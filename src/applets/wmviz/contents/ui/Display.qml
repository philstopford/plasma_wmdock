// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMViz – Audio spectrum visualizer backed by CAVA (via AudioSpectrum).
 *
 * Four MilkDrop-inspired effects driven by real spectral data:
 *
 *   bars      – classic spectrum analyser with per-bar peak markers
 *   wave      – radial scope: 16 bands plotted as a rotating petal blob
 *   circles   – starfield: per-band particles fired in radial directions
 *   plasma    – tunnel:    concentric circles zooming from centre, speed
 *               driven by bass energy
 *
 * All effects react to beat transients (white flash) detected by the
 * AudioSpectrumMonitor C++ singleton.
 */
Item {
    id: root

    // ----- configuration ---------------------------------------------------
    readonly property string effect:      Plasmoid.configuration.effect      || "bars"
    readonly property string colorScheme: Plasmoid.configuration.colorScheme || "green"

    // ----- colour helpers (CSS strings – required for Canvas fillStyle) -----
    function schemeColorCss(t) {
        switch (root.colorScheme) {
        case "blue":
            return "hsl(" + Math.round((0.58 + t * 0.05) * 360) + ",90%,"
                          + Math.round((0.3  + t * 0.4)  * 100) + "%)"
        case "amber":
            return "hsl(" + Math.round((0.10 + t * 0.03) * 360) + ",100%,"
                          + Math.round((0.2  + t * 0.45) * 100) + "%)"
        case "rainbow":
            return "hsl(" + Math.round(t * 0.75 * 360) + ",100%,"
                          + Math.round((0.35 + t * 0.2)  * 100) + "%)"
        default: // green
            return "hsl(" + Math.round((0.33 - t * 0.08) * 360) + ",100%,"
                          + Math.round((0.15 + t * 0.4)  * 100) + "%)"
        }
    }

    // Convert "hsl(...)" to "hsla(..., alpha)"
    function withAlpha(hslStr, alpha) {
        if (hslStr.length > 4 && hslStr.startsWith("hsl("))
            return "hsla(" + hslStr.slice(4, -1) + "," + alpha.toFixed(2) + ")"
        return hslStr
    }

    // ----- shared per-frame state ------------------------------------------
    property var  bandVals:  []         // current 16-band values 0-1
    property real rms:       0          // overall loudness 0-1
    property real bass:      0          // low-freq energy 0-1
    property real treble:    0          // high-freq energy 0-1
    property real beatFlash: 0          // decays to 0 after each beat
    property bool gotBeat:   false      // true for exactly one tick on beat
    property int  tickCount: 0

    // ----- tuning constants -------------------------------------------------
    readonly property real signalDecay:        0.88  // per-frame decay when unavailable
    readonly property real particleLifeDecay:  0.028 // life lost per tick (~35 ticks = 1.4 s)
    readonly property real particleSpawnThresh:0.08  // minimum band energy to spawn
    readonly property real particleSpawnProb:  0.4   // probability multiplier per band

    // ----- bars state -------------------------------------------------------
    property var peakBands: []

    // ----- scope (wave) state -----------------------------------------------
    property real wavePhase: 0

    // ----- starfield (circles) state ----------------------------------------
    property var stars: []

    // ----- tunnel (plasma) state --------------------------------------------
    property var tunnelRings: []

    Component.onCompleted: {
        peakBands = new Array(16).fill(0)
        bandVals  = new Array(16).fill(0)
    }

    // ----- beat → flash ------------------------------------------------------
    Connections {
        target: AudioSpectrum
        function onBeatChanged() {
            if (AudioSpectrum.beat) {
                root.gotBeat   = true
                root.beatFlash = 1.0
            }
        }
    }

    // ----- animation ticker --------------------------------------------------
    Timer {
        interval: 40     // ~25 fps
        repeat:   true
        running:  true
        onTriggered: {
            root.tickCount++

            // Refresh spectrum snapshot
            if (AudioSpectrum.available) {
                root.bandVals = Array.from(AudioSpectrum.bands)
                root.rms    = AudioSpectrum.rms
                root.bass   = AudioSpectrum.bass
                root.treble = AudioSpectrum.treble
            } else {
                root.bandVals = root.bandVals.map(v => v * root.signalDecay)
                root.rms    = root.rms    * root.signalDecay
                root.bass   = root.bass   * root.signalDecay
                root.treble = root.treble * root.signalDecay
            }

            root.beatFlash = Math.max(0, root.beatFlash - 0.12)

            switch (root.effect) {
            case "wave":    tickScope();   break
            case "circles": tickStars();   break
            case "plasma":  tickTunnel();  break
            default:        tickBars();    break
            }

            root.gotBeat = false   // consumed by tick functions above

            canvas.requestPaint()
        }
    }

    // ----- bars tick ---------------------------------------------------------
    function tickBars() {
        const bands = root.bandVals
        const N = 16
        if (!bands || bands.length < N) return
        let peaks = root.peakBands.length === N ? root.peakBands.slice() : new Array(N).fill(0)
        for (let i = 0; i < N; i++) {
            const v = bands[i] || 0
            if (v > peaks[i]) peaks[i] = v
            else              peaks[i] = Math.max(0, peaks[i] - 0.007)
        }
        root.peakBands = peaks
    }

    // ----- scope (wave) tick -------------------------------------------------
    function tickScope() {
        root.wavePhase = (root.wavePhase + 0.025) % (2 * Math.PI)
    }

    // ----- starfield (circles) tick ------------------------------------------
    function tickStars() {
        const cx       = canvas.width  / 2
        const cy       = canvas.height / 2
        const maxSpeed = Math.min(cx, cy) * 0.09
        const bands    = root.bandVals

        // Advance existing particles
        let active = []
        for (let i = 0; i < root.stars.length; i++) {
            const s  = root.stars[i]
            const nl = s.life - root.particleLifeDecay
            if (nl > 0)
                active.push({ x: s.x + s.vx, y: s.y + s.vy,
                             vx: s.vx, vy: s.vy, life: nl, hue: s.hue })
        }

        // Spawn per-band particles (each band fires in its own radial direction)
        if (active.length < 80) {
            for (let i = 0; i < 16; i++) {
                const v = bands[i] || 0
                if (v > root.particleSpawnThresh && Math.random() < v * root.particleSpawnProb) {
                    const angle = 2 * Math.PI * i / 16
                    const speed = v * maxSpeed
                    active.push({ x: cx, y: cy,
                                 vx: Math.cos(angle) * speed,
                                 vy: Math.sin(angle) * speed,
                                 life: 1.0, hue: i / 16 })
                }
            }
        }

        // Beat burst – random spray with bass-scaled velocity
        if (root.gotBeat && active.length < 70) {
            for (let j = 0; j < 10; j++) {
                const angle = Math.random() * 2 * Math.PI
                const speed = (root.bass * 0.6 + 0.2) * maxSpeed * 1.5
                active.push({ x: cx, y: cy,
                             vx: Math.cos(angle) * speed,
                             vy: Math.sin(angle) * speed,
                             life: 1.0, hue: root.treble })
            }
        }

        root.stars = active
    }

    // ----- tunnel (plasma) tick ----------------------------------------------
    function tickTunnel() {
        const speed = root.bass * 0.08 + 0.012

        let rings = root.tunnelRings
                .map(r => ({ scale: r.scale + speed, hue: r.hue }))
                .filter(r => r.scale < 1.8)

        // Spawn a new ring at the centre whenever the gap is large enough
        const frontScale = rings.length > 0 ? rings[0].scale : 9
        if (frontScale > speed * 5)
            rings.unshift({ scale: 0, hue: root.treble })

        root.tunnelRings = rings
    }

    // ----- background -------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#1a1a1a"
        border.width: 1
    }

    // ----- title ------------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 1 }
        text:  "VIZ"
        color: root.schemeColorCss(0.8)
        font { pixelSize: parent.height * 0.10; family: "monospace"; bold: true }
    }

    // ----- main canvas ------------------------------------------------------
    Canvas {
        id: canvas
        anchors {
            top:          titleText.bottom
            left:         parent.left
            right:        parent.right
            bottom:       parent.bottom
            topMargin:    1
            leftMargin:   3
            rightMargin:  3
            bottomMargin: 3
        }
        renderTarget: Canvas.Image

        Component.onCompleted: Qt.callLater(requestPaint)

        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return
            ctx.clearRect(0, 0, width, height)

            switch (root.effect) {
            case "wave":    paintScope(ctx);   break
            case "circles": paintStars(ctx);   break
            case "plasma":  paintTunnel(ctx);  break
            default:        paintBars(ctx);    break
            }

            // Beat flash overlay (all effects)
            if (root.beatFlash > 0.01) {
                ctx.fillStyle = "rgba(255,255,255," + (root.beatFlash * 0.25).toFixed(2) + ")"
                ctx.fillRect(0, 0, width, height)
            }
        }

        // ---- bars -----------------------------------------------------------
        function paintBars(ctx) {
            const w = width, h = height
            const N = 16
            const bands = root.bandVals
            const peaks = root.peakBands
            if (!bands || bands.length < N) return

            const bw = (w - N + 1) / N

            for (let i = 0; i < N; i++) {
                const frac = bands[i] || 0
                const barH = Math.max(1, frac * h)
                ctx.fillStyle = root.schemeColorCss(frac)
                ctx.fillRect(Math.round(i * (bw + 1)), h - barH,
                            Math.max(1, Math.floor(bw)), barH)

                // Per-bar peak marker
                if (peaks && i < peaks.length) {
                    const peakH = peaks[i] * h
                    if (peakH > 2) {
                        ctx.fillStyle = "#ffffff"
                        ctx.fillRect(Math.round(i * (bw + 1)), h - peakH,
                                    Math.max(1, Math.floor(bw)), 1)
                    }
                }
            }
        }

        // ---- scope (radial waveform) -----------------------------------------
        function paintScope(ctx) {
            const w = width, h = height
            const cx = w / 2, cy = h / 2
            const N  = 16
            const bands = root.bandVals
            if (!bands || bands.length < N) return

            const innerR = Math.min(cx, cy) * 0.18
            const outerR = Math.min(cx, cy) * 0.82
            const rangeR = outerR - innerR

            // Draw closed polygon through band points arranged radially
            ctx.beginPath()
            for (let i = 0; i <= N; i++) {
                const idx   = i % N
                const angle = (2 * Math.PI * idx / N) + root.wavePhase
                const r     = innerR + (bands[idx] || 0) * rangeR
                const x     = cx + Math.cos(angle) * r
                const y     = cy + Math.sin(angle) * r
                if (i === 0) ctx.moveTo(x, y)
                else         ctx.lineTo(x, y)
            }
            ctx.closePath()

            ctx.fillStyle   = root.withAlpha(root.schemeColorCss(root.rms * 0.8), 0.18)
            ctx.fill()
            ctx.strokeStyle = root.schemeColorCss(Math.max(0.3, root.rms))
            ctx.lineWidth   = 1.5
            ctx.stroke()

            // Pulsing centre dot scaled by RMS
            const dotR = Math.max(1.5, root.rms * 4)
            ctx.fillStyle = root.schemeColorCss(0.9)
            ctx.beginPath()
            ctx.arc(cx, cy, dotR, 0, 2 * Math.PI)
            ctx.fill()
        }

        // ---- starfield (per-band particles) ----------------------------------
        function paintStars(ctx) {
            const stars = root.stars
            for (let i = 0; i < stars.length; i++) {
                const s  = stars[i]
                const a  = s.life * s.life     // quadratic fade
                const sz = Math.max(1, s.life * 2.5)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(s.hue), a)
                ctx.fillRect(s.x - sz * 0.5, s.y - sz * 0.5, sz, sz)
            }
        }

        // ---- tunnel (zooming concentric rings) --------------------------------
        function paintTunnel(ctx) {
            const w    = width,  h  = height
            const cx   = w / 2, cy = h / 2
            const maxR = Math.min(cx, cy)
            const rings = root.tunnelRings

            for (let i = 0; i < rings.length; i++) {
                const r      = rings[i]
                const radius = r.scale * maxR
                if (radius < 0.5) continue

                // Rings near edge are brighter; rings at centre are dim (depth cue)
                const alpha = Math.min(1.0, r.scale * 1.5)
                ctx.strokeStyle = root.withAlpha(root.schemeColorCss(r.hue), alpha)
                ctx.lineWidth   = Math.max(0.8, (1.0 - r.scale) * 3 + 0.5)
                ctx.beginPath()
                ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                ctx.stroke()
            }
        }
    }
}


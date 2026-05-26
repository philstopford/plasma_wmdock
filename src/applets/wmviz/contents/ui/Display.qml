// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMViz – Audio spectrum visualizer backed by CAVA (via AudioSpectrum).
 *
 * Thirteen MilkDrop-inspired effects driven by real spectral data:
 *
 *   bars      – classic spectrum analyser with per-bar peak markers
 *   wave      – radial scope: 16 bands plotted as a rotating petal blob
 *   circles   – starfield: per-band particles fired in radial directions
 *   plasma    – tunnel:    concentric circles zooming from centre
 *   terrain   – pseudo-3D spectral landscape flyover scrolling toward viewer;
 *               each of the 16 bands drives a hill height with perspective;
 *               optional view rotation (speed: treble) and wireframe mode
 *   vortex    – wormhole fly-through: first-person tunnel with 30 perspective
 *               rings (32 vertices each) zooming toward viewer, 8 longitudinal
 *               rib lines forming the tunnel walls, helix centreline driven by
 *               treble/bass Lissajous (pitch/yaw turns), and continuous camera
 *               roll (banking) accelerated by bass transients
 *   warp      – 16 glowing radial beams (one per band) shooting from centre,
 *               triple-layer glow with beat bursts; hyperspace / warp effect
 *   ripple    – concentric ripples fired on beats and bass transients, with a
 *               background per-band bubble field
 *   kaleid    – 6-fold kaleidoscope of radial spectrum wedges rotating at a
 *               rate driven by RMS and beat transients
 *   nova      – afterglow bloom: persistence-of-vision fade creates glowing
 *               comet trails; beat bursts fire 130 particles with halos; steady
 *               per-band emission weaves a swirling nebula
 *   galaxy    – rotating logarithmic spiral galaxy: 700 stars distributed
 *               across two arms react per-band; galactic core pulses with bass
 *   aurora    – 8 flowing northern-lights curtains; each ribbon's amplitude
 *               and brightness driven by a pair of adjacent bands, with
 *               independent sinusoidal phase drift per ribbon
 *   mandala   – 12/8/6-fold geometric mandala with three counter-rotating
 *               petal layers; each layer's radii driven by a different subset
 *               of bands, building dense jewel-like symmetry
 *
 * All effects react to beat transients (white flash) detected by the
 * AudioSpectrumMonitor C++ singleton.
 */
Item {
    id: root

    // ----- configuration ---------------------------------------------------
    readonly property string effect:           Plasmoid.configuration.effect      || "bars"
    readonly property string colorScheme:      Plasmoid.configuration.colorScheme || "green"
    readonly property bool   terrainRotate:    Plasmoid.configuration.terrainRotate    || false
    readonly property bool   terrainWireframe: Plasmoid.configuration.terrainWireframe || false

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
    readonly property int  numBands:           16    // CAVA band count

    // ----- bars state -------------------------------------------------------
    property var peakBands: []

    // ----- scope (wave) state -----------------------------------------------
    property real wavePhase: 0

    // ----- starfield (circles) state ----------------------------------------
    property var stars: []

    // ----- tunnel (plasma) state --------------------------------------------
    property var tunnelRings: []

    // ----- terrain state ----------------------------------------------------
    // Each entry is a snapshot of 16 band values; index 0 = newest (nearest).
    property var terrainHistory: []
    readonly property int terrainMaxRows: 24

    // ----- vortex state -----------------------------------------------------
    property real vortexAngle:   0
    property real vortexDriftX:  0   // tunnel centreline pitch/yaw fraction (−1..1)
    property real vortexDriftY:  0
    property real vortexRoll:    0   // camera banking (roll about tunnel axis)
    property real vortexTravelZ: 0   // z-travel fraction [0,1); cycles each full fly-through

    // ----- warp state -------------------------------------------------------
    // Per-band beam length in 0-1; each beam immediately jumps up when its
    // band energy rises and then decays exponentially.
    property var warpLengths: []

    // ----- terrain rotation state -------------------------------------------
    property real terrainRotAngle: 0

    // ----- ripple state -----------------------------------------------------
    property var ripples: []

    // ----- kaleidoscope state -----------------------------------------------
    property real kaleidPhase: 0

    // ----- nova (afterglow bloom) state -------------------------------------
    property var  novaParticles: []

    // ----- galaxy (rotating spiral) state -----------------------------------
    property real galaxyAngle: 0
    property var  galaxyStars: []

    // ----- aurora (northern lights) state -----------------------------------
    property real auroraTime: 0

    // ----- mandala (multi-layer geometric) state ----------------------------
    property real mandalaPhase: 0

    Component.onCompleted: {
        peakBands   = new Array(numBands).fill(0)
        bandVals    = new Array(numBands).fill(0)
        warpLengths = new Array(numBands).fill(0)

        // Build the galaxy star field once at startup so positions are fixed
        // and per-frame rendering only needs to rotate and draw.
        const ARMS          = 2
        const STARS_PER_ARM = 280
        const HALO_STARS    = 140
        let gs = []
        for (let arm = 0; arm < ARMS; arm++) {
            for (let s = 0; s < STARS_PER_ARM; s++) {
                const t = s / STARS_PER_ARM
                const theta = t * 4.5 * Math.PI
                // Scatter: more spread toward the outer rim
                const scat = (Math.random() - 0.5) * 0.18 * Math.sqrt(t + 0.05)
                gs.push({
                    r:        Math.sqrt(t) * 0.88 + scat,
                    theta:    theta + arm * Math.PI + (Math.random() - 0.5) * 0.38,
                    hue:      t * 0.65 + Math.random() * 0.15,
                    size:     0.6 + Math.random() * 1.2 * (1.0 - t * 0.55),
                    bandBias: Math.floor(t * 16) % 16
                })
            }
        }
        // Scattered halo stars not on any arm
        for (let i = 0; i < HALO_STARS; i++) {
            gs.push({
                r:        0.20 + Math.random() * 0.80,
                theta:    Math.random() * 2 * Math.PI,
                hue:      Math.random(),
                size:     0.5,
                bandBias: Math.floor(Math.random() * 16)
            })
        }
        galaxyStars = gs
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
            case "wave":    tickScope();    break
            case "circles": tickStars();    break
            case "plasma":  tickTunnel();   break
            case "terrain": tickTerrain();  break
            case "vortex":  tickVortex();   break
            case "warp":    tickWarp();     break
            case "ripple":  tickRipple();   break
            case "kaleid":  tickKaleid();   break
            case "nova":    tickNova();     break
            case "galaxy":  tickGalaxy();   break
            case "aurora":  tickAurora();   break
            case "mandala": tickMandala();  break
            default:        tickBars();     break
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

    // ----- terrain tick -------------------------------------------------------
    function tickTerrain() {
        const snap = (root.bandVals && root.bandVals.length === root.numBands)
                     ? root.bandVals.slice() : new Array(root.numBands).fill(0)
        // Mutate in place to avoid creating a new array every frame.
        let hist = root.terrainHistory
        hist.unshift(snap)
        if (hist.length > root.terrainMaxRows)
            hist.pop()
        root.terrainHistory = hist

        // Optional rotating viewpoint: speed proportional to treble + beat kick
        if (root.terrainRotate) {
            const rotSpeed = 0.003 + root.treble * 0.012 + (root.gotBeat ? 0.08 : 0)
            root.terrainRotAngle = (root.terrainRotAngle + rotSpeed) % (2 * Math.PI)
        }
    }

    // ----- vortex tick --------------------------------------------------------
    function tickVortex() {
        // Primary tunnel spin speed (drives twist / helix accumulation)
        const rotSpeed = 0.018 + root.rms * 0.045 + (root.gotBeat ? 0.14 : 0)
        root.vortexAngle = root.vortexAngle + rotSpeed

        // Banking (camera roll): continuous slow roll, kicked by bass transients
        const rollSpeed = 0.003 + root.bass * 0.018 + (root.gotBeat ? 0.09 : 0)
        root.vortexRoll = root.vortexRoll + rollSpeed

        // Forward travel through tunnel: advances all ring depths toward viewer
        const travelSpeed = 0.009 + root.rms * 0.014
        root.vortexTravelZ = (root.vortexTravelZ + travelSpeed) % 1.0

        // Pitch / yaw Lissajous drives tunnel centreline curvature (turning/winding)
        const driftAmp = Math.min(0.35, root.treble * 0.32 + root.bass * 0.10)
        root.vortexDriftX = root.vortexDriftX * 0.94
                            + Math.sin(root.vortexAngle * 1.7) * driftAmp
        root.vortexDriftY = root.vortexDriftY * 0.94
                            + Math.cos(root.vortexAngle * 2.3) * driftAmp * 0.65
    }

    // ----- warp tick ----------------------------------------------------------
    function tickWarp() {
        const bands     = root.bandVals
        const decayRate = 0.90
        const boom      = root.gotBeat ? 1.5 : 1.0
        // Reuse the existing array when possible; only allocate on first call.
        let lens = root.warpLengths
        if (lens.length !== root.numBands)
            lens = new Array(root.numBands).fill(0)
        for (let i = 0; i < root.numBands; i++) {
            const target = Math.min(1, (bands[i] || 0) * (1 + root.bass * 0.8) * boom)
            lens[i] = Math.max(target, lens[i] * decayRate)
        }
        root.warpLengths = lens
    }

    // ----- ripple tick --------------------------------------------------------
    function tickRipple() {
        const maxR = Math.min(canvas.width, canvas.height) * 0.80
        const speed = 0.9 + root.bass * 1.8

        // Advance existing ripples
        let active = []
        for (let i = 0; i < root.ripples.length; i++) {
            const rp = root.ripples[i]
            const nr = rp.radius + speed
            const ne = rp.energy * 0.96
            if (nr < maxR && ne > 0.02)
                active.push({ radius: nr, energy: ne, hue: rp.hue })
        }

        // Large ripple on beat or strong bass transient
        if ((root.gotBeat || root.bass > 0.55) && active.length < 8)
            active.push({ radius: 2, energy: 0.65 + root.bass * 0.35, hue: root.treble })

        // Steady smaller ripples driven by RMS
        if (root.rms > 0.08 && active.length < 6 && (root.tickCount % 6 === 0))
            active.push({ radius: 2, energy: root.rms * 0.45, hue: root.treble * 0.6 })

        root.ripples = active
    }

    // ----- kaleidoscope tick --------------------------------------------------
    function tickKaleid() {
        const rotSpeed = 0.007 + root.rms * 0.025 + (root.gotBeat ? 0.18 : 0)
        root.kaleidPhase = (root.kaleidPhase + rotSpeed) % (2 * Math.PI)
    }

    // ----- nova tick ----------------------------------------------------------
    function tickNova() {
        const cx       = canvas.width  / 2
        const cy       = canvas.height / 2
        const maxSpeed = Math.min(cx, cy) * 0.14
        const bands    = root.bandVals

        // Advance and decay existing particles
        let alive = []
        for (let i = 0; i < root.novaParticles.length; i++) {
            const p  = root.novaParticles[i]
            const nl = p.life - (p.tracer ? 0.009 : 0.021)
            if (nl > 0)
                alive.push({ x: p.x + p.vx, y: p.y + p.vy,
                            vx: p.vx * 0.97, vy: p.vy * 0.97,
                            life: nl, hue: p.hue, size: p.size, tracer: p.tracer })
        }

        // Continuous per-band emission in each band's radial direction
        if (alive.length < 300) {
            for (let i = 0; i < 16; i++) {
                const v = bands[i] || 0
                if (v > 0.08 && Math.random() < v * 0.55) {
                    const angle = 2 * Math.PI * i / 16 + (Math.random() - 0.5) * 0.70
                    const speed = v * maxSpeed * (0.4 + root.rms * 0.9)
                    alive.push({ x: cx, y: cy,
                                vx: Math.cos(angle) * speed,
                                vy: Math.sin(angle) * speed,
                                life: 0.6 + Math.random() * 0.4,
                                hue: i / 16, size: 1.2 + v * 2.5, tracer: false })
                }
            }
        }

        // Beat burst: 130 particles, first 24 are slow long-lived "tracers"
        if (root.gotBeat) {
            for (let j = 0; j < 130; j++) {
                const angle  = Math.random() * 2 * Math.PI
                const tracer = j < 24
                const speed  = (0.35 + root.bass * 0.75 + Math.random() * 0.30) * maxSpeed
                               * (tracer ? 0.35 : 1.0)
                alive.push({ x: cx, y: cy,
                            vx: Math.cos(angle) * speed,
                            vy: Math.sin(angle) * speed,
                            life: tracer ? 1.0 : 0.70 + Math.random() * 0.30,
                            hue:  root.treble * 0.4 + Math.random() * 0.6,
                            size: tracer ? 2.5 + Math.random() * 1.5
                                        : 1.2 + Math.random() * 2.2,
                            tracer: tracer })
            }
        }

        if (alive.length > 450)
            alive = alive.slice(alive.length - 450)

        root.novaParticles = alive
    }

    // ----- galaxy tick --------------------------------------------------------
    function tickGalaxy() {
        const speed = 0.003 + root.treble * 0.012 + (root.gotBeat ? 0.05 : 0)
        root.galaxyAngle = (root.galaxyAngle + speed) % (2 * Math.PI)
    }

    // ----- aurora tick --------------------------------------------------------
    function tickAurora() {
        const speed = 0.010 + root.rms * 0.022 + (root.gotBeat ? 0.07 : 0)
        root.auroraTime  = root.auroraTime + speed
    }

    // ----- mandala tick -------------------------------------------------------
    function tickMandala() {
        const speed = 0.006 + root.rms * 0.022 + (root.gotBeat ? 0.14 : 0)
        root.mandalaPhase = (root.mandalaPhase + speed) % (2 * Math.PI)
    }

    // ----- background -------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#1a1a1a"
        border.width: 1
    }

    // ----- main canvas ------------------------------------------------------
    Canvas {
        id: canvas
        anchors { fill: parent; margins: 3 }
        renderTarget: Canvas.Image

        onWidthChanged:  Qt.callLater(requestPaint)
        onHeightChanged: Qt.callLater(requestPaint)

        Component.onCompleted: Qt.callLater(requestPaint)

        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return
            // Nova uses a persistence-fade overlay for comet trails; it clears itself.
            // All other effects need a clean canvas each frame.
            if (root.effect !== "nova")
                ctx.clearRect(0, 0, width, height)

            switch (root.effect) {
            case "wave":    paintScope(ctx);    break
            case "circles": paintStars(ctx);    break
            case "plasma":  paintTunnel(ctx);   break
            case "terrain": paintTerrain(ctx);  break
            case "vortex":  paintVortex(ctx);   break
            case "warp":    paintWarp(ctx);     break
            case "ripple":  paintRipple(ctx);   break
            case "kaleid":  paintKaleid(ctx);   break
            case "nova":    paintNova(ctx);     break
            case "galaxy":  paintGalaxy(ctx);   break
            case "aurora":  paintAurora(ctx);   break
            case "mandala": paintMandala(ctx);  break
            default:        paintBars(ctx);     break
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

        // ---- terrain (pseudo-3D spectral landscape flyover) ------------------
        function paintTerrain(ctx) {
            const w        = width,  h = height
            const history  = root.terrainHistory
            const numRows  = history.length
            if (numRows === 0) return

            ctx.fillStyle = "#000"
            ctx.fillRect(0, 0, w, h)

            const horizonY = h * 0.30

            // Optional rotation: spin the whole viewport around the canvas centre
            if (root.terrainRotate && root.terrainRotAngle !== 0) {
                ctx.save()
                ctx.translate(w * 0.5, h * 0.5)
                ctx.rotate(root.terrainRotAngle)
                ctx.translate(-w * 0.5, -h * 0.5)
            }

            // Draw from farthest row (near horizon) to nearest (bottom canvas).
            // In terrainHistory index 0 is NEWEST (nearest), numRows-1 is OLDEST.
            for (let r = numRows - 1; r >= 0; r--) {
                const t     = r / Math.max(1, numRows - 1) // 0=nearest, 1=farthest
                const baseY = h - t * (h - horizonY)       // ground baseline
                const rowW  = w * (1.0 - t * 0.60)         // narrower at horizon
                const xOff  = (w - rowW) / 2
                const maxH  = (baseY - horizonY) * 0.88    // max hill height

                const row = history[r]
                ctx.beginPath()
                ctx.moveTo(xOff, baseY)
                for (let i = 0; i < root.numBands; i++) {
                    const xPos = xOff + i * rowW / Math.max(1, root.numBands - 1) // spread numBands points across [0, rowW]
                    const yPos = baseY - (row[i] || 0) * maxH
                    ctx.lineTo(xPos, yPos)
                }
                ctx.lineTo(xOff + rowW, baseY)
                ctx.closePath()

                const energy = row.reduce((s, v) => s + v, 0) / root.numBands
                const alpha  = 0.12 + (1 - t) * 0.70

                if (!root.terrainWireframe) {
                    ctx.fillStyle = root.withAlpha(
                        root.schemeColorCss((1 - t) * 0.55 + energy * 0.45), alpha)
                    ctx.fill()
                }

                // Wireframe ridge line on top of each terrain slice
                ctx.strokeStyle = root.withAlpha(root.schemeColorCss(1 - t), (1 - t) * 0.55)
                ctx.lineWidth   = root.terrainWireframe ? 1.0 : 0.6
                ctx.stroke()
            }

            // Horizon rule
            ctx.strokeStyle = root.schemeColorCss(0.65)
            ctx.lineWidth   = 0.5
            ctx.beginPath()
            ctx.moveTo(0, horizonY); ctx.lineTo(w, horizonY)
            ctx.stroke()

            if (root.terrainRotate && root.terrainRotAngle !== 0)
                ctx.restore()
        }

        // ---- vortex (wormhole: first-person fly-through tunnel) ---------------
        function paintVortex(ctx) {
            const w      = width,  h  = height
            const cx0    = w / 2,  cy0 = h / 2
            const bands  = root.bandVals
            const minDim = Math.min(w, h)

            // Geometry / perspective constants
            // RINGS × VERTS gives the ring mesh; N_RIBS longitudinal lines add
            // the lengthwise structure visible in wormhole / stargate visuals.
            const RINGS  = 30        // depth slices (cross-section rings)
            const VERTS  = 32        // polygon vertices per ring
            const N_RIBS = 8         // longitudinal rib lines along tunnel walls
            const Z_NEAR = 0.25      // depth of nearest ring (fills ~screen)
            const Z_FAR  = 7.0       // depth of farthest ring (vanishing point)
            const FOCAL  = minDim * 0.50   // focal length in screen pixels
            const TUBE_R = 0.35      // world-space tube radius (calibrated for FOV)

            // Tuning constants (separated for ease of adjustment)
            const ROLL_DAMP       = 0.45  // fraction of vortexRoll applied as canvas rotation
            const MIN_RING_RADIUS = 0.4   // cull rings smaller than this (pixels)
            const MAX_RING_MULT   = 3.0   // cull rings larger than minDim × this
            const HELIX_PHASE_T   = 0.55  // time contribution to helix phase per radian
            const HELIX_PHASE_Z   = 0.20  // depth contribution to helix phase per world unit
            const BEND_AMP        = 0.38  // helix bend amplitude (fraction of FOCAL)
            const LISSAJOUS_Y     = 0.71  // Y-axis phase ratio for Lissajous centreline
            const TWIST_T         = 2.8   // time multiplier for per-ring twist
            const TWIST_Z         = 0.42  // depth multiplier for per-ring twist

            ctx.fillStyle = "#000000"
            ctx.fillRect(0, 0, w, h)

            // Apply camera roll (banking): rotate entire scene around screen centre.
            // This creates the barrel-roll / wormhole banking sensation.
            ctx.save()
            ctx.translate(cx0, cy0)
            ctx.rotate(root.vortexRoll * ROLL_DAMP)
            ctx.translate(-cx0, -cy0)

            // Pre-compute per-ring geometry so both the ring pass and the rib pass
            // can reuse the data without redundant trigonometry.
            const ringData = []
            for (let k = 0; k < RINGS; k++) {
                // tNorm 0 = vanishing (far, small on screen)
                //        1 = right in front of viewer (large, about to clip)
                // vortexTravelZ advances 0→1 continuously, sliding all rings
                // toward the viewer; when a ring reaches tNorm=1 it wraps to 0.
                const tNorm = (k / RINGS + root.vortexTravelZ) % 1.0

                // Logarithmic depth: rings appear evenly spaced in perspective.
                const z = Z_FAR * Math.pow(Z_NEAR / Z_FAR, tNorm)

                // Perspective scale: screen pixels per world unit at depth z.
                const ps    = FOCAL / z
                const baseR = TUBE_R * ps   // screen-space ring radius

                // Cull rings that are invisible (vanishingly small or clipping).
                if (baseR < MIN_RING_RADIUS || baseR > minDim * MAX_RING_MULT) {
                    ringData.push(null)
                    continue
                }

                // Tunnel centreline curves as a smooth helix driven by pitch/yaw.
                // Bend amplitude grows with sqrt(z) so near rings hug the travel
                // axis while far rings show the curve — the "looking into a bend"
                // depth cue.
                const ph    = root.vortexAngle * HELIX_PHASE_T + z * HELIX_PHASE_Z
                const bendR = FOCAL * BEND_AMP * Math.sqrt(z / Z_FAR)
                const cx    = cx0 + root.vortexDriftX * bendR * Math.sin(ph)
                const cy    = cy0 + root.vortexDriftY * bendR * Math.cos(ph * LISSAJOUS_Y)

                // Twist angle: each ring is rotated around the tunnel axis by an
                // amount that depends on both time and depth, giving the spiral
                // corridor appearance.
                const twist = root.vortexAngle * TWIST_T + z * TWIST_Z

                ringData.push({ cx, cy, baseR, twist, tNorm })
            }

            // ---- Cross-section rings, drawn far → near (k=0 farthest) ----------
            for (let k = 0; k < RINGS; k++) {
                const rd = ringData[k]
                if (!rd) continue

                ctx.beginPath()
                for (let v = 0; v <= VERTS; v++) {
                    const idx     = v % VERTS
                    const bandIdx = idx % 16
                    const angle   = (2 * Math.PI * idx / VERTS) + rd.twist
                    // Spectral deformation: vertices pushed out by their band;
                    // effect is strongest for near rings (tNorm → 1).
                    const deform  = (bands[bandIdx] || 0) * 0.50 * rd.tNorm
                    const r = rd.baseR * (1 + deform)
                    const x = rd.cx + Math.cos(angle) * r
                    const y = rd.cy + Math.sin(angle) * r
                    if (v === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.closePath()

                const alpha = 0.06 + rd.tNorm * 0.84
                ctx.strokeStyle = root.withAlpha(
                    root.schemeColorCss(root.treble * 0.2 + rd.tNorm * 0.8), alpha)
                ctx.lineWidth = Math.max(0.3, rd.tNorm * 3.0)
                ctx.stroke()
            }

            // ---- Longitudinal ribs (tunnel structure lines) ---------------------
            // Each rib is a single path connecting one vertex index across all
            // visible rings from far to near, creating the grid-like wormhole wall.
            for (let r = 0; r < N_RIBS; r++) {
                const vIdx    = Math.floor(r * VERTS / N_RIBS)
                const bandIdx = vIdx % 16
                const bandVal = bands[bandIdx] || 0

                ctx.beginPath()
                let started = false
                for (let k = 0; k < RINGS; k++) {
                    const rd = ringData[k]
                    if (!rd) continue
                    const angle  = (2 * Math.PI * vIdx / VERTS) + rd.twist
                    const deform = bandVal * 0.50 * rd.tNorm
                    const radius = rd.baseR * (1 + deform)
                    const x = rd.cx + Math.cos(angle) * radius
                    const y = rd.cy + Math.sin(angle) * radius
                    if (!started) { ctx.moveTo(x, y); started = true }
                    else          { ctx.lineTo(x, y) }
                }

                const ribAlpha = 0.10 + bandVal * 0.42
                ctx.strokeStyle = root.withAlpha(
                    root.schemeColorCss(bandIdx / 16), ribAlpha)
                ctx.lineWidth = Math.max(0.4, bandVal * 1.8 + 0.4)
                ctx.stroke()
            }

            ctx.restore()

            // Vanishing-point glow at screen centre, pulsed by RMS
            if (root.rms > 0.04) {
                const glowR = Math.max(2, root.rms * 10)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(root.treble), 0.85)
                ctx.beginPath()
                ctx.arc(cx0, cy0, glowR, 0, 2 * Math.PI)
                ctx.fill()
            }
        }

        // ---- warp (radial beam hyperspace) -----------------------------------
        function paintWarp(ctx) {
            const w      = width,  h  = height
            const cx     = w / 2,  cy = h / 2
            const maxLen = Math.min(cx, cy) * 0.93
            const lens   = root.warpLengths
            if (!lens || lens.length < root.numBands) return

            for (let i = 0; i < root.numBands; i++) {
                const len = (lens[i] || 0) * maxLen
                if (len < 1.5) continue

                // Beams start at 12 o'clock and fan clockwise around 360°.
                const angle = 2 * Math.PI * i / root.numBands - Math.PI / 2
                const x2   = cx + Math.cos(angle) * len
                const y2   = cy + Math.sin(angle) * len
                const col  = root.schemeColorCss(i / root.numBands)

                // Triple-layer glow: wide halo → mid beam → bright core
                ctx.lineWidth   = 6
                ctx.strokeStyle = root.withAlpha(col, 0.12)
                ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(x2, y2); ctx.stroke()

                ctx.lineWidth   = 2.5
                ctx.strokeStyle = root.withAlpha(col, 0.50)
                ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(x2, y2); ctx.stroke()

                ctx.lineWidth   = 0.8
                ctx.strokeStyle = col
                ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(x2, y2); ctx.stroke()

                // Tip sparkle dot
                const ts = Math.max(1.0, lens[i] * 3)
                ctx.fillStyle = "#ffffff"
                ctx.fillRect(x2 - ts * 0.5, y2 - ts * 0.5, ts, ts)
            }

            // Pulsing core dot
            const coreR = Math.max(1.5, root.rms * 5)
            ctx.fillStyle = root.schemeColorCss(0.85)
            ctx.beginPath()
            ctx.arc(cx, cy, coreR, 0, 2 * Math.PI)
            ctx.fill()
        }

        // ---- ripple (concentric pond ripples + band bubbles) -----------------
        function paintRipple(ctx) {
            const w      = width,  h  = height
            const cx     = w / 2,  cy = h / 2
            const bands  = root.bandVals

            // Background: small per-band circles arranged radially
            if (bands && bands.length >= root.numBands) {
                for (let i = 0; i < root.numBands; i++) {
                    const v     = bands[i] || 0
                    if (v < 0.04) continue
                    const angle = 2 * Math.PI * i / root.numBands
                    const r     = Math.min(cx, cy) * (0.10 + v * 0.58)
                    const bx    = cx + Math.cos(angle) * r
                    const by    = cy + Math.sin(angle) * r
                    const bSize = Math.max(1.2, v * 4.5)
                    ctx.strokeStyle = root.withAlpha(root.schemeColorCss(i / root.numBands), v * 0.45)
                    ctx.lineWidth   = 0.8
                    ctx.beginPath()
                    ctx.arc(bx, by, bSize, 0, 2 * Math.PI)
                    ctx.stroke()
                }
            }

            // Ripple rings
            const ripples = root.ripples
            for (let i = 0; i < ripples.length; i++) {
                const rp    = ripples[i]
                const alpha = rp.energy * 0.85
                ctx.strokeStyle = root.withAlpha(root.schemeColorCss(rp.hue), alpha)
                ctx.lineWidth   = Math.max(0.5, rp.energy * 2.5)
                ctx.beginPath()
                ctx.arc(cx, cy, rp.radius, 0, 2 * Math.PI)
                ctx.stroke()
            }

            // Centre glow
            if (root.rms > 0.04) {
                const gr = Math.max(1.5, root.rms * 6)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(root.treble), root.rms * 0.85)
                ctx.beginPath()
                ctx.arc(cx, cy, gr, 0, 2 * Math.PI)
                ctx.fill()
            }
        }

        // ---- kaleidoscope (6-fold mirrored spectrum wedges) -----------------
        function paintKaleid(ctx) {
            const w      = width,  h  = height
            const cx     = w / 2,  cy = h / 2
            const maxR   = Math.min(cx, cy) * 0.90
            const bands  = root.bandVals
            const folds  = 6
            if (!bands || bands.length < root.numBands) return

            const energy = bands.reduce((s, v) => s + v, 0) / root.numBands

            for (let k = 0; k < folds; k++) {
                // Each fold rotated by 60° + slow phase driven by RMS / beats
                const foldAngle = k * 2 * Math.PI / folds + root.kaleidPhase

                // Draw the wedge twice: once normal, once mirrored (scale Y =-1)
                for (let mirror = 0; mirror < 2; mirror++) {
                    ctx.save()
                    ctx.translate(cx, cy)
                    ctx.rotate(foldAngle)
                    if (mirror === 1) ctx.scale(1, -1)  // mirror image

                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    for (let i = 0; i < root.numBands; i++) {
                        // Sweep band points through the half-wedge angle
                        const sweep = Math.PI / folds
                        const ang   = sweep * i / Math.max(1, root.numBands - 1) - sweep * 0.5
                        const r     = maxR * (0.15 + (bands[i] || 0) * 0.85)
                        ctx.lineTo(Math.cos(ang) * r, Math.sin(ang) * r)
                    }
                    ctx.closePath()

                    ctx.fillStyle = root.withAlpha(
                        root.schemeColorCss(k / folds + root.treble * 0.12),
                        0.12 + energy * 0.30)
                    ctx.fill()

                    ctx.strokeStyle = root.schemeColorCss(k / folds + root.treble * 0.12)
                    ctx.lineWidth   = 0.7 + root.rms * 1.2
                    ctx.stroke()
                    ctx.restore()
                }
            }

            // Centre dot
            if (root.rms > 0.03) {
                const cr = Math.max(1.5, root.rms * 5)
                ctx.fillStyle = root.schemeColorCss(0.9)
                ctx.beginPath()
                ctx.arc(cx, cy, cr, 0, 2 * Math.PI)
                ctx.fill()
            }
        }

        // ---- nova (afterglow bloom / comet-trail nebula) --------------------
        function paintNova(ctx) {
            const w   = width,  h  = height
            const cx  = w / 2,  cy = h / 2
            const R   = Math.min(cx, cy)

            // Persistence fade: overwrite with near-black, not clearRect
            ctx.fillStyle = "rgba(0,0,0,0.072)"
            ctx.fillRect(0, 0, w, h)

            const ps = root.novaParticles
            for (let i = 0; i < ps.length; i++) {
                const p     = ps[i]
                const alpha = p.life * (p.tracer ? 0.70 : 0.82)
                const r     = p.size * (0.5 + p.life * 0.5)

                // Inner core
                ctx.beginPath()
                ctx.arc(p.x, p.y, Math.max(0.5, r), 0, 2 * Math.PI)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(p.hue), alpha)
                ctx.fill()

                // Outer halo glow
                if (p.size > 1.5) {
                    const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r * 3.5)
                    g.addColorStop(0, root.withAlpha(root.schemeColorCss(p.hue), alpha * 0.55))
                    g.addColorStop(1, "rgba(0,0,0,0)")
                    ctx.beginPath()
                    ctx.arc(p.x, p.y, r * 3.5, 0, 2 * Math.PI)
                    ctx.fillStyle = g
                    ctx.fill()
                }
            }

            // Pulsing central star – always rendered
            const coreR = Math.max(1.5, root.rms * R * 0.22 + (root.gotBeat ? R * 0.065 : 0))
            const cg    = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR * 3.5)
            cg.addColorStop(0, root.withAlpha(root.schemeColorCss(root.treble * 0.55), 0.95))
            cg.addColorStop(0.28, root.withAlpha(root.schemeColorCss(root.treble * 0.55 + 0.1), 0.35))
            cg.addColorStop(1, "rgba(0,0,0,0)")
            ctx.beginPath()
            ctx.arc(cx, cy, coreR * 3.5, 0, 2 * Math.PI)
            ctx.fillStyle = cg
            ctx.fill()

            // Bright inner dot
            ctx.beginPath()
            ctx.arc(cx, cy, coreR, 0, 2 * Math.PI)
            ctx.fillStyle = root.schemeColorCss(root.treble * 0.3 + 0.75)
            ctx.fill()
        }

        // ---- galaxy (rotating logarithmic spiral star field) ----------------
        function paintGalaxy(ctx) {
            const w      = width,  h  = height
            const cx     = w / 2,  cy = h / 2
            const R      = Math.min(cx, cy) * 0.90
            const bands  = root.bandVals
            const ang    = root.galaxyAngle
            if (!bands || bands.length < root.numBands) return

            ctx.fillStyle = "#000000"
            ctx.fillRect(0, 0, w, h)

            // Draw stars
            const stars = root.galaxyStars
            for (let i = 0; i < stars.length; i++) {
                const s  = stars[i]
                const a  = s.theta + ang * (1 + s.r * 0.9)
                const px = cx + Math.cos(a) * s.r * R
                const py = cy + Math.sin(a) * s.r * R * 0.52   // flatten: elliptical galaxy

                const band  = bands[s.bandBias] || 0
                const glow  = 0.55 + band * 0.85
                const alpha = (0.4 + band * 0.7) * (1.0 - s.r * 0.45)
                const sr    = s.size * glow * (1.0 + root.bass * 0.6)

                ctx.beginPath()
                ctx.arc(px, py, Math.max(0.4, sr), 0, 2 * Math.PI)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(s.hue + root.treble * 0.08), alpha)
                ctx.fill()
            }

            // Galactic core: layered radial glow
            const coreR = R * (0.065 + root.bass * 0.095 + (root.gotBeat ? 0.04 : 0))
            for (let layer = 3; layer >= 0; layer--) {
                const lr   = coreR * (layer * 1.8 + 1)
                const cg   = ctx.createRadialGradient(cx, cy, 0, cx, cy, lr)
                const alpC = 0.85 - layer * 0.18
                cg.addColorStop(0,    root.withAlpha(root.schemeColorCss(0.08), alpC))
                cg.addColorStop(0.35, root.withAlpha(root.schemeColorCss(0.12), alpC * 0.45))
                cg.addColorStop(1,    "rgba(0,0,0,0)")
                ctx.beginPath()
                ctx.arc(cx, cy, lr, 0, 2 * Math.PI)
                ctx.fillStyle = cg
                ctx.fill()
            }
        }

        // ---- aurora (northern-lights flowing curtains) -----------------------
        function paintAurora(ctx) {
            const w     = width,  h  = height
            const bands = root.bandVals
            const t     = root.auroraTime
            if (!bands || bands.length < root.numBands) return

            ctx.fillStyle = "#000009"
            ctx.fillRect(0, 0, w, h)

            const NUM_RIBBONS = 8
            for (let ri = 0; ri < NUM_RIBBONS; ri++) {
                // Pair up 2 adjacent bands per ribbon
                const b1    = bands[(ri * 2)     % 16] || 0
                const b2    = bands[(ri * 2 + 1) % 16] || 0
                const amp   = h * (0.07 + (b1 + b2) * 0.5 * 0.25)
                const baseY = h * (0.15 + ri / NUM_RIBBONS * 0.60)
                const phase = t * (0.6 + ri * 0.18) + ri * 1.4
                const hue   = ri / NUM_RIBBONS + root.treble * 0.18

                const STEPS = 80
                ctx.beginPath()
                for (let si = 0; si <= STEPS; si++) {
                    const xf  = si / STEPS
                    const px  = xf * w
                    const py  = baseY + Math.sin(xf * 3.5 + phase) * amp
                             + Math.sin(xf * 7.0 - phase * 0.7) * amp * 0.35
                    if (si === 0) ctx.moveTo(px, py)
                    else          ctx.lineTo(px, py)
                }
                // Ribbon bottom (near h)
                for (let si = STEPS; si >= 0; si--) {
                    const xf  = si / STEPS
                    const px  = xf * w
                    const py  = baseY + h * 0.085 + Math.sin(xf * 3.5 + phase + 0.5) * amp * 0.5
                    ctx.lineTo(px, py)
                }
                ctx.closePath()

                const alpha = 0.06 + (b1 + b2) * 0.5 * 0.32 + (root.gotBeat ? 0.10 : 0)
                ctx.fillStyle = root.withAlpha(root.schemeColorCss(hue), alpha)
                ctx.fill()

                // Bright upper edge stroke
                ctx.beginPath()
                for (let si = 0; si <= STEPS; si++) {
                    const xf  = si / STEPS
                    const px  = xf * w
                    const py  = baseY + Math.sin(xf * 3.5 + phase) * amp
                             + Math.sin(xf * 7.0 - phase * 0.7) * amp * 0.35
                    if (si === 0) ctx.moveTo(px, py)
                    else          ctx.lineTo(px, py)
                }
                ctx.strokeStyle = root.withAlpha(root.schemeColorCss(hue + 0.06), 0.45 + b1 * 0.55)
                ctx.lineWidth   = 0.9 + b2 * 1.8
                ctx.stroke()
            }
        }

        // ---- mandala (multi-layer geometric / jewel) ------------------------
        function paintMandala(ctx) {
            const w     = width,  h  = height
            const cx    = w / 2,  cy = h / 2
            const R     = Math.min(cx, cy) * 0.90
            const bands = root.bandVals
            const ph    = root.mandalaPhase
            if (!bands || bands.length < root.numBands) return

            ctx.fillStyle = "#000000"
            ctx.fillRect(0, 0, w, h)

            // Layer definitions: { folds, direction, hueOffset, bandRange }
            const layers = [
                { folds: 12, dir:  1, hueOff: 0.00, bands: [0,5]  },
                { folds:  8, dir: -1, hueOff: 0.33, bands: [5,10] },
                { folds:  6, dir:  1, hueOff: 0.66, bands: [10,16] }
            ]

            for (let li = 0; li < layers.length; li++) {
                const L      = layers[li]
                const folds  = L.folds
                const bSlice = bands.slice(L.bands[0], L.bands[1])
                const energy = bSlice.reduce((s, v) => s + v, 0) / bSlice.length
                const rInner = R * (0.06 + energy * 0.08)
                const rOuter = R * (0.22 + energy * 0.55 + root.rms * 0.12)
                const layPh  = ph * L.dir * (1 + li * 0.35)

                for (let k = 0; k < folds; k++) {
                    const foldAngle = k * 2 * Math.PI / folds + layPh
                    for (let mirror = 0; mirror < 2; mirror++) {
                        ctx.save()
                        ctx.translate(cx, cy)
                        ctx.rotate(foldAngle)
                        if (mirror === 1) ctx.scale(1, -1)

                        // Petal shape: arc from rInner to rOuter using band values
                        ctx.beginPath()
                        ctx.moveTo(0, rInner)
                        const SEGS = bSlice.length
                        for (let si = 0; si <= SEGS; si++) {
                            const t    = si / SEGS
                            const bv   = bSlice[Math.min(si, SEGS - 1)] || 0
                            const petalW = Math.PI * 0.72 / folds
                            const ang  = (t - 0.5) * petalW
                            const r    = rInner + (rOuter - rInner) * (0.2 + bv * 0.8)
                            ctx.lineTo(Math.sin(ang) * r, Math.cos(ang) * r)
                        }
                        ctx.lineTo(0, rInner)
                        ctx.closePath()

                        const hue   = L.hueOff + root.treble * 0.18 + k / folds * 0.1
                        const alpha = 0.08 + energy * 0.35
                        ctx.fillStyle   = root.withAlpha(root.schemeColorCss(hue), alpha)
                        ctx.strokeStyle = root.withAlpha(root.schemeColorCss(hue + 0.04), 0.55 + energy * 0.45)
                        ctx.lineWidth   = 0.6
                        ctx.fill()
                        ctx.stroke()
                        ctx.restore()
                    }
                }
            }

            // Central jewel – glowing disc
            const jewR = R * (0.04 + root.rms * 0.08 + (root.gotBeat ? 0.03 : 0))
            const jg   = ctx.createRadialGradient(cx, cy, 0, cx, cy, jewR * 3)
            jg.addColorStop(0,   root.withAlpha(root.schemeColorCss(root.treble * 0.5 + 0.8), 1.0))
            jg.addColorStop(0.4, root.withAlpha(root.schemeColorCss(root.treble * 0.5 + 0.6), 0.50))
            jg.addColorStop(1,   "rgba(0,0,0,0)")
            ctx.beginPath()
            ctx.arc(cx, cy, jewR * 3, 0, 2 * Math.PI)
            ctx.fillStyle = jg
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy, jewR, 0, 2 * Math.PI)
            ctx.fillStyle = root.schemeColorCss(root.treble * 0.5 + 0.9)
            ctx.fill()
        }
    }
}


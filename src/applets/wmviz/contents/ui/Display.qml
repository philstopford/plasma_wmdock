// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMViz – Audio visualizer applet.
 *
 * Animates one of four visual effects driven by the current audio volume
 * level obtained from AudioManager:
 *
 *   bars    – classic equalizer-style frequency bars (randomly varied
 *             heights per band, envelope-following the volume level)
 *   wave    – scrolling sinusoidal waveform whose amplitude tracks volume
 *   circles – concentric rings that expand and fade with each beat
 *   plasma  – shifting colour-field (Lissajous-based plasma effect)
 *
 * Effect and colour scheme are user-selectable via the configuration dialog.
 */
Item {
    id: root

    // ----- configuration ---------------------------------------------------
    readonly property string effect:      Plasmoid.configuration.effect      || "bars"
    readonly property string colorScheme: Plasmoid.configuration.colorScheme || "green"

    // ----- colour helpers (CSS strings – required for Canvas fillStyle) ----
    function schemeColorCss(t) {
        // t in [0,1]; returns a CSS hsl() string for the active scheme
        switch (root.colorScheme) {
        case "blue":
            return "hsl(" + Math.round((0.58 + t * 0.05) * 360) + ",90%,"
                          + Math.round((0.3 + t * 0.4) * 100) + "%)"
        case "amber":
            return "hsl(" + Math.round((0.10 + t * 0.03) * 360) + ",100%,"
                          + Math.round((0.2 + t * 0.45) * 100) + "%)"
        case "rainbow":
            return "hsl(" + Math.round(t * 0.75 * 360) + ",100%,"
                          + Math.round((0.35 + t * 0.2) * 100) + "%)"
        default: // green
            return "hsl(" + Math.round((0.33 - t * 0.08) * 360) + ",100%,"
                          + Math.round((0.15 + t * 0.4) * 100) + "%)"
        }
    }

    function ringColorCss(alpha) {
        switch (root.colorScheme) {
        case "blue":   return "rgba(26,153,255,"  + alpha.toFixed(2) + ")"
        case "amber":  return "rgba(255,128,0,"   + alpha.toFixed(2) + ")"
        default:       return "rgba(26,230,26,"   + alpha.toFixed(2) + ")"
        }
    }

    // ----- volume tracking -------------------------------------------------
    property real smoothVol: 0        // 0–1, smoothed
    property real peakVol:   0        // 0–1, slow-falling peak

    Connections {
        target: AudioManager
        function onVolumeChanged() {
            const v = Math.min(1, AudioManager.volume / 100)
            root.smoothVol = root.smoothVol * 0.6 + v * 0.4
            if (v > root.peakVol) root.peakVol = v
        }
    }

    // ----- per-effect state ------------------------------------------------
    // bars
    property var barHeights: []
    property var barTargets: []

    // wave
    property real wavePhase: 0
    property var  waveHistory: []

    // circles
    property var  rings: []    // [{r, alpha}]

    // plasma
    property real plasmaT: 0

    // ----- shared animation ticker ----------------------------------------
    property int  tickCount: 0

    Timer {
        id: animTimer
        interval: 40          // ~25 fps
        repeat:   true
        running:  true
        onTriggered: {
            root.tickCount++

            // Decay peak volume slowly
            root.peakVol = Math.max(0, root.peakVol - 0.01)

            switch (root.effect) {
            case "wave":    tickWave();    break
            case "circles": tickCircles(); break
            case "plasma":  tickPlasma();  break
            default:        tickBars();    break
            }
            canvas.requestPaint()
        }
    }

    // ----- bars tick -------------------------------------------------------
    function tickBars() {
        const N = 12
        if (root.barHeights.length !== N) {
            root.barHeights = new Array(N).fill(0)
            root.barTargets  = new Array(N).fill(0)
        }
        const bh = [...root.barHeights]
        const bt = [...root.barTargets]
        const vol = root.smoothVol
        for (let i = 0; i < N; i++) {
            // Randomise targets occasionally
            if (root.tickCount % 3 === i % 3) {
                bt[i] = Math.max(0.02, vol * (0.4 + Math.random() * 0.6))
            }
            // Ease toward target
            bh[i] = bh[i] * 0.7 + bt[i] * 0.3
        }
        root.barHeights = bh
        root.barTargets  = bt
    }

    // ----- wave tick -------------------------------------------------------
    function tickWave() {
        root.wavePhase = (root.wavePhase + 0.15) % (2 * Math.PI)
        let hist = [...root.waveHistory, root.smoothVol]
        if (hist.length > 64) hist = hist.slice(hist.length - 64)
        root.waveHistory = hist
    }

    // ----- circles tick ----------------------------------------------------
    function tickCircles() {
        // Spawn a new ring when volume jumps
        let newRings = root.rings.filter(r => r.alpha > 0.02)
            .map(r => ({ r: r.r + 1.2, alpha: r.alpha * 0.93 }))

        if (root.smoothVol > 0.15 && root.tickCount % 4 === 0) {
            newRings.push({ r: 4, alpha: root.smoothVol })
        }
        root.rings = newRings
    }

    // ----- plasma tick -----------------------------------------------------
    function tickPlasma() {
        root.plasmaT = (root.plasmaT + 0.04) % (2 * Math.PI)
    }

    // ----- background ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#1a1a1a"
        border.width: 1
    }

    // ---- title label -------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 1 }
        text: "VIZ"
        color: root.schemeColorCss(0.8)
        font { pixelSize: parent.height * 0.10; family: "monospace"; bold: true }
    }

    // ----- main canvas -----------------------------------------------------
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
        renderTarget: Canvas.Image   // software path – reliable in all compositors

        Component.onCompleted: Qt.callLater(requestPaint)

        onPaint: {
            const ctx = getContext("2d")
            if (!ctx) return
            ctx.clearRect(0, 0, width, height)

            switch (root.effect) {
            case "wave":    paintWave(ctx);    break
            case "circles": paintCircles(ctx); break
            case "plasma":  paintPlasma(ctx);  break
            default:        paintBars(ctx);    break
            }
        }

        // ---- bars ---------------------------------------------------------
        function paintBars(ctx) {
            const w = width, h = height
            const bh = root.barHeights
            if (!bh || bh.length === 0) return
            const N  = bh.length
            const bw = (w - N + 1) / N

            for (let i = 0; i < N; i++) {
                const frac  = bh[i]
                const barH  = Math.max(1, frac * h)
                ctx.fillStyle = root.schemeColorCss(frac)
                ctx.fillRect(Math.round(i * (bw + 1)), h - barH, Math.max(1, Math.floor(bw)), barH)
            }

            // Peak dot
            if (root.peakVol > 0.05) {
                const ph = Math.round(root.peakVol * h)
                ctx.fillStyle = "#ffffff"
                ctx.fillRect(0, h - ph, w, 1)
            }
        }

        // ---- wave ---------------------------------------------------------
        function paintWave(ctx) {
            const w = width, h = height
            const hist = root.waveHistory
            if (hist.length < 2) return
            const mid  = h / 2
            const step = w / (hist.length - 1)

            ctx.strokeStyle = root.schemeColorCss(root.smoothVol)
            ctx.lineWidth   = 1.5
            ctx.beginPath()
            for (let i = 0; i < hist.length; i++) {
                const amp = hist[i] * mid * 0.9
                const y   = mid + Math.sin(root.wavePhase + i * 0.4) * amp
                if (i === 0) ctx.moveTo(0, y)
                else         ctx.lineTo(i * step, y)
            }
            ctx.stroke()

            // Centre line
            ctx.strokeStyle = root.schemeColorCss(0.2)
            ctx.lineWidth   = 0.5
            ctx.beginPath()
            ctx.moveTo(0, mid); ctx.lineTo(w, mid)
            ctx.stroke()
        }

        // ---- circles -------------------------------------------------------
        function paintCircles(ctx) {
            const cx = width / 2, cy = height / 2
            const rings = root.rings

            for (let i = 0; i < rings.length; i++) {
                const ring = rings[i]
                ctx.strokeStyle = root.ringColorCss(ring.alpha)
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.arc(cx, cy, ring.r, 0, 2 * Math.PI)
                ctx.stroke()
            }

            // Central dot (volume indicator)
            const r = Math.max(2, root.smoothVol * Math.min(cx, cy) * 0.4)
            ctx.fillStyle = root.schemeColorCss(root.smoothVol)
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.fill()
        }

        // ---- plasma -------------------------------------------------------
        function paintPlasma(ctx) {
            const w = width, h = height
            const t = root.plasmaT
            const vol = root.smoothVol + 0.3   // minimum animation even when silent

            // Draw a coarse grid (~8×8 cells) for performance on small canvas
            const step = 8
            for (let y = 0; y < h; y += step) {
                for (let x = 0; x < w; x += step) {
                    const nx = x / w, ny = y / h
                    const v = Math.sin(nx * 6 + t) +
                              Math.sin(ny * 6 + t * 1.3) +
                              Math.sin((nx + ny) * 4 + t * 0.7) +
                              Math.sin(Math.sqrt(nx * nx + ny * ny) * 8 + t * vol * 2)
                    const norm = (v + 4) / 8    // 0–1
                    ctx.fillStyle = root.schemeColorCss(norm)
                    ctx.fillRect(x, y, step, step)
                }
            }
        }
    }
}

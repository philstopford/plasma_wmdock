// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMLava – Lava lamp simulation driven by system heat.
 *
 * Renders metaball-style blobs that float inside a glass container.
 * At idle the blobs rest at the bottom; as CPU load rises they heat up,
 * rise to the top, and move more turbulently – just like a real lava lamp.
 *
 * Algorithm:
 *   Each blob has a position (x, y) and radius r.  Every ~50 ms the canvas
 *   is redrawn by evaluating the metaball scalar field on a coarse 4×4 grid.
 *   Blob buoyancy is biased upward when heat is high and downward when idle.
 *   Speed and turbulence both scale linearly with the smoothed CPU heat.
 *
 * System heat source: SystemMonitor.cpuUsage (smoothed exponentially).
 * Configuration: color scheme, blob count.
 */
Item {
    id: root

    readonly property string blobColor: Plasmoid.configuration.blobColor || "red"
    readonly property int    blobCount: Math.max(2, Math.min(10, Plasmoid.configuration.blobCount || 5))

    // ----- system heat (0 = idle, 1 = fully loaded) -------------------------
    // Smoothed exponentially so the lamp reacts gradually to load changes.
    property real heat: 0.1

    Connections {
        target: SystemMonitor
        function onCpuUsageChanged() {
            const raw = Math.min(1.0, Math.max(0.0, SystemMonitor.cpuUsage / 100.0))
            root.heat = root.heat * 0.85 + raw * 0.15
        }
    }

    // Speed multiplier: 0.2 at idle → 3.0 at full load
    readonly property real speedMult: 0.2 + root.heat * 2.8

    // ----- blob state -------------------------------------------------------
    property var blobs: []

    // ----- colour helpers (CSS strings – required for Canvas fillStyle) -----
    function blobFillCss(intensity) {
        // intensity: 0 (deep/dim) → 1 (peak/bright)
        switch (root.blobColor) {
        case "blue":
            return "hsl(" + Math.round(209 + intensity * 22) + ",95%,"
                          + Math.round(25  + intensity * 35) + "%)"
        case "green":
            return "hsl(" + Math.round(108 + intensity * 18) + ",95%,"
                          + Math.round(20  + intensity * 35) + "%)"
        case "purple":
            return "hsl(" + Math.round(270 + intensity * 18) + ",90%,"
                          + Math.round(25  + intensity * 30) + "%)"
        case "rainbow":
            return "hsl(" + Math.round(intensity * 252) + ",100%,"
                          + Math.round(30  + intensity * 25) + "%)"
        default: // red/orange
            return "hsl(" + Math.round(11  + intensity * 29) + ",100%,"
                          + Math.round(20  + intensity * 40) + "%)"
        }
    }

    function glowCss(glow) {
        // Soft surface glow tinted to the colour scheme.
        // RGB components are scaled fractions of 255 chosen to match each scheme's hue.
        switch (root.blobColor) {
        case "blue":   // ~hsl(210): R=0, G=20%, B=50%
            return "rgba(0,"   + Math.round(glow * 51)  + "," + Math.round(glow * 128) + "," + (glow * 0.5).toFixed(2) + ")"
        case "green":  // ~hsl(108): R=0, G=40%, B=0
            return "rgba(0,"   + Math.round(glow * 102) + ",0,"                               + (glow * 0.5).toFixed(2) + ")"
        case "purple": // ~hsl(270): R=25%, G=0, B=30%
            return "rgba(" + Math.round(glow * 64) + ",0," + Math.round(glow * 77)    + "," + (glow * 0.5).toFixed(2) + ")"
        default:       // red/orange/rainbow: R=30%, G=5%, B=0
            return "rgba(" + Math.round(glow * 77) + "," + Math.round(glow * 13) + ",0," + (glow * 0.5).toFixed(2) + ")"
        }
    }

    function fluidColor() {
        switch (root.blobColor) {
        case "blue":   return "#000818"
        case "green":  return "#000c00"
        case "purple": return "#0a0010"
        case "rainbow":return "#080808"
        default:       return "#110000"
        }
    }

    // ----- initialise blobs ------------------------------------------------
    function initBlobs() {
        const w = canvas.width  > 4 ? canvas.width  : 64
        const h = canvas.height > 4 ? canvas.height : 64

        let bs = []
        for (let i = 0; i < root.blobCount; i++) {
            bs.push({
                x:     w * (0.2 + Math.random() * 0.6),
                y:     h * (0.55 + Math.random() * 0.35), // start in lower half
                r:     Math.min(w, h) * (0.12 + Math.random() * 0.10),
                vy:    -(Math.random() * 0.3),
                vx:    (Math.random() - 0.5) * 0.2,
                phase: Math.random() * Math.PI * 2
            })
        }
        root.blobs = bs
    }

    // ----- physics tick ----------------------------------------------------
    function tickBlobs() {
        if (root.blobs.length !== root.blobCount) {
            initBlobs()
            return
        }

        const w  = canvas.width  > 4 ? canvas.width  : 64
        const h  = canvas.height > 4 ? canvas.height : 64
        const sm = root.speedMult
        const ht = root.heat

        let bs = root.blobs.map(b => Object.assign({}, b))
        for (let i = 0; i < bs.length; i++) {
            const b = bs[i]
            b.phase += 0.05 * sm

            // Natural height: cool → bottom 80%, hot → upper 20–60%
            const naturalY = h * (0.80 - ht * 0.60)
            b.vy += (naturalY - b.y) * 0.002 * (0.5 + sm) // buoyancy
            b.vy += Math.sin(b.phase) * 0.015 * sm         // wobble
            b.vx += (Math.random() - 0.5) * 0.008 * (1 + ht * 2) // turbulence

            // Damping
            b.vy *= 0.97
            b.vx *= 0.96

            b.x += b.vx * sm
            b.y += b.vy * sm

            // Clamp to canvas bounds
            const margin = b.r * 0.4
            if (b.x < margin)     { b.x = margin;     b.vx =  Math.abs(b.vx) * 0.5 }
            if (b.x > w - margin) { b.x = w - margin; b.vx = -Math.abs(b.vx) * 0.5 }
            if (b.y < margin)     { b.y = margin;     b.vy =  Math.abs(b.vy) * 0.5 }
            if (b.y > h - margin) { b.y = h - margin; b.vy = -Math.abs(b.vy) * 0.5 }
        }
        root.blobs = bs
    }

    // ----- animation timer -------------------------------------------------
    Timer {
        interval: 50      // ~20 fps
        repeat:   true
        running:  true
        onTriggered: {
            root.tickBlobs()
            canvas.requestPaint()
        }
    }

    // ----- background (glass container) ------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  root.fluidColor()
        radius: 4
        border.color: Qt.lighter(root.fluidColor(), 3)
        border.width: 1
    }

    // ----- metaball canvas -------------------------------------------------
    Canvas {
        id: canvas
        anchors { fill: parent; margins: 2 }
        renderTarget: Canvas.Image   // software path – reliable in all compositors

        Component.onCompleted: {
            root.initBlobs()
            Qt.callLater(requestPaint)
        }
        onWidthChanged:  root.initBlobs()
        onHeightChanged: root.initBlobs()

        onPaint: {
            const ctx   = getContext("2d")
            if (!ctx) return
            const w     = width
            const h     = height
            const blobs = root.blobs

            ctx.clearRect(0, 0, w, h)
            if (!blobs || blobs.length === 0) return

            // Coarse pixel grid – each "pixel" is step×step
            const step = 4

            for (let py = 0; py < h; py += step) {
                for (let px = 0; px < w; px += step) {
                    let field = 0
                    for (let i = 0; i < blobs.length; i++) {
                        const dx = px - blobs[i].x
                        const dy = py - blobs[i].y
                        const r2 = blobs[i].r * blobs[i].r
                        const d2 = dx * dx + dy * dy
                        if (d2 > 0) field += r2 / d2
                    }

                    if (field >= 1.0) {
                        // Inside a blob (or merged blobs)
                        const intensity = Math.min(1, (field - 1.0) / 2.0)
                        ctx.fillStyle = root.blobFillCss(intensity)
                        ctx.fillRect(px, py, step, step)
                    } else {
                        // Subtle surface glow
                        const glow = Math.max(0, field - 0.5) * 2
                        if (glow > 0.02) {
                            ctx.fillStyle = root.glowCss(glow)
                            ctx.fillRect(px, py, step, step)
                        }
                    }
                }
            }
        }
    }

    // ----- glass rim highlight ---------------------------------------------
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 3
        radius: 4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: "rgba(255,255,255,0.18)" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}

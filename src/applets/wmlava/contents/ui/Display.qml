// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid

/**
 * WMLava – Lava lamp simulation applet.
 *
 * Renders metaball-style blobs that float up and down inside a glass
 * container, merging when close together – just like a classic lava lamp.
 *
 * Algorithm:
 *   Each blob has a position (x, y) and radius r.  Every frame the canvas
 *   is redrawn by evaluating the metaball scalar field at each pixel of a
 *   coarse 4×4 grid, thresholding at 1.0 to determine blob vs. fluid.
 *   Blobs float up when below mid-height and sink when above, with small
 *   random perturbations to keep things interesting.
 *
 * Configuration: color scheme, speed multiplier, blob count.
 */
Item {
    id: root

    readonly property string blobColor: Plasmoid.configuration.blobColor || "red"
    readonly property real   speedMult: Math.max(0.5, Math.min(5, Plasmoid.configuration.speed || 3)) * 0.4
    readonly property int    blobCount: Math.max(2, Math.min(10, Plasmoid.configuration.blobCount || 5))

    // ----- blob state (initialised when canvas is ready) -------------------
    property var blobs: []

    // Colour helpers
    function blobFill(field) {
        // field: 0 (deep) → 1 (peak)
        switch (root.blobColor) {
        case "blue":
            return Qt.hsla(0.58 + field * 0.06, 0.95, 0.25 + field * 0.35, 1)
        case "green":
            return Qt.hsla(0.30 + field * 0.05, 0.95, 0.20 + field * 0.35, 1)
        case "purple":
            return Qt.hsla(0.75 + field * 0.05, 0.90, 0.25 + field * 0.30, 1)
        case "rainbow":
            return Qt.hsla(field * 0.70, 1.0, 0.30 + field * 0.25, 1)
        default: // red/orange
            return Qt.hsla(0.03 + field * 0.08, 1.0, 0.20 + field * 0.40, 1)
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
        const w = canvas.width  || 64
        const h = canvas.height || 64
        if (w < 4 || h < 4) return

        let bs = []
        for (let i = 0; i < root.blobCount; i++) {
            bs.push({
                x:  w * (0.2 + Math.random() * 0.6),
                y:  h * (0.2 + Math.random() * 0.6),
                r:  Math.min(w, h) * (0.12 + Math.random() * 0.12),
                vy: (Math.random() - 0.5) * root.speedMult * 0.6,
                vx: (Math.random() - 0.5) * root.speedMult * 0.3,
                phase: Math.random() * Math.PI * 2
            })
        }
        root.blobs = bs
    }

    // ----- physics tick ----------------------------------------------------
    function tickBlobs() {
        const w  = canvas.width  || 64
        const h  = canvas.height || 64
        const sm = root.speedMult

        let bs = root.blobs.map(b => Object.assign({}, b))
        for (let i = 0; i < bs.length; i++) {
            const b = bs[i]
            b.phase += 0.05 * sm

            // Buoyancy: blobs float toward their "natural" y
            const naturalY = h * (0.25 + (i / bs.length) * 0.5)
            const buoyancy = (naturalY - b.y) * 0.0015 * sm
            b.vy += buoyancy
            b.vy += Math.sin(b.phase) * 0.02 * sm  // random wobble
            b.vx += (Math.random() - 0.5) * 0.01 * sm

            // Damping
            b.vy *= 0.98
            b.vx *= 0.97

            b.x += b.vx * sm
            b.y += b.vy * sm

            // Bounce off walls (soft)
            const margin = b.r * 0.5
            if (b.x < margin)          { b.x = margin;      b.vx = Math.abs(b.vx) * 0.5 }
            if (b.x > w - margin)      { b.x = w - margin;  b.vx = -Math.abs(b.vx) * 0.5 }
            if (b.y < margin)          { b.y = margin;      b.vy = Math.abs(b.vy) * 0.5 }
            if (b.y > h - margin)      { b.y = h - margin;  b.vy = -Math.abs(b.vy) * 0.5 }
        }
        root.blobs = bs
    }

    // ----- animation timer -------------------------------------------------
    Timer {
        interval: 50      // ~20 fps
        repeat:   true
        running:  true
        onTriggered: {
            if (root.blobs.length !== root.blobCount)
                root.initBlobs()
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

        Component.onCompleted: root.initBlobs()

        onWidthChanged:  root.initBlobs()
        onHeightChanged: root.initBlobs()

        onPaint: {
            const ctx    = getContext("2d")
            const w      = width,  h = height
            const blobs  = root.blobs

            ctx.clearRect(0, 0, w, h)

            if (!blobs || blobs.length === 0) return

            // Coarse pixel grid – each "pixel" is step×step
            const step = 4

            for (let py = 0; py < h; py += step) {
                for (let px = 0; px < w; px += step) {
                    // Metaball field value at (px, py)
                    let field = 0
                    for (let i = 0; i < blobs.length; i++) {
                        const dx = px - blobs[i].x
                        const dy = py - blobs[i].y
                        const r2 = blobs[i].r * blobs[i].r
                        const d2 = dx * dx + dy * dy
                        if (d2 > 0)
                            field += r2 / d2
                    }

                    if (field >= 1.0) {
                        // Inside a blob (or merged blobs)
                        const intensity = Math.min(1, (field - 1.0) / 2.0)
                        ctx.fillStyle = root.blobFill(intensity)
                        ctx.fillRect(px, py, step, step)
                    } else {
                        // Fluid background with slight glow near surface
                        const glow = Math.max(0, field - 0.5) * 2
                        if (glow > 0.02) {
                            ctx.fillStyle = Qt.rgba(
                                glow * (root.blobColor === "blue"  ? 0.0
                                      : root.blobColor === "green" ? 0.0 : 0.3),
                                glow * (root.blobColor === "green" ? 0.4
                                      : root.blobColor === "blue"  ? 0.2 : 0.05),
                                glow * (root.blobColor === "blue"  ? 0.5 : 0.0),
                                glow * 0.5
                            )
                            ctx.fillRect(px, py, step, step)
                        }
                        // else: transparent – clearRect already handled it
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

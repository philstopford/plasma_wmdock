// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMLava – Lava lamp simulation driven by system heat.
 *
 * Renders metaball-style blobs that flow inside a glass container.
 * The outer walls are modelled as colder, creating a convective circulation:
 * the central column rises while the wall columns sink, with horizontal return
 * flow at top and bottom – like a classic convection cell.
 * As CPU load rises, blobs move faster and more turbulently.
 * Nearby blobs merge (area-weighted, momentum-conserving); large blobs split.
 *
 * Algorithm:
 *   Each blob has a position (x, y), radius r, velocity (vx, vy) and a phase
 *   offset for organic wobble.  Every ~50 ms the canvas is redrawn by
 *   evaluating the metaball scalar field on a coarse 4×4 pixel grid.
 *   Forces applied each tick:
 *     • Convective vortex  – cold-wall driven circulation (dominant)
 *     • Residual buoyancy  – overall upward push scaled by heat
 *     • Organic wobble     – sinusoidal perturbation
 *     • Random turbulence  – small stochastic kick
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
        if (root.blobs.length === 0) { initBlobs(); return }

        const w  = canvas.width  > 4 ? canvas.width  : 64
        const h  = canvas.height > 4 ? canvas.height : 64
        const cx = w / 2,  cy = h / 2
        const sm = root.speedMult
        const ht = root.heat
        // Blob radius bounds (fraction of shorter side)
        const minR = Math.min(w, h) * 0.08
        const maxR = Math.min(w, h) * 0.30

        // Physics tuning constants
        // xn² > RISE_THRESHOLD → blob is in wall region and sinks; < threshold → rises
        const RISE_THRESHOLD       = 0.28   // centre fraction² that rises (≈53% width)
        const MERGE_THRESH_FACTOR  = 0.70   // merge when dist < factor * (r_a + r_b)
        const SPLIT_POS_OFFSET     = 0.40   // daughter centre offset as fraction of new r
        const SPLIT_VEL_KICK       = 0.35   // speed imparted to each daughter on split

        // Deep-copy so QML property binding fires on reassignment.
        let bs = root.blobs.map(b => Object.assign({}, b))

        // ── 1. Forces ─────────────────────────────────────────────────────────
        for (let i = 0; i < bs.length; i++) {
            const b = bs[i]
            b.phase += 0.04 * sm

            // Normalised position: -1 = left/top wall, +1 = right/bottom wall
            const xn = (b.x - cx) / Math.max(1, cx)
            const yn = (b.y - cy) / Math.max(1, cy)

            // Convective circulation driven by cold outer walls:
            //  • Vertical: central column rises (xn≈0 → up), wall columns sink (|xn|≈1 → down)
            //  • Horizontal: outward near top (yn<0), inward near bottom (yn>0)
            // heightZoneFactor clamps yn to [-1,1] with a 3× amplification so only
            // the outer thirds of the vertical extent drive horizontal return flow.
            const heightZoneFactor = Math.max(-1, Math.min(1, yn * 3))
            b.vx -= 0.06 * ht * xn * heightZoneFactor          // horizontal return flow
            b.vy += 0.06 * ht * (xn * xn - RISE_THRESHOLD)     // up at centre, down at walls

            // Residual heat buoyancy (all hot blobs want to rise a little)
            b.vy -= ht * 0.003

            // Organic wobble
            b.vy += Math.sin(b.phase * 1.1) * 0.008 * sm
            b.vx += Math.cos(b.phase * 0.7) * 0.005 * sm

            // Small random turbulence
            b.vx += (Math.random() - 0.5) * 0.004 * (1 + ht)
            b.vy += (Math.random() - 0.5) * 0.003 * (1 + ht)

            // Velocity damping
            b.vx *= 0.96
            b.vy *= 0.96

            // Integrate position
            b.x += b.vx * sm
            b.y += b.vy * sm

            // Elastic bounce off container walls
            const margin = b.r * 0.30
            if (b.x < margin)     { b.x = margin;     b.vx =  Math.abs(b.vx) * 0.50 }
            if (b.x > w - margin) { b.x = w - margin; b.vx = -Math.abs(b.vx) * 0.50 }
            if (b.y < margin)     { b.y = margin;     b.vy =  Math.abs(b.vy) * 0.50 }
            if (b.y > h - margin) { b.y = h - margin; b.vy = -Math.abs(b.vy) * 0.50 }
        }

        // ── 2. Merging ────────────────────────────────────────────────────────
        // When two blob centres are within MERGE_THRESH_FACTOR*(r_a+r_b), absorb
        // the smaller into the larger (area-weighted, momentum-conserving).
        const absorbed = new Array(bs.length).fill(false)
        const postMerge = []
        for (let i = 0; i < bs.length; i++) {
            if (absorbed[i]) continue
            let a = bs[i]
            for (let j = i + 1; j < bs.length; j++) {
                if (absorbed[j]) continue
                const dx    = a.x - bs[j].x
                const dy    = a.y - bs[j].y
                const dist2 = dx * dx + dy * dy
                const thresh = (a.r + bs[j].r) * MERGE_THRESH_FACTOR
                if (dist2 < thresh * thresh) {
                    const ra2 = a.r * a.r,  rb2 = bs[j].r * bs[j].r
                    const tot = ra2 + rb2
                    a = {
                        x:     (a.x  * ra2 + bs[j].x  * rb2) / tot,
                        y:     (a.y  * ra2 + bs[j].y  * rb2) / tot,
                        vx:    (a.vx * ra2 + bs[j].vx * rb2) / tot,
                        vy:    (a.vy * ra2 + bs[j].vy * rb2) / tot,
                        r:     Math.min(maxR, Math.sqrt(tot)),
                        phase: a.phase
                    }
                    absorbed[j] = true
                }
            }
            postMerge.push(a)
        }
        bs = postMerge

        // ── 3. Splitting oversized blobs ──────────────────────────────────────
        // A blob that grew beyond maxR breaks into two equal-area daughters.
        // Only split if total count is below twice the target (prevents explosions).
        const canSplit = bs.length < root.blobCount * 2
        const postSplit = []
        for (let i = 0; i < bs.length; i++) {
            const b = bs[i]
            if (canSplit && b.r > maxR) {
                const nr    = b.r / Math.SQRT2
                const angle = Math.random() * Math.PI * 2
                const off   = nr * SPLIT_POS_OFFSET
                postSplit.push(
                    { x: b.x + Math.cos(angle) * off,
                      y: b.y + Math.sin(angle) * off,
                      r: nr,
                      vx: b.vx + Math.cos(angle) * SPLIT_VEL_KICK,
                      vy: b.vy + Math.sin(angle) * SPLIT_VEL_KICK,
                      phase: b.phase },
                    { x: b.x - Math.cos(angle) * off,
                      y: b.y - Math.sin(angle) * off,
                      r: nr,
                      vx: b.vx - Math.cos(angle) * SPLIT_VEL_KICK,
                      vy: b.vy - Math.sin(angle) * SPLIT_VEL_KICK,
                      phase: b.phase + Math.PI }
                )
            } else {
                postSplit.push(b)
            }
        }
        bs = postSplit

        // ── 4. Respawn when blobs are lost to repeated merging ─────────────────
        while (bs.length < root.blobCount) {
            bs.push({
                x:     w * (0.25 + Math.random() * 0.50),
                y:     h * (0.55 + Math.random() * 0.38),
                r:     Math.max(minR, Math.min(maxR * 0.6, Math.min(w, h) * (0.09 + Math.random() * 0.09))),
                vx:    (Math.random() - 0.5) * 0.20,
                vy:   -(Math.random() * 0.25),
                phase: Math.random() * Math.PI * 2
            })
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
            GradientStop { position: 0.5; color: "#2effffff" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}

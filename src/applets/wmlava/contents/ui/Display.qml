// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMLava – Lava lamp simulation driven by system heat.
 *
 * Renders metaball-style blobs that flow inside a glass container.
 * Physics model mirrors a real lava lamp:
 *   • A heat source at the BOTTOM (intensity ∝ CPU load) warms blobs
 *     that settle there, making them buoyant so they rise.
 *   • Away from the bottom blobs radiate heat and cool, becoming denser
 *     than the surrounding fluid and sinking back to the heat source.
 *   • At idle the bottom heater is very weak: all blobs cool, sink, and
 *     coalesce into a pool / landscape of dark cooled lava at the bottom.
 *   • At high CPU load blobs heat quickly, rise vigorously, and can
 *     stretch and split before sinking again.
 *
 * Each blob carries a temperature (0–1).  Colour intensity scales with
 * temperature so cold pooled lava appears dark and hot rising lava glows.
 *
 * Forces per tick (50 ms / 20 fps):
 *   • Gravity        – constant downward
 *   • Thermal buoyancy – upward proportional to blob.temp
 *   • Tiny organic wobble – amplitude gated by temperature
 *   • Minute random turbulence – only when blob is warm
 *   • Viscous drag   – strong enough to prevent jitter
 *
 * System heat source: SystemMonitor.cpuUsage (smoothed exponentially).
 * Configuration: color scheme, blob count.
 */
Item {
    id: root

    readonly property string blobColor: Plasmoid.configuration.blobColor || "red"
    readonly property int    blobCount: Math.max(2, Math.min(10, Plasmoid.configuration.blobCount || 5))
    readonly property int    renderResolution: Math.max(1, Math.min(4, Plasmoid.configuration.resolution || 1))

    // ----- system heat (0 = idle, 1 = fully loaded) -------------------------
    // Smoothed exponentially so the lamp reacts gradually to load changes.
    property real heat: 0.05

    Connections {
        target: SystemMonitor
        function onCpuUsageChanged() {
            const raw = Math.min(1.0, Math.max(0.0, SystemMonitor.cpuUsage / 100.0))
            // Faster smoothing (tau ≈ 5 ticks / 0.25 s) so the lamp reacts
            // promptly to load changes without jarring instant jumps.
            root.heat = root.heat * 0.80 + raw * 0.20
        }
    }

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

        // Scale the base radius so that fewer blobs are individually larger,
        // keeping visual density roughly constant across blob-count settings.
        // Reference count is 5; sqrt gives area-proportional scaling.
        const countScale = Math.sqrt(5.0 / root.blobCount)
        const minR   = Math.min(w, h) * 0.07
        const maxR   = Math.min(w, h) * 0.30

        let bs = []
        for (let i = 0; i < root.blobCount; i++) {
            const r = Math.max(minR, Math.min(maxR,
                          Math.min(w, h) * (0.10 + Math.random() * 0.10) * countScale))
            bs.push({
                x:     w * (0.15 + Math.random() * 0.70),
                y:     h * (0.65 + Math.random() * 0.30), // start cold at the bottom
                r:     r,
                vy:    0,
                vx:    (Math.random() - 0.5) * 0.1,
                phase: Math.random() * Math.PI * 2,
                temp:  0.25  // start pre-warmed so blobs reach breakeven within ~3 s at moderate load
            })
        }
        root.blobs = bs
    }

    // ----- physics tick ----------------------------------------------------
    //
    // Real lava lamp model:
    //   GRAVITY pulls every blob downward at a constant rate.
    //   BUOYANCY pushes a blob upward in proportion to its temperature.
    //   A blob at the BOTTOM of the container gains heat proportional to
    //     the current CPU load (the "lamp bulb").
    //   A blob anywhere else cools gradually.
    //   At idle: all blobs stay cold, gravity wins, they pool at the bottom.
    //   At high load: bottom blobs heat up, become buoyant, rise, cool at
    //     the top, sink back – a true convective cycle.
    //
    // Tuning targets (50 ms tick / 20 fps, typical canvas ~60-100 px):
    //   Terminal sink speed  ≈ 0.8 px/tick (≈ 2 s to cross canvas at idle)
    //   Terminal rise speed  ≈ 1.0 px/tick (≈ 1.5 s at full load)
    //   Heat-to-breakeven    ≈ 3 s at 50% CPU
    //   Full cool-down       ≈ 6 s after CPU drops to idle
    //
    function tickBlobs() {
        if (root.blobs.length === 0) { initBlobs(); return }

        const w  = canvas.width  > 4 ? canvas.width  : 64
        const h  = canvas.height > 4 ? canvas.height : 64
        const ht = root.heat   // 0 = idle, 1 = full load

        const minR = Math.min(w, h) * 0.07
        const maxR = Math.min(w, h) * 0.30

        // ── Physics constants ─────────────────────────────────────────────────
        // These are read from Plasmoid.configuration so users can tune them
        // via the config dialog without needing to rebuild.
        // Net force = BUOYANCY*temp - GRAVITY.  Breakeven temp = GRAVITY/BUOYANCY.
        // At the default breakeven ≈ 0.44 the blob is neutrally buoyant.
        const GRAVITY        = Plasmoid.configuration.gravity     // px/tick² downward
        const BUOYANCY       = Plasmoid.configuration.buoyancy    // px/tick² upward at temp=1
        // Blobs with y > HEAT_ZONE_Y * h are in the bottom heat zone (canvas y
        // increases downward, so this selects the lower portion of the container).
        const HEAT_ZONE_Y    = Plasmoid.configuration.heatZoneY   // generous bottom zone so blobs heat reliably
        const HEAT_RATE      = Plasmoid.configuration.heatRate    // temp/tick gained in heat zone
        const COOL_RATE      = Plasmoid.configuration.coolRate    // temp/tick lost outside heat zone
        // Viscous drag gives the lazy flow of real wax (terminal rise ≈ 1 px/tick).
        const DRAG           = Plasmoid.configuration.drag
        // Merge threshold: blobs merge when centres are within factor*(ra+rb).
        // Reduced from 0.70 → 0.52 so blobs must significantly overlap before
        // merging, preventing the entire mass from fusing into one large blob.
        const MERGE_THRESH   = 0.52
        // SPLIT_OFFSET must exceed MERGE_THRESH so daughters start safely separated.
        const SPLIT_OFFSET   = 0.80
        const SPLIT_KICK     = 0.30
        // Soft repulsion: blobs closer than REPULSE_THRESH*(ra+rb) but not yet
        // at the merge threshold push each other apart gently.  This breaks up
        // tight clusters and maintains multiple distinct blobs.
        const REPULSE_THRESH = 1.10
        const REPULSE_K      = 0.012   // repulsion acceleration coefficient

        // ── Effective heat: base minimum + CPU component ──────────────────────
        // baseHeat sets how active the lamp is at zero CPU load.  At the
        // default of 0.40 the lamp always cycles.  Setting it to 0.0 makes
        // the lamp respond only to actual CPU load.
        const baseHeat      = Plasmoid.configuration.baseHeat
        const effectiveHeat = baseHeat + ht * (1.0 - baseHeat)

        // Deep-copy so QML property binding fires on reassignment.
        let bs = root.blobs.map(b => Object.assign({}, b))

        // ── 1. Temperature exchange & forces ─────────────────────────────────
        for (let i = 0; i < bs.length; i++) {
            const b = bs[i]

            // margin per blob (20% of radius keeps centre inside canvas).
            const margin = b.r * 0.20

            // Slow phase advance for organic wobble (independent of heat)
            b.phase += 0.020

            // ─ Heat exchange ─────────────────────────────────────────────────
            if (b.y / h > HEAT_ZONE_Y) {
                // Near the bottom heater: absorb heat.  A base minimum ensures
                // blobs always cycle; CPU load makes the cycle faster.
                b.temp = Math.min(1.0, b.temp + effectiveHeat * HEAT_RATE)
            } else {
                // Away from heater: radiate heat. Cooling is slightly slowed
                // when CPU is high (blob doesn't fully cool before returning).
                b.temp = Math.max(0.0, b.temp - COOL_RATE * (1.0 - ht * 0.4))
            }

            // ─ Net vertical acceleration ──────────────────────────────────────
            // Positive = downward.  Negative = upward (buoyancy > gravity).
            const ay = GRAVITY - b.temp * BUOYANCY

            // ─ Floor normal force ─────────────────────────────────────────────
            // When a blob rests on the floor and net force is downward, the
            // floor provides a normal force that exactly cancels gravity.  This
            // keeps cold pooled lava perfectly still (no jiggling) until it
            // heats past breakeven and the net force turns upward, at which
            // point the blob lifts off naturally.
            // Note: threshold matches the position clamp below exactly so a
            // blob can't hover just above the clamp zone and get gravity applied.
            const onFloor = b.y >= h - margin
            const effectiveAy = (onFloor && ay > 0) ? 0.0 : ay

            // ─ Tiny organic wobble (scales with temperature to keep cold
            //   pooled blobs still) ─────────────────────────────────────────
            const wobble = b.temp * b.temp   // quadratic: very small when cold
            b.vx += Math.cos(b.phase * 0.7) * 0.007 * wobble
            b.vy += Math.sin(b.phase * 1.1) * 0.005 * wobble

            // ─ Turbulent convection (active across a wider temperature range)
            //   Models the internal convection currents that keep real lava lamps
            //   turbulent and prevent single-blob stagnation.
            if (b.temp > 0.20) {
                const t = b.temp - 0.20
                b.vx += (Math.random() - 0.5) * 0.014 * t
                b.vy += (Math.random() - 0.5) * 0.010 * t
            }

            // ─ Thermal plume kick: blobs in the heat zone get occasional lateral
            //   impulses so they detach from the pool at different positions,
            //   preventing all the wax from rising from one spot.
            if (b.y / h > HEAT_ZONE_Y && b.temp > 0.30 && Math.random() < 0.04) {
                b.vx += (Math.random() - 0.5) * 0.25 * effectiveHeat
            }

            // ─ Apply forces & drag ────────────────────────────────────────────
            b.vy += effectiveAy
            b.vx *= DRAG
            b.vy *= DRAG

            // ─ Integrate position ─────────────────────────────────────────────
            b.x += b.vx
            b.y += b.vy

            // ─ Wall constraints ───────────────────────────────────────────────
            // Side walls: gentle elastic rebound.
            // Top wall: gentle rebound (blobs can reach it when very hot).
            // Bottom floor: HARD STOP – any downward velocity is cancelled so
            //   blobs settle smoothly.  The normal-force above prevents the
            //   gravity/clamp oscillation that caused visible jiggling.
            if (b.x < margin)     { b.x = margin;     b.vx =  Math.abs(b.vx) * 0.20 }
            if (b.x > w - margin) { b.x = w - margin; b.vx = -Math.abs(b.vx) * 0.20 }
            if (b.y < margin)     { b.y = margin;     b.vy =  Math.abs(b.vy) * 0.15 }
            if (b.y > h - margin) { b.y = h - margin; if (b.vy > 0) b.vy = 0 }
        }

        // ── 1b. Soft inter-blob repulsion ────────────────────────────────────
        // Blobs that are close (REPULSE_THRESH contact radii) but not yet
        // overlapping get a gentle push apart.  This prevents pile-ups at the
        // base and maintains multiple distinct blobs even at low temperatures.
        for (let i = 0; i < bs.length; i++) {
            for (let j = i + 1; j < bs.length; j++) {
                const dx    = bs[i].x - bs[j].x
                const dy    = bs[i].y - bs[j].y
                const dist2 = dx * dx + dy * dy
                const contactDist = (bs[i].r + bs[j].r) * REPULSE_THRESH
                if (dist2 < contactDist * contactDist && dist2 > 0.01) {
                    const dist = Math.sqrt(dist2)
                    const nx   = dx / dist
                    const ny   = dy / dist
                    // Force scales with how deeply the blobs overlap the repulsion zone
                    const overlap = 1.0 - dist / contactDist
                    const fx = nx * REPULSE_K * overlap
                    const fy = ny * REPULSE_K * overlap
                    bs[i].vx += fx;  bs[i].vy += fy
                    bs[j].vx -= fx;  bs[j].vy -= fy
                }
            }
        }

        // ── 2. Merging ────────────────────────────────────────────────────────
        // When two blob centres are within MERGE_THRESH*(r_a+r_b), absorb
        // the smaller into the larger (area-weighted, momentum-conserving).
        // Temperature is also area-weighted so merged blobs inherit both temps.
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
                const thresh = (a.r + bs[j].r) * MERGE_THRESH
                if (dist2 < thresh * thresh) {
                    const ra2 = a.r * a.r,  rb2 = bs[j].r * bs[j].r
                    const tot = ra2 + rb2
                    a = {
                        x:     (a.x    * ra2 + bs[j].x    * rb2) / tot,
                        y:     (a.y    * ra2 + bs[j].y    * rb2) / tot,
                        vx:    (a.vx   * ra2 + bs[j].vx   * rb2) / tot,
                        vy:    (a.vy   * ra2 + bs[j].vy   * rb2) / tot,
                        // Do NOT cap radius here: if the merged blob exceeds maxR the
                        // split logic (pass 3) fires on this same tick and breaks it back
                        // into two daughters.  Capping at maxR would set r === maxR so the
                        // condition `b.r > maxR` would never be true and the blob would
                        // stay permanently oversized, creating a low-energy locked state.
                        r:     Math.sqrt(tot),
                        phase: a.phase,
                        temp:  (a.temp * ra2 + bs[j].temp * rb2) / tot
                    }
                    absorbed[j] = true
                }
            }
            postMerge.push(a)
        }
        bs = postMerge

        // ── 3. Splitting ──────────────────────────────────────────────────────
        // Two mechanisms, both area-conserving (total r² is invariant):
        //
        //  a) Hot split: a blob that grew beyond maxR while hot (temp > 0.55)
        //     breaks symmetrically into two equal daughters.  This models the
        //     necking of a rapidly-rising wax column.
        //
        //  b) Bottom fragmentation: a large blob sitting in the heat zone and
        //     warm enough (temp > 0.25) sheds a small rising bubble with ~3 %
        //     probability each tick.  This models non-uniform heating – part of
        //     the pooled wax warms faster and detaches.  The daughter takes
        //     FRAG_AREA_FRAC of the parent's area; the parent shrinks by the
        //     same amount.  No volume is created or destroyed.
        //
        // The cap (blobCount × 3) bounds the maximum blob count so the pixel
        // loop stays cheap while still allowing generous fragmentation.
        const canSplit      = bs.length < root.blobCount * 3
        // Fragmentation constants — 15 % area shed per bubble, raised probability
        // (0.03 → 0.07) so pools break into rising bubbles more readily under load.
        const FRAG_AREA_FRAC = 0.15
        const FRAG_KICK      = 0.28
        const FRAG_PROB      = 0.07   // probability per tick for bottom fragmentation
        const postSplit = []
        for (let i = 0; i < bs.length; i++) {
            const b = bs[i]
            if (canSplit && b.r > maxR && b.temp > 0.55) {
                // ── a) Hot split: symmetric, equal daughters ───────────────────
                const nr    = b.r / Math.SQRT2
                const angle = Math.random() * Math.PI * 2
                const off   = nr * SPLIT_OFFSET
                postSplit.push(
                    { x: b.x + Math.cos(angle) * off,
                      y: b.y + Math.sin(angle) * off,
                      r: nr,
                      vx: b.vx + Math.cos(angle) * SPLIT_KICK,
                      vy: b.vy + Math.sin(angle) * SPLIT_KICK,
                      phase: b.phase,
                      temp: b.temp },
                    { x: b.x - Math.cos(angle) * off,
                      y: b.y - Math.sin(angle) * off,
                      r: nr,
                      vx: b.vx - Math.cos(angle) * SPLIT_KICK,
                      vy: b.vy - Math.sin(angle) * SPLIT_KICK,
                      phase: b.phase + Math.PI,
                      temp: b.temp }
                )
            } else if (canSplit && b.r > minR * 2.0
                       && b.y / h > HEAT_ZONE_Y
                       && b.temp > 0.25
                       && Math.random() < FRAG_PROB) {
                // ── b) Bottom fragmentation: asymmetric bubble emission ────────
                // Parent shrinks; daughter (the bubble) rises with an upward kick.
                const parentR   = b.r * Math.sqrt(1.0 - FRAG_AREA_FRAC)
                const daughterR = b.r * Math.sqrt(FRAG_AREA_FRAC)
                // Daughter rises mostly upward with a slight random lateral spread.
                const angle = -Math.PI / 2 + (Math.random() - 0.5) * 0.8
                // Separate centres so daughter starts outside the merge threshold.
                const sep = parentR + daughterR
                postSplit.push(
                    // Shrunken parent stays in place
                    { x:     b.x,
                      y:     b.y,
                      r:     parentR,
                      vx:    b.vx,
                      vy:    b.vy,
                      phase: b.phase,
                      temp:  b.temp * 0.92 },   // parent loses a little heat to the departing bubble
                    // Rising daughter bubble
                    { x:     b.x + Math.cos(angle) * sep,
                      y:     b.y + Math.sin(angle) * sep,
                      r:     daughterR,
                      vx:    b.vx + Math.cos(angle) * FRAG_KICK,
                      vy:    b.vy + Math.sin(angle) * FRAG_KICK,
                      phase: b.phase + Math.PI,
                      temp:  Math.min(1.0, b.temp * 1.12) }   // bubble is slightly warmer
                )
            } else {
                postSplit.push(b)
            }
        }
        bs = postSplit

        // No respawn step: total lava volume is conserved across the simulation.
        // Merge conserves area: √(ra²+rb²) gives one blob whose area equals the
        // sum of the two originals.  Both split paths produce daughters whose
        // combined area equals the parent's.  The dynamic blob count emerges
        // from the heat/cool cycle naturally.

        root.blobs = bs
    }

    // ----- animation timer -------------------------------------------------
    Timer {
        interval: 50      // ~20 fps
        repeat:   true
        running:  true
        onTriggered: {
            root.tickBlobs()
            // Decouple paint from physics so GC pauses in the physics tick
            // don't block the compositor — the paint is scheduled for the
            // next event-loop iteration, giving Qt a chance to breathe.
            Qt.callLater(canvas.requestPaint)
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

            // Coarse pixel grid – higher resolution reduces the cell size.
            const step = Math.max(1, 5 - root.renderResolution)

            for (let py = 0; py < h; py += step) {
                for (let px = 0; px < w; px += step) {
                    let field  = 0
                    let tfield = 0   // temperature-weighted field accumulator
                    for (let i = 0; i < blobs.length; i++) {
                        const dx = px - blobs[i].x
                        const dy = py - blobs[i].y
                        const r2 = blobs[i].r * blobs[i].r
                        const d2 = dx * dx + dy * dy
                        if (d2 > 0) {
                            const contrib = r2 / d2
                            field  += contrib
                            tfield += contrib * blobs[i].temp
                        }
                    }
                    // Pixel temperature: weighted average of contributing blobs.
                    // This makes cold pooled lava appear dark and hot rising
                    // lava vivid, providing clear visual feedback of the cycle.
                    // Only computed when field is high enough that we will render.

                    if (field >= 1.0) {
                        // Inside a blob.  Colour intensity scales with temperature
                        // so cold lava is dark and hot lava is bright.
                        const pixTemp = tfield / field
                        const raw = Math.min(1, (field - 1.0) / 2.0)
                        const intensity = raw * (0.15 + pixTemp * 0.85)
                        ctx.fillStyle = root.blobFillCss(intensity)
                        ctx.fillRect(px, py, step, step)
                    } else if (field > 0.5) {
                        // Subtle surface glow – also temperature-modulated.
                        const pixTemp = tfield / field
                        const glow = (field - 0.5) * 2 * (0.08 + pixTemp * 0.92)
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

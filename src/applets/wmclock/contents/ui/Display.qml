// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid

/**
 * WMClock – Analog / Nixie-Tube clock applet styled after the classic wmclock dockapp.
 *
 * Modes (clockStyle config):
 *   analog  – Classic analog face with digital readout and optional date line.
 *   nixie   – Vintage nixie-tube display: HH*MM format.
 *             Orange digit glow, blue LED base pulsing per tube,
 *             red dot pulsing for the seconds separator (*).
 */
Item {
    id: root

    // Configuration bindings
    readonly property bool   use24Hour:       Plasmoid.configuration.use24Hour       ?? true
    readonly property bool   showSeconds:     Plasmoid.configuration.showSeconds     ?? true
    readonly property bool   showDate:        Plasmoid.configuration.showDate        ?? true
    readonly property string clockStyle:      Plasmoid.configuration.clockStyle      || "analog"
    readonly property string nixieTransition:  Plasmoid.configuration.nixieTransition || "slot"
    readonly property string nixieTubeStyle:   Plasmoid.configuration.nixieTubeStyle  || "classic"
    readonly property real   nixieGlowRadius:  Plasmoid.configuration.nixieGlowRadius > 0
                                               ? Plasmoid.configuration.nixieGlowRadius : 0.35

    // Repaint triggers
    onUse24HourChanged:       faceCanvas.requestPaint()
    onShowSecondsChanged:     faceCanvas.requestPaint()
    onShowDateChanged:        faceCanvas.requestPaint()
    onClockStyleChanged:      faceCanvas.requestPaint()
    onNixieTransitionChanged:  faceCanvas.requestPaint()
    onNixieTubeStyleChanged:   faceCanvas.requestPaint()
    onNixieGlowRadiusChanged:  faceCanvas.requestPaint()

    // -----------------------------------------------------------------------
    // Background
    // -----------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:   "#111"
        radius:  3
    }

    // -----------------------------------------------------------------------
    // Unified Canvas – handles both analog and nixie rendering
    // -----------------------------------------------------------------------
    Canvas {
        id: faceCanvas
        anchors.fill: parent
        antialiasing: true

        Timer {
            interval: root.showSeconds ? 1000 : 60000
            running:  true
            repeat:   true
            onTriggered: faceCanvas.requestPaint()
        }

        // 20 fps animation timer – only active in nixie mode for smooth pulsing
        // and digit transition animations.
        Timer {
            id: nixieAnimTimer
            interval: 50
            running:  root.clockStyle === "nixie"
            repeat:   true
            onTriggered: faceCanvas.requestPaint()
        }

        // ---- Nixie animation state (persists across paint calls) -------------
        property var  nxCurDig:    [-1,-1,-1,-1,-1]  // current digits (-1 = unset)
        property var  nxPrevDig:   [0,0,0,0,0]       // digits before last change
        property var  nxTgtDig:    [0,0,0,0,0]       // target digits
        property real nxAnimStart: 0                  // Date.now() at anim start
        property real nxAnimDurMs: 600               // anim duration ms
        property bool nxInAnim:    false             // animation in progress
        property var  nxFlicker:   [1.0,1.0,1.0,1.0,1.0]  // per-tube brightness
        property var  nxLastFlick: [0,0,0,0,0]      // per-tube last flicker ms

        Component.onCompleted: requestPaint()

        onPaint: {
            if (root.clockStyle === "nixie")
                paintNixie()
            else
                paintAnalog()
        }

        // ── Analog clock ────────────────────────────────────────────────────
        function paintAnalog() {
            const ctx = getContext("2d")
            const w = width, h = height

            ctx.clearRect(0, 0, w, h)

            const t    = new Date()
            const hrs  = t.getHours()   % 12 + t.getMinutes() / 60.0
            const mins = t.getMinutes() + t.getSeconds()  / 60.0
            const secs = t.getSeconds()

            // Layout: face centre at 37 % from top; radius 32 % of short side.
            // This leaves room for the digital time (~8 % below face) and the
            // date line (~9 % below that) — all within the widget boundary.
            const cx  = w / 2
            const cy  = h * 0.37
            const R   = Math.min(w, h) * 0.32

            const markR1 = R * 0.82
            const markR2 = R * 0.92
            const hourR  = R * 0.55
            const minR   = R * 0.80
            const secR   = R * 0.88
            const dotR   = R * 0.08

            // ---- Face circle ------------------------------------------------
            const grad = ctx.createRadialGradient(cx, cy - R*0.2, R*0.1, cx, cy, R)
            grad.addColorStop(0,   "#2a2a2a")
            grad.addColorStop(1,   "#111")
            ctx.beginPath()
            ctx.arc(cx, cy, R, 0, 2*Math.PI)
            ctx.fillStyle = grad
            ctx.fill()

            ctx.beginPath()
            ctx.arc(cx, cy, R, 0, 2*Math.PI)
            ctx.strokeStyle = "#555"
            ctx.lineWidth   = 1.5
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(cx, cy, R - 2, 0, 2*Math.PI)
            ctx.strokeStyle = "#222"
            ctx.lineWidth   = 1
            ctx.stroke()

            // ---- Hour marks ------------------------------------------------
            for (let i = 0; i < 12; i++) {
                const angle = (i / 12) * 2 * Math.PI - Math.PI / 2
                const r1 = (i % 3 === 0) ? markR1 * 0.92 : markR1
                ctx.beginPath()
                ctx.moveTo(cx + r1 * Math.cos(angle), cy + r1 * Math.sin(angle))
                ctx.lineTo(cx + markR2 * Math.cos(angle), cy + markR2 * Math.sin(angle))
                ctx.strokeStyle = (i % 3 === 0) ? "#aaa" : "#555"
                ctx.lineWidth   = (i % 3 === 0) ? 2 : 1
                ctx.stroke()
            }

            // ---- Minute marks -----------------------------------------------
            for (let i = 0; i < 60; i++) {
                if (i % 5 === 0) continue
                const angle = (i / 60) * 2 * Math.PI - Math.PI / 2
                ctx.beginPath()
                ctx.moveTo(cx + markR1 * 1.02 * Math.cos(angle),
                           cy + markR1 * 1.02 * Math.sin(angle))
                ctx.lineTo(cx + markR2 * Math.cos(angle),
                           cy + markR2 * Math.sin(angle))
                ctx.strokeStyle = "#333"
                ctx.lineWidth   = 0.8
                ctx.stroke()
            }

            // ---- Helper: draw a hand ----------------------------------------
            function drawHand(angleDeg, length, handWidth, color, shadow) {
                const a  = (angleDeg * Math.PI / 180) - Math.PI / 2
                const ex = cx + length * Math.cos(a)
                const ey = cy + length * Math.sin(a)
                if (shadow) {
                    ctx.beginPath()
                    ctx.moveTo(cx + 1, cy + 1)
                    ctx.lineTo(ex + 1, ey + 1)
                    ctx.strokeStyle = "rgba(0,0,0,0.5)"
                    ctx.lineWidth   = handWidth + 1
                    ctx.lineCap     = "round"
                    ctx.stroke()
                }
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(ex, ey)
                ctx.strokeStyle = color
                ctx.lineWidth   = handWidth
                ctx.lineCap     = "round"
                ctx.stroke()
            }

            drawHand(hrs * 30, hourR, 2.5, "#ddd",    true)
            drawHand(mins * 6, minR,  1.8, "#ccc",    true)
            if (root.showSeconds) {
                drawHand(secs * 6, secR, 1.0, "#e03030", false)
                const sa = (secs * 6 * Math.PI / 180) - Math.PI / 2
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(cx - secR * 0.2 * Math.cos(sa),
                           cy - secR * 0.2 * Math.sin(sa))
                ctx.strokeStyle = "#e03030"
                ctx.lineWidth   = 1.5
                ctx.stroke()
            }

            // Centre dot
            ctx.beginPath()
            ctx.arc(cx, cy, dotR, 0, 2*Math.PI)
            ctx.fillStyle = "#bbb"
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy, dotR * 0.5, 0, 2*Math.PI)
            ctx.fillStyle = "#444"
            ctx.fill()

            // ---- Digital time -----------------------------------------------
            const pad     = n => String(n).padStart(2, "0")
            const hours   = root.use24Hour ? t.getHours() : (t.getHours() % 12 || 12)
            const timeStr = pad(hours) + ":" + pad(t.getMinutes())
                          + (root.use24Hour ? "" : (t.getHours() < 12 ? " AM" : " PM"))
            const ty = cy + R + R * 0.36
            ctx.font         = "bold " + Math.round(R * 0.38) + "px monospace"
            ctx.textAlign    = "center"
            ctx.textBaseline = "middle"
            ctx.fillStyle = "#004400"
            ctx.fillText(timeStr, cx + 1, ty + 1)
            ctx.fillStyle = "#33dd33"
            ctx.fillText(timeStr, cx, ty)

            // ---- Date line --------------------------------------------------
            if (root.showDate) {
                const days    = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                const months  = ["Jan","Feb","Mar","Apr","May","Jun",
                                 "Jul","Aug","Sep","Oct","Nov","Dec"]
                const dateStr = days[t.getDay()] + " " +
                                String(t.getDate()).padStart(2,"0") + " " +
                                months[t.getMonth()]
                ctx.font      = Math.round(R * 0.28) + "px monospace"
                ctx.fillStyle = "#229922"
                ctx.fillText(dateStr, cx, ty + R * 0.44)
            }
        }

        // ── Nixie tube clock ────────────────────────────────────────────────
        //
        // Layout (W×H widget, typically 64×64):
        //   Five positions: H1 · H2 · [sep] · M1 · M2
        //   Each digit tube: tubeW wide, tubeH tall, starting at tubeY
        //   Blue LED strip below each digit tube (pulsing at 0.7 Hz, per-tube phase)
        //   Red pulsing separator dot (1 Hz sine, tracks wall-clock phase)
        //
        // Tube styles: classic (rounded rect), barrel (IN-14 bulge), slim (IN-18 narrow)
        // Transitions: slot (spin through extra steps), cascade, count, none
        //
        // roundRectPath: ctx.roundRect() was added in Qt 6.8 / Chrome 99.
        // Polyfill using arcTo() so the nixie mode works on Qt 6.5–6.7.
        function roundRectPath(ctx, x, y, w, h, r) {
            r = Math.min(r, w / 2, h / 2)
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.arcTo(x + w, y,     x + w, y + r,     r)
            ctx.lineTo(x + w, y + h - r)
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
            ctx.lineTo(x + r, y + h)
            ctx.arcTo(x,      y + h, x,      y + h - r, r)
            ctx.lineTo(x,     y + r)
            ctx.arcTo(x,      y,     x + r,  y,         r)
            ctx.closePath()
        }

        // drawTubePath – lays out the outer glass-envelope path for the given style.
        function drawTubePath(ctx, x, y, tW, tH, style) {
            if (style === "barrel") {
                // IN-14 style: sides bow outward ~12% using quadratic bezier
                const bx = Math.max(2, Math.ceil(tW * 0.12))
                ctx.moveTo(x + 3, y)
                ctx.lineTo(x + tW - 3, y)
                ctx.arcTo (x + tW, y,         x + tW, y + 3,       3)
                ctx.quadraticCurveTo(x + tW + bx, y + tH / 2, x + tW, y + tH - 3)
                ctx.arcTo (x + tW, y + tH,    x + tW - 3, y + tH,  3)
                ctx.lineTo(x + 3, y + tH)
                ctx.arcTo (x,     y + tH,     x, y + tH - 3,       3)
                ctx.quadraticCurveTo(x - bx,  y + tH / 2, x, y + 3)
                ctx.arcTo (x,     y,          x + 3, y,             3)
                ctx.closePath()
            } else if (style === "slim") {
                // IN-18 style: narrowed by 12% each side
                const ins = Math.max(1, Math.ceil(tW * 0.12))
                roundRectPath(ctx, x + ins, y, tW - 2 * ins, tH, 3)
            } else {
                // classic: rounded rectangle
                roundRectPath(ctx, x, y, tW, tH, 3)
            }
        }

        // drawNixieGlyph – renders a single digit '0'-'9' as stroked canvas paths
        // that mimic the wire-formed cathode shape of a real nixie tube.
        // (cx,cy) is the centre; (w,h) is the bounding cell for the digit.
        // All digit endpoints span cy ± h*0.46 (full cell height).
        // Bezier CONTROL POINTS may extend beyond ±0.46 to correctly pull curve
        // apices to the ±0.46 boundary — this is expected and correct for bezier curves.
        // Every digit is a SINGLE continuous sub-path (no moveTo break mid-digit,
        // except for the 4 which has two physically separate wires).
        // Caller must set ctx.strokeStyle, ctx.lineWidth, ctx.lineCap, ctx.lineJoin.
        function drawNixieGlyph(ctx, ch, cx, cy, w, h) {
            const X = f => cx + f * w
            const Y = f => cy + f * h
            ctx.beginPath()
            switch (ch) {
                case '0':
                    // Tall narrow oval spanning full cell height.
                    // Drawn as two bezier arcs (right half then left half) because
                    // QML Canvas ctx.ellipse(x,y,w,h) takes top-left+size, NOT
                    // the HTML5 centre+radii API — using bezier avoids that mismatch.
                    ctx.moveTo(cx, Y(-0.46))
                    ctx.bezierCurveTo(X(0.38), Y(-0.46), X(0.38), Y(0.46), cx, Y(0.46))
                    ctx.bezierCurveTo(X(-0.38), Y(0.46), X(-0.38), Y(-0.46), cx, Y(-0.46))
                    break
                case '1':
                    // Simple vertical stroke — no serif.
                    ctx.moveTo(cx, Y(-0.46))
                    ctx.lineTo(cx, Y(0.46))
                    break
                case '2':
                    // Top arc from lower-left, bowing to full height, sweeping right;
                    // diagonal down-left; horizontal base bar.
                    // Control points use Y(-0.55) to pull the arc apex to ≈ Y(-0.46).
                    ctx.moveTo(X(-0.30), Y(-0.16))
                    ctx.bezierCurveTo(X(-0.36), Y(-0.55), X(0.34), Y(-0.55), X(0.34), Y(-0.14))
                    ctx.bezierCurveTo(X(0.34), Y(0.08), X(-0.26), Y(0.22), X(-0.36), Y(0.46))
                    ctx.lineTo(X(0.36), Y(0.46))
                    break
                case '3':
                    // Two right-facing arcs spanning full height.
                    ctx.moveTo(X(-0.28), Y(-0.46))
                    ctx.bezierCurveTo(X(0.36), Y(-0.46), X(0.36), Y(-0.04), X(0.02), Y(-0.02))
                    ctx.bezierCurveTo(X(0.38), Y(0.00), X(0.38), Y(0.46), X(-0.28), Y(0.46))
                    break
                case '4':
                    // Angled left stroke down to crossbar (one wire).
                    // Separate right vertical (physically distinct cathode wire).
                    ctx.moveTo(X(-0.22), Y(-0.46))
                    ctx.lineTo(X(-0.30), Y(0.08))
                    ctx.lineTo(X(0.34), Y(0.08))
                    ctx.moveTo(X(0.16), Y(-0.46))
                    ctx.lineTo(X(0.16), Y(0.46))
                    break
                case '5':
                    // Top bar, left vertical half, lower right arc to full height.
                    ctx.moveTo(X(0.32), Y(-0.46))
                    ctx.lineTo(X(-0.32), Y(-0.46))
                    ctx.lineTo(X(-0.32), Y(-0.04))
                    ctx.bezierCurveTo(X(-0.30), Y(-0.04), X(0.34), Y(-0.06), X(0.34), Y(0.20))
                    ctx.bezierCurveTo(X(0.34), Y(0.46), X(-0.34), Y(0.46), X(-0.34), Y(0.20))
                    break
                case '6':
                    // Tail from top-right down left side into closed lower loop.
                    ctx.moveTo(X(0.26), Y(-0.46))
                    ctx.bezierCurveTo(X(-0.36), Y(-0.46), X(-0.36), Y(0.06), X(-0.36), Y(0.18))
                    ctx.bezierCurveTo(X(-0.36), Y(0.46), X(0.36), Y(0.46), X(0.36), Y(0.18))
                    ctx.bezierCurveTo(X(0.36), Y(-0.06), X(-0.32), Y(-0.06), X(-0.36), Y(0.18))
                    break
                case '7':
                    // Horizontal top bar, then diagonal stroke to bottom.
                    ctx.moveTo(X(-0.34), Y(-0.46))
                    ctx.lineTo(X(0.34), Y(-0.46))
                    ctx.bezierCurveTo(X(0.34), Y(-0.42), X(0.10), Y(-0.04), X(-0.12), Y(0.46))
                    break
                case '8':
                    // Single continuous figure-eight: wire crosses itself at the waist (cx,cy).
                    // Upper loop winds CW, lower loop winds CCW, so the path is self-consistent.
                    // X control points use ±0.38/±0.40 (upper vs lower) because the lower
                    // loop is deliberately wider — matching the asymmetric silhouette of
                    // real in-18 cathode wires where the bottom lobe is slightly larger.
                    // Upper loop (CW): waist → right arc to top → left arc back to waist.
                    ctx.moveTo(cx, cy)
                    ctx.bezierCurveTo(X(0.38), Y(0.00), X(0.36), Y(-0.46), cx, Y(-0.46))
                    ctx.bezierCurveTo(X(-0.36), Y(-0.46), X(-0.38), Y(0.00), cx, cy)
                    // Lower loop (CCW): waist → left arc to bottom → right arc back to waist.
                    ctx.bezierCurveTo(X(-0.40), Y(0.00), X(-0.38), Y(0.46), cx, Y(0.46))
                    ctx.bezierCurveTo(X(0.38), Y(0.46), X(0.40), Y(0.00), cx, cy)
                    break
                case '9':
                    // Single continuous path: oval loop (traced as two bezier halves)
                    // then tail — no moveTo break, so the whole shape is one wire.
                    // The path crosses itself at the right-side junction (X(0.34), Y(-0.20)).
                    // Control points use Y(-0.54) to pull the arc apex to ≈ Y(-0.46).
                    // Top arc CCW: right-junction → top → left.
                    ctx.moveTo(X(0.34), Y(-0.20))
                    ctx.bezierCurveTo(X(0.36), Y(-0.54), X(-0.36), Y(-0.54), X(-0.36), Y(-0.20))
                    // Bottom arc: left → bottom → right-junction.
                    ctx.bezierCurveTo(X(-0.36), Y(0.06), X(0.34), Y(0.06), X(0.34), Y(-0.20))
                    // Tail: right-junction curves down to base.
                    ctx.bezierCurveTo(X(0.36), Y(0.18), X(0.28), Y(0.46), X(0.04), Y(0.46))
                    break
                default:
                    return
            }
            ctx.stroke()
        }

        // nixieGetDigit – return the digit (0-9 integer) to display during a transition.
        function nixieGetDigit(idx, prevDig, tgtDig, elapsed, durMs, transition) {
            if (elapsed >= durMs) return tgtDig
            const t    = elapsed / durMs
            const ease = 1.0 - Math.pow(1.0 - t, 2.0)   // ease-out quadratic

            if (transition === "cascade") {
                // staggered per-tube: delays [0.0, 0.15, –, 0.30, 0.45] of total duration
                // Index 2 is the separator slot (not a digit); its delay value is unused.
                const delays = [0.0, 0.15, 0.0, 0.30, 0.45]
                const d      = delays[idx]
                const segLen = 0.40   // each tube animates for 40% of total duration
                if (t < d) return prevDig
                const localT = Math.min(1.0, (t - d) / segLen)
                const localE = 1.0 - Math.pow(1.0 - localT, 2.0)
                const dist   = (tgtDig - prevDig + 10) % 10 || 10
                return (prevDig + Math.floor(dist * localE)) % 10
            }
            if (transition === "count") {
                const dist = (tgtDig - prevDig + 10) % 10 || 10
                return (prevDig + Math.floor(dist * ease)) % 10
            }
            // slot (default): spin through 5 extra steps then land on target
            const extraSpin  = 5
            const dist       = (tgtDig - prevDig + 10) % 10 || 10
            const totalSteps = extraSpin + dist
            return (prevDig + Math.floor(totalSteps * ease)) % 10
        }

        function paintNixie() {
            const ctx = getContext("2d")
            const w = width, h = height
            ctx.clearRect(0, 0, w, h)

            const now  = Date.now()
            const t    = new Date()
            const hrs  = root.use24Hour ? t.getHours() : (t.getHours() % 12 || 12)
            const mins = t.getMinutes()

            const pad = n => String(n).padStart(2, "0")
            const hStr = pad(hrs)
            const mStr = pad(mins)
            // Target digit integers (0-9); index 2 is separator (use -1 as sentinel)
            const tgtDigs = [
                parseInt(hStr[0]), parseInt(hStr[1]),
                -1,
                parseInt(mStr[0]), parseInt(mStr[1])
            ]

            // ---- Animation state bookkeeping ----------------------------------
            // On very first paint nxCurDig is [-1,...]: accept tgt without animation
            if (nxCurDig[0] < 0) {
                nxCurDig  = tgtDigs.slice()
                nxTgtDig  = tgtDigs.slice()
                nxPrevDig = tgtDigs.slice()
            } else {
                // Check whether any digit changed since last paint
                let changed = false
                for (let i = 0; i < 5; i++) {
                    if (i === 2) continue
                    if (nxCurDig[i] !== tgtDigs[i]) { changed = true; break }
                }
                if (changed) {
                    nxPrevDig  = nxCurDig.slice()
                    nxTgtDig   = tgtDigs.slice()
                    nxAnimStart = now
                    nxInAnim   = true
                }
                nxCurDig = tgtDigs.slice()
            }

            const elapsed    = nxInAnim ? (now - nxAnimStart) : nxAnimDurMs
            const transition = root.nixieTransition || "slot"
            const tubeStyle  = root.nixieTubeStyle  || "classic"
            if (nxInAnim && elapsed >= nxAnimDurMs) nxInAnim = false

            // ---- Per-digit flicker (simulates cathode-poisoning avoidance) ----
            // Real nixie drivers periodically boost non-displayed cathodes to prevent
            // sputtering buildup. Here we simulate it with random brightness dips.
            const flickerWindowMs  = 45      // check for flicker event every 45 ms
            const flickerProbability = 0.035 // 3.5% chance of a dip per window
            const flickerMinBright = 0.28    // minimum brightness during a dip
            const flickerDipRange  = 0.52    // dip is in [minBright, minBright+range]
            const flickerRecovery  = 0.12    // brightness recovered per window
            let flicker   = nxFlicker.slice()
            let lastFlick = nxLastFlick.slice()
            for (let i = 0; i < 5; i++) {
                if (i === 2) continue
                if (now - lastFlick[i] > flickerWindowMs) {
                    lastFlick[i] = now
                    if (Math.random() < flickerProbability) {
                        flicker[i] = flickerMinBright + Math.random() * flickerDipRange
                    } else {
                        flicker[i] = Math.min(1.0, flicker[i] + flickerRecovery)
                    }
                }
            }
            nxFlicker   = flicker
            nxLastFlick = lastFlick

            // ---- Layout -------------------------------------------------------
            const tubeW  = Math.floor(w * 0.19)
            const tubeH  = Math.floor(h * 0.58)
            const sepW   = Math.floor(w * 0.08)
            const gap    = Math.max(1, Math.floor(w * 0.025))
            const tubeY  = Math.floor(h * 0.05)
            const totalW = 4 * tubeW + sepW + 4 * gap
            const startX = Math.floor((w - totalW) / 2)
            const posX   = [
                startX,
                startX + tubeW + gap,
                startX + 2 * (tubeW + gap),
                startX + 2 * (tubeW + gap) + sepW + gap,
                startX + 3 * (tubeW + gap) + sepW + gap
            ]
            const ledH         = Math.max(2, Math.floor(h * 0.055))
            const ledY         = tubeY + tubeH + gap
            const meshStep     = Math.max(3, Math.floor(tubeW * 0.30))

            // ---- Smooth wall-clock phase for pulsing --------------------------
            const phaseS  = now * 0.001
            // All pulsing at 1 Hz, synchronized (no per-tube offset)
            const pulse1hz = (Math.sin(phaseS * 2.0 * Math.PI) + 1.0) * 0.5

            // LED brightness: shared 1 Hz sine, same for all tubes
            const ledPulse = pulse1hz

            // Separator dot: exponential-decay flash at each second boundary
            // (mimics a red LED that fires briefly as each second ticks over)
            const LED_DECAY_RATE = 9.0   // 1.0 at t=0ms, ~0.01 at t=500ms
            const fracSec   = (now % 1000) / 1000
            const dotBright = Math.exp(-fracSec * LED_DECAY_RATE)

            // ---- Dark background ----------------------------------------------
            ctx.fillStyle = "#060508"
            ctx.fillRect(0, 0, w, h)

            // ---- Draw each position -------------------------------------------
            for (let i = 0; i < 5; i++) {
                const x   = posX[i]
                const isS = (i === 2)

                if (isS) {
                    // Red LED-style separator dot – bright flash at second boundary,
                    // then exponential decay to near-off (mimics a real indicator LED).
                    const dotCx = x + Math.floor(sepW / 2)
                    const dotCy = tubeY + Math.floor(tubeH / 2)
                    const dotR  = Math.max(2, Math.floor(sepW * 0.40))

                    const rg = ctx.createRadialGradient(dotCx, dotCy, 0, dotCx, dotCy, dotR * 3.0)
                    rg.addColorStop(0, "rgba(255,20,0," + (dotBright * 0.70).toFixed(2) + ")")
                    rg.addColorStop(1, "rgba(0,0,0,0)")
                    ctx.beginPath()
                    ctx.arc(dotCx, dotCy, dotR * 3.0, 0, 2 * Math.PI)
                    ctx.fillStyle = rg
                    ctx.fill()

                    ctx.beginPath()
                    ctx.arc(dotCx, dotCy, dotR, 0, 2 * Math.PI)
                    ctx.fillStyle = "hsl(8,100%," + Math.round(20 + dotBright * 55) + "%)"
                    ctx.fill()
                    continue
                }

                const tW = tubeW
                const fk = flicker[i]

                // ---- Effective inner half-width for this tube style ----------
                // Used to scale the discharge cloud so it fits inside the envelope.
                // TUBE_ENVELOPE_SCALE: fraction of tube width used for barrel/slim shaping.
                const TUBE_ENVELOPE_SCALE = 0.12
                const tubeEnvPx = Math.max(2, Math.ceil(tW * TUBE_ENVELOPE_SCALE))
                let innerHalfW
                if (tubeStyle === "slim") {
                    // IN-18: narrower on each side by TUBE_ENVELOPE_SCALE
                    innerHalfW = (tW - 2 * tubeEnvPx) * 0.5
                } else if (tubeStyle === "barrel") {
                    // IN-14: sides bow outward; effective width slightly wider at centre
                    innerHalfW = tW * 0.5 + tubeEnvPx * 0.5
                } else {
                    innerHalfW = tW * 0.5
                }

                // ---- Glyph dimensions: bounded by tube interior width -----------
                // effGlyphW is derived from the tube's inner width, NOT from tubeH,
                // so digits always fit inside the tube envelope without clipping.
                const innerTubeW = (tubeStyle === "slim")
                    ? Math.max(4, tW - 2 * tubeEnvPx)
                    : tW
                const effGlyphW  = Math.max(4, Math.floor(innerTubeW * 0.84))
                // Aspect ratio ~2.2:1; cap at 86% of tube height so digits don't overflow top/bottom.
                const effGlyphH  = Math.max(6, Math.min(Math.floor(tubeH * 0.86),
                                                          Math.floor(effGlyphW * 2.2)))
                // Wire stroke: 10% of glyph width for clear visibility, min 1.5 px.
                const wireW      = Math.max(1.5, effGlyphW * 0.10)

                // ---- Outer ambient glow (light escaping through the glass) -----
                // Real nixie tubes cast a warm orange-amber halo onto their surroundings;
                // visible in reference photos as a soft glow radiating past each tube edge.
                const outerGlowCx = x + tW * 0.5
                const outerGlowCy = tubeY + tubeH * 0.5
                const outerGlowR  = tW * 1.15
                const outerGrad   = ctx.createRadialGradient(
                    outerGlowCx, outerGlowCy, tW * 0.35,
                    outerGlowCx, outerGlowCy, outerGlowR)
                outerGrad.addColorStop(0,   "rgba(200,85,15," + (0.22 * fk).toFixed(2) + ")")
                outerGrad.addColorStop(0.55, "rgba(140,50,8," + (0.10 * fk).toFixed(2) + ")")
                outerGrad.addColorStop(1,   "rgba(0,0,0,0)")
                ctx.fillStyle = outerGrad
                ctx.fillRect(x - tW * 0.45, tubeY - tW * 0.3, tW * 1.9, tubeH + tW * 0.6)

                // ---- Glass tube body – outer border --------------------------
                ctx.strokeStyle = "rgba(120,115,105,0.80)"
                ctx.lineWidth   = 1
                ctx.beginPath()
                drawTubePath(ctx, x, tubeY, tW, tubeH, tubeStyle)
                ctx.stroke()

                // Dark glass interior fill – neutral dark grey matching real tube glass.
                // Real nixie glass is clear/neutral, not amber-tinted; the warm colour
                // is entirely from the discharge.  Left-to-right gradient for cylinder illusion.
                const glassGrad = ctx.createLinearGradient(x, tubeY, x + tW, tubeY)
                glassGrad.addColorStop(0,    "rgba(30,28,25,0.80)")
                glassGrad.addColorStop(0.20, "rgba(15,14,12,0.60)")
                glassGrad.addColorStop(0.80, "rgba(15,14,12,0.60)")
                glassGrad.addColorStop(1,    "rgba(30,28,25,0.80)")
                ctx.fillStyle = glassGrad
                ctx.beginPath()
                drawTubePath(ctx, x, tubeY, tW, tubeH, tubeStyle)
                ctx.fill()

                // ---- Digit (with transition) ----------------------------------
                const dispD = (nxInAnim && transition !== "none")
                              ? nixieGetDigit(i, nxPrevDig[i], nxTgtDig[i],
                                              elapsed, nxAnimDurMs, transition)
                              : tgtDigs[i]
                const digit  = String(dispD)
                const digitInt = parseInt(digit)

                const cx2 = x + Math.floor(tW / 2)
                const cy2 = tubeY + Math.floor(tubeH * 0.52)

                // ---- All inner rendering is clipped to tube interior ----------
                ctx.save()
                ctx.beginPath()
                drawTubePath(ctx, x + 1, tubeY + 1, tW - 2, tubeH - 2, tubeStyle)
                ctx.clip()
                // Wire-cathode rendering uses stroked paths; round caps give smooth ends
                ctx.lineCap  = "round"
                ctx.lineJoin = "round"

                // Blue LED emissive – vertical gradient rising from tube bottom.
                // Simulates the cool-blue cathode glow seen at the base of real
                // nixie tubes; the orange discharge overlays it in the digit region.
                const blueRiseH = tubeH * 0.45
                const bGlow     = ctx.createLinearGradient(
                                      cx2, tubeY + tubeH,
                                      cx2, tubeY + tubeH - blueRiseH)
                const bA0 = (0.35 * ledPulse * fk).toFixed(2)
                const bA1 = (0.14 * ledPulse * fk).toFixed(2)
                bGlow.addColorStop(0,   "rgba(15,45,235," + bA0 + ")")
                bGlow.addColorStop(0.4, "rgba(18,65,215," + bA1 + ")")
                bGlow.addColorStop(1,   "rgba(0,0,0,0)")
                ctx.fillStyle = bGlow
                ctx.fillRect(x, tubeY + tubeH - blueRiseH, tW, blueRiseH)

                // ---- Anode mesh – drawn before the active discharge so the
                // glowing digit renders over it (in a real tube the discharge glow
                // is far brighter than the mesh and visually dominates).
                ctx.lineCap     = "butt"
                ctx.strokeStyle = "rgba(70,45,8,0.12)"
                ctx.lineWidth   = 0.5
                for (let row = 1; row * meshStep < tubeH; row++) {
                    const ry = tubeY + row * meshStep
                    ctx.beginPath()
                    ctx.moveTo(x + 1, ry)
                    ctx.lineTo(x + tW - 1, ry)
                    ctx.stroke()
                }
                for (let col = 1; col * meshStep < tW; col++) {
                    const cx3 = x + col * meshStep
                    ctx.beginPath()
                    ctx.moveTo(cx3, tubeY + 1)
                    ctx.lineTo(cx3, tubeY + tubeH - 1)
                    ctx.stroke()
                }
                ctx.lineCap  = "round"
                ctx.lineJoin = "round"

                // Ghost cathodes – inactive stacked digit wire frames.
                // Draw second so plasma cloud and active digit glow over them.
                const ghostWireScale = 0.7   // inactive digits use 70% of main wire width
                for (let d = 0; d < 10; d++) {
                    if (String(d) === digit) continue
                    const depthOff = ((d - 5) * 0.25)
                    const dist = Math.min(Math.abs(d - digitInt),
                                         10 - Math.abs(d - digitInt))
                    const gAlpha = (0.10 + dist * 0.015) * fk
                    ctx.strokeStyle = "rgba(160,80,12," + gAlpha.toFixed(3) + ")"
                    ctx.lineWidth   = wireW * ghostWireScale
                    drawNixieGlyph(ctx, String(d), cx2 + depthOff, cy2, effGlyphW, effGlyphH)
                }

                // Plasma cloud (discharge glow background) – clipped to tube interior.
                // nixieGlowRadius is a fraction of the inner half-width (tube radius).
                const glowR = innerHalfW * root.nixieGlowRadius
                const dg = ctx.createRadialGradient(cx2, cy2, 0, cx2, cy2, glowR)
                dg.addColorStop(0,   "rgba(220,95,5,"  + (0.40 * fk).toFixed(2) + ")")
                dg.addColorStop(0.4, "rgba(180,60,5,"  + (0.20 * fk).toFixed(2) + ")")
                dg.addColorStop(1,   "rgba(0,0,0,0)")
                ctx.beginPath()
                ctx.arc(cx2, cy2, glowR, 0, 2 * Math.PI)
                ctx.fillStyle = dg
                ctx.fill()

                // Fuzzy discharge glow: 4 offset passes at low alpha using the wire
                // glyph path. Both offset distance and glyph expansion scale with
                // nixieGlowRadius so the slider controls ALL sources of haze.
                const glowScale = root.nixieGlowRadius
                const glowA = (0.15 * fk * glowScale).toFixed(2)
                // glyphExpansionPerPass: each glow pass is 12% larger per pass (×radius)
                // wireWidthExpansionPerPass: each glow pass adds 25% to wire width
                const glyphExpansionPerPass  = 0.12
                const wireWidthExpansionPerPass = 0.25
                for (let pass = 1; pass <= 4; pass++) {
                    const blur = pass * 1.2 * glowScale
                    const gs   = 1.0 + pass * glyphExpansionPerPass * glowScale
                    ctx.strokeStyle = "rgba(255,130,15," + glowA + ")"
                    ctx.lineWidth   = wireW * (1.0 + pass * wireWidthExpansionPerPass)
                    const gw = effGlyphW * gs, gh = effGlyphH * gs
                    drawNixieGlyph(ctx, digit, cx2 - blur, cy2, gw, gh)
                    drawNixieGlyph(ctx, digit, cx2 + blur, cy2, gw, gh)
                    drawNixieGlyph(ctx, digit, cx2, cy2 - blur, gw, gh)
                    drawNixieGlyph(ctx, digit, cx2, cy2 + blur, gw, gh)
                    const db = blur * 0.7
                    drawNixieGlyph(ctx, digit, cx2 - db, cy2 - db, gw, gh)
                    drawNixieGlyph(ctx, digit, cx2 + db, cy2 - db, gw, gh)
                    drawNixieGlyph(ctx, digit, cx2 - db, cy2 + db, gw, gh)
                    drawNixieGlyph(ctx, digit, cx2 + db, cy2 + db, gw, gh)
                }

                // Depth shadow
                ctx.strokeStyle = "rgba(160,40,0,0.22)"
                ctx.lineWidth   = wireW
                drawNixieGlyph(ctx, digit, cx2 + 1, cy2 + 1, effGlyphW, effGlyphH)

                // Main orange discharge wire
                ctx.strokeStyle = "hsl(22,100%," + Math.round(62 + fk * 12) + "%)"
                ctx.lineWidth   = wireW
                drawNixieGlyph(ctx, digit, cx2, cy2, effGlyphW, effGlyphH)

                // Bright core highlight – thinner stroke (45%), slightly smaller glyph
                // (88%) offset 0.5 px upward to simulate cathode wire inner luminosity
                if (fk > 0.4) {
                    const highlightWireScale  = 0.45
                    const highlightGlyphScale = 0.88
                    const highlightYOffset    = 0.5
                    ctx.strokeStyle = "rgba(255,215,130," + (0.60 * fk).toFixed(2) + ")"
                    ctx.lineWidth   = wireW * highlightWireScale
                    drawNixieGlyph(ctx, digit, cx2, cy2 - highlightYOffset,
                                   effGlyphW * highlightGlyphScale, effGlyphH * highlightGlyphScale)
                }

                ctx.restore()   // end tube interior clip

                // ---- Cylindrical glass overlay --------------------------------
                // Left-side bright specular streak (strong) + right-side secondary.
                // Use cooler, more neutral white (not warm amber) to match real glass.
                const specGr = ctx.createLinearGradient(x, tubeY, x + Math.floor(tW * 0.35), tubeY)
                specGr.addColorStop(0,   "rgba(240,242,245,0.28)")
                specGr.addColorStop(0.4, "rgba(220,225,230,0.14)")
                specGr.addColorStop(1,   "rgba(0,0,0,0.0)")
                ctx.save()
                ctx.beginPath()
                drawTubePath(ctx, x + 1, tubeY + 1, Math.floor(tW * 0.35), tubeH - 2, tubeStyle)
                ctx.fillStyle = specGr
                ctx.fill()
                ctx.restore()

                const specR  = ctx.createLinearGradient(x + Math.floor(tW * 0.70), tubeY,
                                                         x + tW, tubeY)
                specR.addColorStop(0,   "rgba(0,0,0,0.0)")
                specR.addColorStop(0.7, "rgba(200,205,210,0.08)")
                specR.addColorStop(1,   "rgba(210,215,220,0.16)")
                ctx.save()
                ctx.beginPath()
                drawTubePath(ctx, x + Math.floor(tW * 0.70), tubeY + 1,
                             tW - Math.floor(tW * 0.70) - 1, tubeH - 2, tubeStyle)
                ctx.fillStyle = specR
                ctx.fill()
                ctx.restore()

                // ---- Top glass dome / getter cap --------------------------------
                // Real nixie tubes are sealed with a rounded glass dome at the top.
                // In the reference photo the dome is roughly 25% of tube height.
                // domeRy uses tubeH so it scales with the tube proportions rather
                // than just the tube width (which produced a too-flat cap before).
                const domeCx = x + Math.floor(tW * 0.5)
                const domeRx = Math.floor(tW * 0.46)
                const domeRy = Math.max(4, Math.floor(tubeH * 0.18))
                ctx.save()
                // Dome body: top-half ellipse (upper arc of the sealed glass top)
                ctx.beginPath()
                ctx.ellipse(domeCx, tubeY, domeRx, domeRy, 0, Math.PI, 2 * Math.PI)
                ctx.fillStyle   = "rgba(50,48,44,0.75)"
                ctx.fill()
                ctx.strokeStyle = "rgba(140,135,122,0.88)"
                ctx.lineWidth   = 0.6
                ctx.stroke()
                // Left specular on dome – bright streak like glass cylinder highlight
                ctx.beginPath()
                ctx.ellipse(domeCx - Math.floor(domeRx * 0.32), tubeY - Math.floor(domeRy * 0.35),
                            Math.floor(domeRx * 0.20), Math.floor(domeRy * 0.42), -0.4, 0, 2*Math.PI)
                ctx.fillStyle = "rgba(255,252,245,0.22)"
                ctx.fill()
                // Getter disc at very top centre (darker metallic spot)
                const getterR = Math.max(2, Math.floor(tW * 0.14))
                const getterY = tubeY - domeRy + 2
                ctx.beginPath()
                ctx.ellipse(domeCx, getterY, getterR, Math.max(1, Math.floor(getterR * 0.42)), 0, 0, 2*Math.PI)
                ctx.fillStyle   = "rgba(35,33,30,0.90)"
                ctx.fill()
                ctx.strokeStyle = "rgba(150,140,120,0.65)"
                ctx.lineWidth   = 0.5
                ctx.stroke()
                ctx.restore()

                // ---- Lead pin wires at the bottom of the tube ----------------
                const pinY0 = tubeY + tubeH
                const pinY1 = pinY0 + Math.max(2, Math.floor(h * 0.04))
                const nPins = 5
                for (let p = 0; p < nPins; p++) {
                    const px = x + Math.floor((p + 0.5) * tW / nPins)
                    ctx.strokeStyle = "rgba(80,60,25,0.55)"
                    ctx.lineWidth   = 0.5
                    ctx.beginPath()
                    ctx.moveTo(px, pinY0)
                    ctx.lineTo(px, pinY1)
                    ctx.stroke()
                }

                // ---- Blue LED strip (1 Hz, synchronized across all tubes) ----
                // Model each tube's LED as a small rectangular emitter with a
                // radial glow halo spreading outward — matches reference photos.
                const ledX = x + 1
                const lW   = tW - 2

                // Halo glow spreading beyond the LED pad
                const lg = ctx.createRadialGradient(
                    x + tW / 2, ledY + ledH / 2, 0,
                    x + tW / 2, ledY + ledH / 2, tW * 0.95)
                lg.addColorStop(0, "rgba(25,50,240," + (ledPulse * fk * 0.65).toFixed(2) + ")")
                lg.addColorStop(0.5, "rgba(10,30,200," + (ledPulse * fk * 0.25).toFixed(2) + ")")
                lg.addColorStop(1, "rgba(0,0,0,0)")
                ctx.fillStyle = lg
                ctx.fillRect(ledX - 3, ledY - 3, lW + 6, ledH + 8)

                // LED pad itself
                ctx.fillStyle = "hsl(232,90%," + Math.round(22 + ledPulse * fk * 30) + "%)"
                ctx.fillRect(ledX, ledY, lW, ledH)
                // Bright specular spot on the LED surface
                if (ledPulse * fk > 0.3) {
                    const ledSpecGr = ctx.createLinearGradient(ledX, ledY, ledX + lW * 0.5, ledY)
                    ledSpecGr.addColorStop(0,   "rgba(180,200,255," + (ledPulse * fk * 0.35).toFixed(2) + ")")
                    ledSpecGr.addColorStop(1,   "rgba(0,0,0,0)")
                    ctx.fillStyle = ledSpecGr
                    ctx.fillRect(ledX, ledY, lW * 0.5, ledH)
                }
            }

            // ---- Date line at the bottom (optional) ---------------------------
            if (root.showDate) {
                const days   = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                const months = ["Jan","Feb","Mar","Apr","May","Jun",
                                "Jul","Aug","Sep","Oct","Nov","Dec"]
                const dateStr = days[t.getDay()] + " "
                              + String(t.getDate()).padStart(2, "0") + " "
                              + months[t.getMonth()]
                const dateY = ledY + ledH + Math.floor(h * 0.06)
                ctx.font         = Math.max(8, Math.floor(h * 0.12)) + "px monospace"
                ctx.textAlign    = "center"
                ctx.textBaseline = "top"
                // Dark shadow pass for contrast against the black background
                ctx.fillStyle    = "rgba(0,0,0,0.75)"
                ctx.fillText(dateStr, w / 2 + 1, dateY + 1)
                // Bright warm amber, matching the nixie tube discharge colour
                ctx.fillStyle    = "rgba(210,145,55,0.95)"
                ctx.fillText(dateStr, w / 2, dateY)
            }
        }
    }
}

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
                                               ? Plasmoid.configuration.nixieGlowRadius : 0.55

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
            const tubeW  = Math.floor(w * 0.175)
            const tubeH  = Math.floor(h * 0.52)
            const sepW   = Math.floor(w * 0.08)
            const gap    = Math.max(1, Math.floor(w * 0.025))
            const tubeY  = Math.floor(h * 0.07)
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
            const fontSz       = Math.max(8, Math.floor(tubeH * 0.72))
            const ghostFontSz  = Math.round(fontSz * 0.90)
            const highlightFontSz = Math.round(fontSz * 0.70)
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

                // ---- Glass tube body – outer border --------------------------
                ctx.strokeStyle = "rgba(80,65,35,0.75)"
                ctx.lineWidth   = 1
                ctx.beginPath()
                drawTubePath(ctx, x, tubeY, tW, tubeH, tubeStyle)
                ctx.stroke()

                // Dark glass interior fill (left-to-right gradient for cylinder illusion)
                const glassGrad = ctx.createLinearGradient(x, tubeY, x + tW, tubeY)
                glassGrad.addColorStop(0,    "rgba(28,20,8,0.70)")
                glassGrad.addColorStop(0.20, "rgba(14,10,4,0.55)")
                glassGrad.addColorStop(0.80, "rgba(14,10,4,0.55)")
                glassGrad.addColorStop(1,    "rgba(28,20,8,0.70)")
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
                ctx.textAlign    = "center"
                ctx.textBaseline = "middle"

                // Ghost cathodes – inactive stacked digit wire frames.
                // Draw first so plasma cloud and active digit glow over them.
                for (let d = 0; d < 10; d++) {
                    if (String(d) === digit) continue
                    const depthOff = ((d - 5) * 0.25)
                    const dist = Math.min(Math.abs(d - digitInt),
                                         10 - Math.abs(d - digitInt))
                    const gAlpha = (0.08 + dist * 0.012) * fk
                    ctx.font      = "bold " + ghostFontSz + "px monospace"
                    ctx.fillStyle = "rgba(160,80,12," + gAlpha.toFixed(3) + ")"
                    ctx.fillText(String(d), cx2 + depthOff, cy2)
                }

                // Plasma cloud (discharge glow background) – clipped to tube interior.
                // nixieGlowRadius is a fraction of the inner half-width (tube radius).
                // Removing the former ×2 multiplier so the full slider range 0.20–1.00
                // maps to 20%–100% of the tube radius, giving a visible effect across
                // the entire range rather than being clipped above ~50%.
                const glowR = innerHalfW * root.nixieGlowRadius
                const dg = ctx.createRadialGradient(cx2, cy2, 0, cx2, cy2, glowR)
                dg.addColorStop(0,   "rgba(220,95,5,"  + (0.40 * fk).toFixed(2) + ")")
                dg.addColorStop(0.4, "rgba(180,60,5,"  + (0.20 * fk).toFixed(2) + ")")
                dg.addColorStop(1,   "rgba(0,0,0,0)")
                ctx.beginPath()
                ctx.arc(cx2, cy2, glowR, 0, 2 * Math.PI)
                ctx.fillStyle = dg
                ctx.fill()

                // Fuzzy discharge glow: 4 offset passes at low alpha
                const glowA = (0.15 * fk).toFixed(2)
                for (let pass = 1; pass <= 4; pass++) {
                    const blur = pass * 1.2
                    ctx.font      = "bold " + (fontSz + pass * 2) + "px monospace"
                    ctx.fillStyle = "rgba(255,130,15," + glowA + ")"
                    ctx.fillText(digit, cx2 - blur, cy2)
                    ctx.fillText(digit, cx2 + blur, cy2)
                    ctx.fillText(digit, cx2, cy2 - blur)
                    ctx.fillText(digit, cx2, cy2 + blur)
                    const db = blur * 0.7
                    ctx.fillText(digit, cx2 - db, cy2 - db)
                    ctx.fillText(digit, cx2 + db, cy2 - db)
                    ctx.fillText(digit, cx2 - db, cy2 + db)
                    ctx.fillText(digit, cx2 + db, cy2 + db)
                }

                ctx.font = "bold " + fontSz + "px monospace"

                // Depth shadow
                ctx.fillStyle = "rgba(160,40,0,0.22)"
                ctx.fillText(digit, cx2 + 1, cy2 + 1)

                // Main orange discharge
                ctx.fillStyle = "hsl(22,100%," + Math.round(50 + fk * 14) + "%)"
                ctx.fillText(digit, cx2, cy2)

                // Bright core highlight
                if (fk > 0.5) {
                    ctx.fillStyle = "rgba(255,215,130," + (0.60 * fk).toFixed(2) + ")"
                    ctx.font      = "bold " + highlightFontSz + "px monospace"
                    ctx.fillText(digit, cx2, cy2 - 1)
                }

                // ---- Anode mesh – drawn on top of the active digit -----------
                // In a real tube the mesh anode surrounds all cathodes and is
                // visible in front; draw it last inside the clip so it overlays.
                ctx.strokeStyle = "rgba(90,55,10,0.40)"
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

                ctx.restore()   // end tube interior clip

                // ---- Cylindrical glass overlay --------------------------------
                const specGr = ctx.createLinearGradient(x, tubeY, x + Math.floor(tW * 0.35), tubeY)
                specGr.addColorStop(0,   "rgba(255,240,200,0.13)")
                specGr.addColorStop(0.5, "rgba(255,240,200,0.07)")
                specGr.addColorStop(1,   "rgba(255,240,200,0.0)")
                ctx.save()
                ctx.beginPath()
                drawTubePath(ctx, x + 1, tubeY + 1, Math.floor(tW * 0.35), tubeH - 2, tubeStyle)
                ctx.fillStyle = specGr
                ctx.fill()
                ctx.restore()

                const specR  = ctx.createLinearGradient(x + Math.floor(tW * 0.70), tubeY,
                                                         x + tW, tubeY)
                specR.addColorStop(0,   "rgba(255,240,200,0.0)")
                specR.addColorStop(0.7, "rgba(255,240,200,0.06)")
                specR.addColorStop(1,   "rgba(255,240,200,0.10)")
                ctx.save()
                ctx.beginPath()
                drawTubePath(ctx, x + Math.floor(tW * 0.70), tubeY + 1,
                             tW - Math.floor(tW * 0.70) - 1, tubeH - 2, tubeStyle)
                ctx.fillStyle = specR
                ctx.fill()
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
                const ledX = x + 1
                const lW   = tW - 2

                const lg = ctx.createRadialGradient(
                    x + tW / 2, ledY + ledH / 2, 0,
                    x + tW / 2, ledY + ledH / 2, tW * 0.8)
                lg.addColorStop(0, "rgba(30,60,230," + (ledPulse * fk * 0.55).toFixed(2) + ")")
                lg.addColorStop(1, "rgba(0,0,0,0)")
                ctx.fillStyle = lg
                ctx.fillRect(ledX - 2, ledY - 2, lW + 4, ledH + 6)

                ctx.fillStyle = "hsl(232,90%," + Math.round(25 + ledPulse * fk * 25) + "%)"
                ctx.fillRect(ledX, ledY, lW, ledH)
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
                ctx.font         = Math.max(6, Math.floor(h * 0.10)) + "px monospace"
                ctx.textAlign    = "center"
                ctx.textBaseline = "top"
                ctx.fillStyle    = "#443322"
                ctx.fillText(dateStr, w / 2, dateY)
            }
        }
    }
}

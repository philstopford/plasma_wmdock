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
    readonly property bool   use24Hour:   Plasmoid.configuration.use24Hour   ?? true
    readonly property bool   showSeconds: Plasmoid.configuration.showSeconds ?? true
    readonly property bool   showDate:    Plasmoid.configuration.showDate    ?? true
    readonly property string clockStyle:  Plasmoid.configuration.clockStyle  || "analog"

    // Repaint triggers
    onUse24HourChanged:   faceCanvas.requestPaint()
    onShowSecondsChanged: faceCanvas.requestPaint()
    onShowDateChanged:    faceCanvas.requestPaint()
    onClockStyleChanged:  faceCanvas.requestPaint()

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
        //   Blue LED strip below each digit tube
        //   Red pulsing dot at the separator position
        function paintNixie() {
            const ctx = getContext("2d")
            const w = width, h = height
            ctx.clearRect(0, 0, w, h)

            const t    = new Date()
            const hrs  = root.use24Hour ? t.getHours() : (t.getHours() % 12 || 12)
            const mins = t.getMinutes()
            const secs = t.getSeconds()

            const pad = n => String(n).padStart(2, "0")
            const hStr = pad(hrs)
            const mStr = pad(mins)
            const digits = [hStr[0], hStr[1], null, mStr[0], mStr[1]]  // null = separator

            // ---- Layout -------------------------------------------------------
            // Tube dimensions
            const tubeW  = Math.floor(w * 0.175)   // ~11px at 64px
            const tubeH  = Math.floor(h * 0.52)    // ~33px at 64px
            const sepW   = Math.floor(w * 0.08)    // ~5px at 64px
            const gap    = Math.max(1, Math.floor(w * 0.025))
            const tubeY  = Math.floor(h * 0.07)    // top of tubes

            // Total layout width: 4*tubeW + sepW + 4*gap, centred in widget
            const totalW = 4 * tubeW + sepW + 4 * gap
            const startX = Math.floor((w - totalW) / 2)

            // X positions (left edge of each element)
            const posX = [
                startX,
                startX + tubeW + gap,
                startX + 2 * (tubeW + gap),                // separator
                startX + 2 * (tubeW + gap) + sepW + gap,
                startX + 3 * (tubeW + gap) + sepW + gap
            ]

            const ledH   = Math.max(2, Math.floor(h * 0.055))   // ~3px LED strip
            const ledY   = tubeY + tubeH + gap                   // LED strip top
            const fontSz = Math.max(8, Math.floor(tubeH * 0.72))

            // Seconds pulse [0-1] – cosine so it smoothly brightens on odd secs
            const sPulse = 0.55 + 0.45 * Math.abs(Math.cos(secs * Math.PI))

            // ---- Dark background ----------------------------------------------
            ctx.fillStyle = "#060508"
            ctx.fillRect(0, 0, w, h)

            // ---- Draw digit tubes --------------------------------------------
            for (let i = 0; i < 5; i++) {
                const x   = posX[i]
                const isS = (i === 2)   // separator slot

                if (isS) {
                    // Red pulsing seconds dot
                    const dotCx = x + Math.floor(sepW / 2)
                    const dotCy = tubeY + Math.floor(tubeH / 2)
                    const dotR  = Math.max(2, Math.floor(sepW * 0.40))

                    // Outer glow
                    const rg = ctx.createRadialGradient(dotCx, dotCy, 0, dotCx, dotCy, dotR * 3.5)
                    rg.addColorStop(0, "rgba(255,20,0," + (sPulse * 0.65).toFixed(2) + ")")
                    rg.addColorStop(1, "rgba(0,0,0,0)")
                    ctx.beginPath()
                    ctx.arc(dotCx, dotCy, dotR * 3.5, 0, 2 * Math.PI)
                    ctx.fillStyle = rg
                    ctx.fill()

                    // Core dot
                    ctx.beginPath()
                    ctx.arc(dotCx, dotCy, dotR, 0, 2 * Math.PI)
                    ctx.fillStyle = "hsl(8,100%," + Math.round(40 + sPulse * 35) + "%)"
                    ctx.fill()
                    continue
                }

                const tW = (i < 2) ? tubeW : tubeW   // same for both sides

                // ---- Glass tube outline ---------------------------------------
                // Outer rim (dark metal / pins)
                ctx.strokeStyle = "#2a2520"
                ctx.lineWidth   = 1
                ctx.beginPath()
                ctx.roundRect(x, tubeY, tW, tubeH, 3)
                ctx.stroke()

                // Inner glass (subtle warm tint)
                const glassGrad = ctx.createLinearGradient(x, tubeY, x + tW, tubeY)
                glassGrad.addColorStop(0,    "rgba(40,28,12,0.55)")
                glassGrad.addColorStop(0.35, "rgba(18,12,6,0.30)")
                glassGrad.addColorStop(1,    "rgba(40,28,12,0.55)")
                ctx.fillStyle = glassGrad
                ctx.beginPath()
                ctx.roundRect(x, tubeY, tW, tubeH, 3)
                ctx.fill()

                // Cathode grid lines (faint horizontal bands in the glass)
                ctx.strokeStyle = "rgba(60,45,20,0.18)"
                ctx.lineWidth = 0.5
                for (let row = 1; row < 4; row++) {
                    const ry = tubeY + row * (tubeH / 4)
                    ctx.beginPath()
                    ctx.moveTo(x + 2, ry)
                    ctx.lineTo(x + tW - 2, ry)
                    ctx.stroke()
                }

                // ---- Digit glow (neon orange) ---------------------------------
                const digit = digits[i]
                const cx2   = x + Math.floor(tW / 2)
                const cy2   = tubeY + Math.floor(tubeH * 0.52)

                // Soft background plasma cloud behind digit
                const dg = ctx.createRadialGradient(cx2, cy2, 0, cx2, cy2, tW * 0.75)
                dg.addColorStop(0,   "rgba(200,80,5,0.30)")
                dg.addColorStop(0.5, "rgba(160,50,5,0.12)")
                dg.addColorStop(1,   "rgba(0,0,0,0)")
                ctx.beginPath()
                ctx.arc(cx2, cy2, tW * 0.75, 0, 2 * Math.PI)
                ctx.fillStyle = dg
                ctx.fill()

                // Shadow layer (depth / shadow digit under glow)
                ctx.save()
                ctx.beginPath()
                ctx.roundRect(x + 1, tubeY + 1, tW - 2, tubeH - 2, 2)
                ctx.clip()

                ctx.textAlign    = "center"
                ctx.textBaseline = "middle"
                ctx.font = "bold " + fontSz + "px monospace"

                ctx.fillStyle = "rgba(160,40,0,0.20)"
                ctx.fillText(digit, cx2 + 1, cy2 + 1)

                // Main orange digit
                ctx.fillStyle = "hsl(22,100%,62%)"
                ctx.fillText(digit, cx2, cy2)

                // Bright core highlight
                ctx.fillStyle = "rgba(255,210,120,0.65)"
                ctx.font = "bold " + Math.round(fontSz * 0.72) + "px monospace"
                ctx.fillText(digit, cx2, cy2 - 1)
                ctx.restore()

                // Specular reflection streak on left side of glass
                ctx.strokeStyle = "rgba(255,230,180,0.10)"
                ctx.lineWidth   = 1
                ctx.beginPath()
                ctx.moveTo(x + 2, tubeY + 4)
                ctx.lineTo(x + 2, tubeY + tubeH - 4)
                ctx.stroke()

                // ---- Blue LED strip below tube --------------------------------
                const ledX = x + 1
                const lW   = tW - 2
                const ledPulse = 0.50 + 0.50 * Math.abs(Math.sin(secs * Math.PI + i * 0.6))

                // Glow spread above strip
                const lg = ctx.createRadialGradient(
                    x + tW / 2, ledY + ledH / 2, 0,
                    x + tW / 2, ledY + ledH / 2, tW * 0.8)
                lg.addColorStop(0, "rgba(30,60,230," + (ledPulse * 0.55).toFixed(2) + ")")
                lg.addColorStop(1, "rgba(0,0,0,0)")
                ctx.fillStyle = lg
                ctx.fillRect(ledX - 2, ledY - 2, lW + 4, ledH + 6)

                // LED strip itself
                ctx.fillStyle = "hsl(232,90%," + Math.round(25 + ledPulse * 25) + "%)"
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

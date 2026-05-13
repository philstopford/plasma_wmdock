// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2

/**
 * WMClock – Analog clock applet styled after the classic wmclock dockapp.
 *
 * Features:
 *   • Analog clock face with hour marks and three hands
 *   • Digital time readout below the clock face
 *   • Date line at the bottom
 *   • Classic dark dockapp colour scheme
 */
Item {
    id: root

    // -----------------------------------------------------------------------
    // Time
    // -----------------------------------------------------------------------
    readonly property var now: new Date()

    Timer {
        interval: 1000
        running:  true
        repeat:   true
        onTriggered: root.now_update()
    }

    // QML property bindings need a notifiable property – use a plain update
    property var _now: new Date()
    function now_update() { _now = new Date() }

    // -----------------------------------------------------------------------
    // Layout constants (designed for 60×60 inside a 64×64 slot)
    // -----------------------------------------------------------------------
    readonly property real cx: width  / 2
    readonly property real cy: height * 0.44   // slightly above centre to leave room for digits

    readonly property real faceR:  Math.min(width, height) * 0.36
    readonly property real hourR:  faceR * 0.55
    readonly property real minR:   faceR * 0.80
    readonly property real secR:   faceR * 0.88
    readonly property real dotR:   faceR * 0.08
    readonly property real markR1: faceR * 0.82
    readonly property real markR2: faceR * 0.92

    // -----------------------------------------------------------------------
    // Background
    // -----------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:   "#111"
        radius:  3
    }

    // -----------------------------------------------------------------------
    // Clock face (Canvas)
    // -----------------------------------------------------------------------
    Canvas {
        id: faceCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            const w = width, h = height

            ctx.clearRect(0, 0, w, h)

            const t    = root._now
            const hrs  = t.getHours()   % 12 + t.getMinutes() / 60.0
            const mins = t.getMinutes() + t.getSeconds()  / 60.0
            const secs = t.getSeconds()

            const cx = root.cx
            const cy = root.cy
            const R  = root.faceR

            // ---- Face circle ------------------------------------------------
            const grad = ctx.createRadialGradient(cx, cy - R*0.2, R*0.1, cx, cy, R)
            grad.addColorStop(0,   "#2a2a2a")
            grad.addColorStop(1,   "#111")
            ctx.beginPath()
            ctx.arc(cx, cy, R, 0, 2*Math.PI)
            ctx.fillStyle = grad
            ctx.fill()

            // Outer ring
            ctx.beginPath()
            ctx.arc(cx, cy, R, 0, 2*Math.PI)
            ctx.strokeStyle = "#555"
            ctx.lineWidth   = 1.5
            ctx.stroke()

            // Inner glow ring
            ctx.beginPath()
            ctx.arc(cx, cy, R - 2, 0, 2*Math.PI)
            ctx.strokeStyle = "#222"
            ctx.lineWidth   = 1
            ctx.stroke()

            // ---- Hour marks ------------------------------------------------
            for (let i = 0; i < 12; i++) {
                const angle = (i / 12) * 2 * Math.PI - Math.PI / 2
                const isHour = true
                const r1 = (i % 3 === 0) ? root.markR1 * 0.92 : root.markR1
                const r2 = root.markR2

                ctx.beginPath()
                ctx.moveTo(cx + r1 * Math.cos(angle), cy + r1 * Math.sin(angle))
                ctx.lineTo(cx + r2 * Math.cos(angle), cy + r2 * Math.sin(angle))
                ctx.strokeStyle = (i % 3 === 0) ? "#aaa" : "#555"
                ctx.lineWidth   = (i % 3 === 0) ? 2 : 1
                ctx.stroke()
            }

            // ---- Minute marks ----------------------------------------------
            for (let i = 0; i < 60; i++) {
                if (i % 5 === 0) continue  // already drawn as hour marks
                const angle = (i / 60) * 2 * Math.PI - Math.PI / 2
                ctx.beginPath()
                ctx.moveTo(cx + root.markR1 * 1.02 * Math.cos(angle),
                           cy + root.markR1 * 1.02 * Math.sin(angle))
                ctx.lineTo(cx + root.markR2 * Math.cos(angle),
                           cy + root.markR2 * Math.sin(angle))
                ctx.strokeStyle = "#333"
                ctx.lineWidth   = 0.8
                ctx.stroke()
            }

            // ---- Helper: draw a hand ----------------------------------------
            function drawHand(angleDeg, length, width, color, shadow) {
                const a = (angleDeg * Math.PI / 180) - Math.PI / 2
                const ex = cx + length * Math.cos(a)
                const ey = cy + length * Math.sin(a)
                if (shadow) {
                    ctx.beginPath()
                    ctx.moveTo(cx + 1, cy + 1)
                    ctx.lineTo(ex + 1, ey + 1)
                    ctx.strokeStyle = "rgba(0,0,0,0.5)"
                    ctx.lineWidth   = width + 1
                    ctx.lineCap     = "round"
                    ctx.stroke()
                }
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(ex, ey)
                ctx.strokeStyle = color
                ctx.lineWidth   = width
                ctx.lineCap     = "round"
                ctx.stroke()
            }

            // Hour hand
            drawHand(hrs * 30, root.hourR, 2.5, "#ddd", true)
            // Minute hand
            drawHand(mins * 6, root.minR,  1.8, "#ccc", true)
            // Second hand (red)
            drawHand(secs * 6, root.secR,  1.0, "#e03030", false)
            // Counter-weight of second hand
            const sa = (secs * 6 * Math.PI / 180) - Math.PI / 2
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.lineTo(cx - root.secR * 0.2 * Math.cos(sa),
                       cy - root.secR * 0.2 * Math.sin(sa))
            ctx.strokeStyle = "#e03030"
            ctx.lineWidth   = 1.5
            ctx.stroke()

            // Centre dot
            ctx.beginPath()
            ctx.arc(cx, cy, root.dotR, 0, 2*Math.PI)
            ctx.fillStyle = "#bbb"
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy, root.dotR * 0.5, 0, 2*Math.PI)
            ctx.fillStyle = "#444"
            ctx.fill()

            // ---- Digital time (HH:MM) ----------------------------------------
            const pad = n => String(n).padStart(2, "0")
            const timeStr = pad(t.getHours()) + ":" + pad(t.getMinutes())
            ctx.font        = "bold " + Math.round(R * 0.38) + "px monospace"
            ctx.textAlign   = "center"
            ctx.textBaseline = "middle"
            ctx.fillStyle   = "#33dd33"

            const ty = cy + R + R * 0.35
            // Shadow
            ctx.fillStyle = "#004400"
            ctx.fillText(timeStr, cx + 1, ty + 1)
            ctx.fillStyle = "#33dd33"
            ctx.fillText(timeStr, cx, ty)

            // ---- Date line --------------------------------------------------
            const days   = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            const months = ["Jan","Feb","Mar","Apr","May","Jun",
                            "Jul","Aug","Sep","Oct","Nov","Dec"]
            const dateStr = days[t.getDay()] + " " +
                            String(t.getDate()).padStart(2,"0") + " " +
                            months[t.getMonth()]
            ctx.font        = Math.round(R * 0.28) + "px monospace"
            ctx.fillStyle   = "#229922"
            ctx.fillText(dateStr, cx, ty + R * 0.42)
        }

        // Repaint every second
        Connections {
            target: root
            function on_NowChanged() { faceCanvas.requestPaint() }
        }

        Component.onCompleted: requestPaint()
    }
}

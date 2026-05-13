// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.private.wmdock 1.0

/**
 * WMBattery – Battery status applet.
 *
 * Draws a stylised battery icon showing charge level, a plug symbol
 * when charging, and numeric percentage + time-remaining readout.
 * Styled after the classic wmbattery dockapp.
 */
Item {
    id: root

    Rectangle {
        anchors.fill: parent
        color: "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    // -----------------------------------------------------------------------
    // Battery icon (Canvas)
    // -----------------------------------------------------------------------
    Canvas {
        id: battCanvas
        anchors {
            top:              parent.top
            left:             parent.left
            right:            parent.right
            bottom:           statusLabel.top
            topMargin:        4
            leftMargin:       8
            rightMargin:      8
            bottomMargin:     2
        }
        antialiasing: true

        Connections {
            target: BatteryMonitor
            function onStatusChanged() { battCanvas.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const pct     = BatteryMonitor.available ? BatteryMonitor.percentage : 0
            const charge  = BatteryMonitor.charging
            const full    = BatteryMonitor.full
            const avail   = BatteryMonitor.available

            const bw  = width  * 0.70
            const bh  = height * 0.65
            const bx  = (width  - bw) / 2
            const by  = (height - bh) / 2 + 4
            const nw  = bw * 0.18   // nub width
            const nh  = bh * 0.30   // nub height

            // Battery outline
            ctx.strokeStyle = avail ? "#888" : "#333"
            ctx.lineWidth   = 1.5
            ctx.beginPath()
            ctx.rect(bx, by, bw, bh)
            ctx.stroke()

            // Nub (positive terminal)
            ctx.beginPath()
            ctx.rect(bx + (bw - nw) / 2, by - nh, nw, nh)
            ctx.strokeStyle = avail ? "#666" : "#222"
            ctx.lineWidth   = 1
            ctx.stroke()

            if (!avail) {
                ctx.fillStyle = "#330000"
                ctx.font      = "bold " + Math.round(height * 0.25) + "px monospace"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText("N/A", width / 2, by + bh / 2)
                return
            }

            // Fill level
            const fillH   = Math.max(0, (pct / 100) * (bh - 4))
            const fillCol = full    ? "#00ff44"
                          : charge  ? "#44aaff"
                          : pct < 10 ? "#ff2200"
                          : pct < 25 ? "#ff8800"
                          : "#00cc44"

            ctx.fillStyle = fillCol
            ctx.fillRect(bx + 2, by + bh - 2 - fillH, bw - 4, fillH)

            // Bolt (charging) or low-battery mark
            if (charge) {
                ctx.fillStyle   = "rgba(255,255,255,0.85)"
                ctx.font        = "bold " + Math.round(bh * 0.55) + "px sans-serif"
                ctx.textAlign   = "center"
                ctx.textBaseline = "middle"
                ctx.fillText("⚡", bx + bw / 2, by + bh / 2)
            } else if (pct < 15) {
                ctx.fillStyle   = "#ff4400"
                ctx.font        = "bold " + Math.round(bh * 0.45) + "px sans-serif"
                ctx.textAlign   = "center"
                ctx.textBaseline = "middle"
                ctx.fillText("!", bx + bw / 2, by + bh / 2)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Status text
    // -----------------------------------------------------------------------
    Text {
        id: statusLabel
        anchors {
            bottom: pctLabel.top
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 1
        }
        text: BatteryMonitor.available ? BatteryMonitor.stateString : "No battery"
        color: BatteryMonitor.charging ? "#44aaff" : "#00cc44"
        font { pixelSize: parent.height * 0.10; family: "monospace" }
        elide: Text.ElideRight
        width: parent.width - 4
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        id: pctLabel
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 2
        }
        text: BatteryMonitor.available
              ? BatteryMonitor.percentage.toFixed(0) + "%"
              : "–"
        color: {
            const p = BatteryMonitor.percentage
            return BatteryMonitor.charging ? "#44aaff"
                 : p < 10 ? "#ff2200"
                 : p < 25 ? "#ff8800"
                 : "#00cc44"
        }
        font { pixelSize: parent.height * 0.14; family: "monospace"; bold: true }
    }
}

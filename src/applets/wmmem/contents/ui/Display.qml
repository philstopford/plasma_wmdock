// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.private.wmdock 1.0

/**
 * WMMemMon – Memory and swap usage applet.
 *
 * Displays two horizontal bar graphs (RAM and Swap) with percentage
 * readouts, styled after the classic wmmemmon dockapp.
 */
Item {
    id: root

    // Relay SystemMonitor values at root scope so Qt6 inline-component
    // property bindings re-evaluate correctly when the notify signal fires.
    readonly property double ramPct:  SystemMonitor.memUsage
    readonly property double swapPct: SystemMonitor.swapUsage

    // -----------------------------------------------------------------------
    // Background
    // -----------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    // -----------------------------------------------------------------------
    // Layout helpers
    // -----------------------------------------------------------------------
    readonly property real innerW: width  - 6
    readonly property real innerH: height - 6
    readonly property real rowH:   (innerH - 30) / 2    // bar height

    // -----------------------------------------------------------------------
    // Title
    // -----------------------------------------------------------------------
    Text {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 2 }
        text: "MEM"
        color: "#00aaff"
        font { pixelSize: parent.height * 0.12; family: "monospace"; bold: true }
    }

    // -----------------------------------------------------------------------
    // Helper: single stat row (label + bar + percentage)
    // -----------------------------------------------------------------------
    component MemRow : Item {
        id: row
        property string label:   "RAM"
        property double pct:     0
        property color  barColor: "#0088ff"

        height: root.height * 0.26
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 3
        anchors.rightMargin: 3

        // Label
        Text {
            id: rowLabel
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: row.label
            color: "#888"
            font { pixelSize: parent.height * 0.55; family: "monospace" }
            width: parent.width * 0.22
        }

        // Bar background
        Rectangle {
            id: barBg
            anchors {
                left: rowLabel.right
                right: pctText.left
                verticalCenter: parent.verticalCenter
                leftMargin: 2; rightMargin: 2
            }
            height: parent.height * 0.55
            color: "#0a1a0a"
            radius: 1

            // Fill
            Rectangle {
                width:  Math.max(0, Math.min(1, row.pct / 100)) * parent.width
                height: parent.height
                color:  row.pct > 90 ? "#ff3300"
                      : row.pct > 70 ? "#aa8800"
                      : row.barColor
                radius: parent.radius
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }

        // Percentage
        Text {
            id: pctText
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: row.pct.toFixed(0) + "%"
            color: row.barColor
            font { pixelSize: parent.height * 0.52; family: "monospace" }
            width: parent.width * 0.27
            horizontalAlignment: Text.AlignRight
        }
    }

    // -----------------------------------------------------------------------
    // RAM row
    // -----------------------------------------------------------------------
    MemRow {
        id: ramRow
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.18
        label:    "RAM"
        pct:      root.ramPct
        barColor: "#0088ff"
    }

    // -----------------------------------------------------------------------
    // Swap row
    // -----------------------------------------------------------------------
    MemRow {
        id: swapRow
        anchors.top: ramRow.bottom
        anchors.topMargin: 3
        label:    "SWP"
        pct:      root.swapPct
        barColor: "#ff8800"
    }

    // -----------------------------------------------------------------------
    // Numeric values
    // -----------------------------------------------------------------------
    function fmtBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + "G"
        if (b >= 1048576)    return (b / 1048576).toFixed(0)    + "M"
        return (b / 1024).toFixed(0) + "K"
    }

    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 2
        }
        text: fmtBytes(SystemMonitor.memUsed) + "/" + fmtBytes(SystemMonitor.memTotal)
        color: "#006699"
        font { pixelSize: parent.height * 0.11; family: "monospace" }
    }
}

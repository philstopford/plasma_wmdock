// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.ksystemstats 1.0

/**
 * WMMemMon – Memory and swap usage applet.
 *
 * Uses KDE's org.kde.ksystemstats QML API (same backend as KDE's own
 * "Memory Usage" widget).  The ksystemstats memory plugin reports totals
 * and used amounts in KiB (matching /proc/meminfo units), so fmtKiB() is
 * used for byte display instead of a raw-byte formatter.
 *
 * Displays two horizontal bar graphs (RAM and Swap) with percentage
 * readouts, styled after the classic wmmemmon dockapp.
 */
Item {
    id: root

    // -----------------------------------------------------------------------
    // ksystemstats sensors
    // -----------------------------------------------------------------------
    Sensor { id: memUsedPctSensor;  sensorId: "memory/physical/usedPercent"; enabled: true }
    Sensor { id: memUsedSensor;     sensorId: "memory/physical/used";        enabled: true }
    Sensor { id: memTotalSensor;    sensorId: "memory/physical/total";       enabled: true }
    Sensor { id: swapUsedPctSensor; sensorId: "memory/swap/usedPercent";     enabled: true }
    Sensor { id: swapUsedSensor;    sensorId: "memory/swap/used";            enabled: true }
    Sensor { id: swapTotalSensor;   sensorId: "memory/swap/total";           enabled: true }

    // Convenience aliases with safe fallback to 0 before first data arrives
    readonly property real memPct:   memUsedPctSensor.value  != null ? memUsedPctSensor.value  : 0
    readonly property real swapPct:  swapUsedPctSensor.value != null ? swapUsedPctSensor.value : 0
    readonly property real memUsed:  memUsedSensor.value     != null ? memUsedSensor.value     : 0
    readonly property real memTotal: memTotalSensor.value    != null ? memTotalSensor.value    : 0

    // KiB → human-readable string (ksystemstats memory values are in KiB)
    function fmtKiB(kib) {
        if (kib >= 1048576) return (kib / 1048576).toFixed(1) + "G"
        if (kib >= 1024)    return (kib / 1024).toFixed(0)    + "M"
        return kib.toFixed(0) + "K"
    }

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
    // Title
    // -----------------------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 2 }
        text: "MEM"
        color: "#00aaff"
        font { pixelSize: parent.height * 0.12; family: "monospace"; bold: true }
    }

    // -----------------------------------------------------------------------
    // RAM row
    // -----------------------------------------------------------------------
    Item {
        id: ramRow
        anchors {
            top:        titleText.bottom
            topMargin:  parent.height * 0.04
            left:       parent.left
            right:      parent.right
            leftMargin: 3; rightMargin: 3
        }
        height: parent.height * 0.24

        Text {
            id: ramLabel
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "RAM"
            color: "#888"
            font { pixelSize: parent.height * 0.55; family: "monospace" }
            width: parent.width * 0.22
        }
        Rectangle {
            id: ramBarBg
            anchors {
                left: ramLabel.right; right: ramPctText.left
                verticalCenter: parent.verticalCenter
                leftMargin: 2; rightMargin: 2
            }
            height: parent.height * 0.55
            color: "#0a1a0a"
            radius: 1
            Rectangle {
                width:  Math.max(0, Math.min(1, root.memPct / 100)) * parent.width
                height: parent.height
                color:  root.memPct > 90 ? "#ff3300"
                      : root.memPct > 70 ? "#aa8800"
                      : "#0088ff"
                radius: parent.radius
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
        Text {
            id: ramPctText
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.memPct.toFixed(0) + "%"
            color: "#0088ff"
            font { pixelSize: parent.height * 0.52; family: "monospace" }
            width: parent.width * 0.27
            horizontalAlignment: Text.AlignRight
        }
    }

    // -----------------------------------------------------------------------
    // Swap row
    // -----------------------------------------------------------------------
    Item {
        id: swapRow
        anchors {
            top:        ramRow.bottom
            topMargin:  3
            left:       parent.left
            right:      parent.right
            leftMargin: 3; rightMargin: 3
        }
        height: parent.height * 0.24

        Text {
            id: swapLabel
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "SWP"
            color: "#888"
            font { pixelSize: parent.height * 0.55; family: "monospace" }
            width: parent.width * 0.22
        }
        Rectangle {
            id: swapBarBg
            anchors {
                left: swapLabel.right; right: swapPctText.left
                verticalCenter: parent.verticalCenter
                leftMargin: 2; rightMargin: 2
            }
            height: parent.height * 0.55
            color: "#0a1a0a"
            radius: 1
            Rectangle {
                width:  Math.max(0, Math.min(1, root.swapPct / 100)) * parent.width
                height: parent.height
                color:  root.swapPct > 90 ? "#ff3300"
                      : root.swapPct > 70 ? "#aa8800"
                      : "#ff8800"
                radius: parent.radius
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
        Text {
            id: swapPctText
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.swapPct.toFixed(0) + "%"
            color: "#ff8800"
            font { pixelSize: parent.height * 0.52; family: "monospace" }
            width: parent.width * 0.27
            horizontalAlignment: Text.AlignRight
        }
    }

    // -----------------------------------------------------------------------
    // Numeric values (used / total) in KiB-aware format
    // -----------------------------------------------------------------------
    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 2
        }
        text: fmtKiB(root.memUsed) + "/" + fmtKiB(root.memTotal)
        color: "#006699"
        font { pixelSize: parent.height * 0.11; family: "monospace" }
    }
}

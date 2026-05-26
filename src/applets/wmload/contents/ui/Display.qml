// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.private.wmdock 1.0

/**
 * WMLoad – System load-average applet.
 *
 * Three stacked rows show 1-min, 5-min and 15-min load averages,
 * each with a colour-coded horizontal bar and a numeric readout.
 * Styled after the classic wmloadavg dockapp.
 *
 * Vertical layout ensures numeric values never overflow even under
 * sustained full load on many-core systems.  The bar scale is
 * 0 – 2×numCores so the bar reaches 50% at full load (1.0 per core);
 * colour shifts amber at 75% and red above 100% of core count.
 */
Item {
    id: root

    readonly property int numCores: Math.max(1, SystemMonitor.cpuCoreCount)

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
    // Row-area container (fills full height)
    // -----------------------------------------------------------------------
    Item {
        id: rowArea
        anchors {
            top:    parent.top
            bottom: parent.bottom
            left:   parent.left
            right:  parent.right
            topMargin:    2
            bottomMargin: 2
            leftMargin:   3
            rightMargin:  3
        }

        // -------------------------------------------------------------------
        // Helper: bar fill colour
        // -------------------------------------------------------------------
        function loadColor(load) {
            return load > root.numCores        ? "#ff3300"
                 : load > root.numCores * 0.75 ? "#ffaa00"
                 : "#cc8800"
        }

        // -------------------------------------------------------------------
        // Helper: compact numeric format (always ≤ 5 chars)
        // -------------------------------------------------------------------
        function fmtLoad(v) {
            return v >= 10 ? v.toFixed(1) : v.toFixed(2)
        }

        // -------------------------------------------------------------------
        // 1-min row
        // -------------------------------------------------------------------
        Item {
            id: row1
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height / 3

            Text {
                id: lbl1
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text:  "1m"
                color: "#555"
                font { pixelSize: parent.height * 0.42; family: "monospace" }
                width: parent.width * 0.22
            }
            Rectangle {
                anchors {
                    left: lbl1.right; right: val1.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 2; rightMargin: 2
                }
                height: parent.height * 0.50
                color: "#0a0800"; radius: 1
                Rectangle {
                    width:  Math.min(1, SystemMonitor.load1 / (root.numCores * 2)) * parent.width
                    height: parent.height
                    color:  rowArea.loadColor(SystemMonitor.load1)
                    radius: parent.radius
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
            Text {
                id: val1
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text:  rowArea.fmtLoad(SystemMonitor.load1)
                color: rowArea.loadColor(SystemMonitor.load1)
                font { pixelSize: parent.height * 0.42; family: "monospace" }
                width: parent.width * 0.36
                horizontalAlignment: Text.AlignRight
            }
        }

        // -------------------------------------------------------------------
        // 5-min row
        // -------------------------------------------------------------------
        Item {
            id: row5
            anchors { top: row1.bottom; left: parent.left; right: parent.right }
            height: parent.height / 3

            Text {
                id: lbl5
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text:  "5m"
                color: "#555"
                font { pixelSize: parent.height * 0.42; family: "monospace" }
                width: parent.width * 0.22
            }
            Rectangle {
                anchors {
                    left: lbl5.right; right: val5.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 2; rightMargin: 2
                }
                height: parent.height * 0.50
                color: "#0a0800"; radius: 1
                Rectangle {
                    width:  Math.min(1, SystemMonitor.load5 / (root.numCores * 2)) * parent.width
                    height: parent.height
                    color:  rowArea.loadColor(SystemMonitor.load5)
                    radius: parent.radius
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
            Text {
                id: val5
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text:  rowArea.fmtLoad(SystemMonitor.load5)
                color: rowArea.loadColor(SystemMonitor.load5)
                font { pixelSize: parent.height * 0.42; family: "monospace" }
                width: parent.width * 0.36
                horizontalAlignment: Text.AlignRight
            }
        }

        // -------------------------------------------------------------------
        // 15-min row
        // -------------------------------------------------------------------
        Item {
            id: row15
            anchors { top: row5.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }

            Text {
                id: lbl15
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text:  "15m"
                color: "#555"
                font { pixelSize: parent.height * 0.42; family: "monospace" }
                width: parent.width * 0.22
            }
            Rectangle {
                anchors {
                    left: lbl15.right; right: val15.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 2; rightMargin: 2
                }
                height: parent.height * 0.50
                color: "#0a0800"; radius: 1
                Rectangle {
                    width:  Math.min(1, SystemMonitor.load15 / (root.numCores * 2)) * parent.width
                    height: parent.height
                    color:  rowArea.loadColor(SystemMonitor.load15)
                    radius: parent.radius
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
            Text {
                id: val15
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text:  rowArea.fmtLoad(SystemMonitor.load15)
                color: rowArea.loadColor(SystemMonitor.load15)
                font { pixelSize: parent.height * 0.42; family: "monospace" }
                width: parent.width * 0.36
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.private.wmdock 1.0

/**
 * WMLoad – System load-average applet.
 *
 * Displays three vertical bar graphs for 1-min, 5-min and 15-min
 * load averages, plus numeric readouts below each bar.
 * Styled after the classic wmloadavg dockapp.
 *
 * The bar scale is 0–numCPUs (load of 1.0 = 100% of one core).
 */
Item {
    id: root

    readonly property int numCores: Math.max(1, SystemMonitor.cpuCoreCount)

    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 2 }
        text: "LOAD"
        color: "#cc8800"
        font { pixelSize: parent.height * 0.12; family: "monospace"; bold: true }
    }

    // -----------------------------------------------------------------------
    // Three bars
    // -----------------------------------------------------------------------
    Row {
        id: barRow
        anchors {
            top:    titleText.bottom
            bottom: labelsRow.top
            left:   parent.left
            right:  parent.right
            topMargin:    4
            bottomMargin: 2
            leftMargin:   6
            rightMargin:  6
        }
        spacing: 4

        component LoadBar : Item {
            property double load:  0
            property int    cores: 1
            property color  col:   "#cc8800"

            // Clamp: bars go up to 2× core-count for visual drama
            readonly property double pct: Math.min(1.0, load / (Math.max(1, cores) * 2))

            Rectangle {
                anchors { fill: parent }
                color:  "#0a0800"
                radius: 1

                Rectangle {
                    width:  parent.width
                    height: Math.max(1, pct * parent.height)
                    anchors.bottom: parent.bottom
                    color: load > cores ? "#ff3300"
                         : load > cores * 0.75 ? "#ffaa00"
                         : col
                    radius: 1
                    Behavior on height { NumberAnimation { duration: 300 } }
                }
            }
        }

        LoadBar { id: bar1; load: SystemMonitor.load1;  cores: root.numCores; width: (parent.width - 8) / 3 }
        LoadBar { id: bar5; load: SystemMonitor.load5;  cores: root.numCores; width: (parent.width - 8) / 3 }
        LoadBar { id: bar15; load: SystemMonitor.load15; cores: root.numCores; width: (parent.width - 8) / 3 }
    }

    // -----------------------------------------------------------------------
    // Labels
    // -----------------------------------------------------------------------
    Row {
        id: labelsRow
        anchors {
            bottom: numRow.top
            left:   parent.left
            right:  parent.right
            leftMargin: 4
            rightMargin: 4
            bottomMargin: 1
        }
        spacing: 2

        Repeater {
            model: ["1m", "5m", "15m"]
            Text {
                width: (parent.width - 4) / 3
                text: modelData
                color: "#555"
                font { pixelSize: root.height * 0.09; family: "monospace" }
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Row {
        id: numRow
        anchors {
            bottom: parent.bottom
            left:   parent.left
            right:  parent.right
            bottomMargin: 2
            leftMargin:   4
            rightMargin:  4
        }
        spacing: 2

        Repeater {
            model: [SystemMonitor.load1, SystemMonitor.load5, SystemMonitor.load15]
            Text {
                width: (parent.width - 4) / 3
                text:  modelData.toFixed(2)
                color: modelData > root.numCores ? "#ff3300"
                     : modelData > root.numCores * 0.75 ? "#ffaa00"
                     : "#cc8800"
                font { pixelSize: root.height * 0.11; family: "monospace" }
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}

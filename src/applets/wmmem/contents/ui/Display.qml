// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.private.wmdock 1.0

/**
 * WMMemMon – Memory and swap usage applet.
 *
 * Displays two horizontal bar graphs (RAM and Swap) with percentage
 * readouts, styled after the classic wmmemmon dockapp.
 *
 * Data source: SystemMonitor singleton from the wmdockplugin C++ extension.
 * Debug output appears in: journalctl --user -f -g wmmem
 * or when plasmashell is run from a terminal.
 *
 * Intentionally avoids QML inline components so that Qt6 property
 * change notifications from the C++ singleton propagate reliably to
 * every binding in this file.
 */
Item {
    id: root

    Component.onCompleted: {
        console.log("[wmmem] Display loaded; memUsage=" + SystemMonitor.memUsage.toFixed(1)
                    + "% memTotal=" + SystemMonitor.memTotal
                    + " swapUsage=" + SystemMonitor.swapUsage.toFixed(1) + "%")
    }

    Connections {
        target: SystemMonitor
        function onMemoryChanged() {
            console.log("[wmmem] memoryChanged: RAM=" + SystemMonitor.memUsage.toFixed(1)
                        + "% SWAP=" + SystemMonitor.swapUsage.toFixed(1) + "%")
        }
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
                width:  Math.max(0, Math.min(1, SystemMonitor.memUsage / 100)) * parent.width
                height: parent.height
                color:  SystemMonitor.memUsage > 90 ? "#ff3300"
                      : SystemMonitor.memUsage > 70 ? "#aa8800"
                      : "#0088ff"
                radius: parent.radius
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
        Text {
            id: ramPctText
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: SystemMonitor.memUsage.toFixed(0) + "%"
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
                width:  Math.max(0, Math.min(1, SystemMonitor.swapUsage / 100)) * parent.width
                height: parent.height
                color:  SystemMonitor.swapUsage > 90 ? "#ff3300"
                      : SystemMonitor.swapUsage > 70 ? "#aa8800"
                      : "#ff8800"
                radius: parent.radius
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
        Text {
            id: swapPctText
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: SystemMonitor.swapUsage.toFixed(0) + "%"
            color: "#ff8800"
            font { pixelSize: parent.height * 0.52; family: "monospace" }
            width: parent.width * 0.27
            horizontalAlignment: Text.AlignRight
        }
    }

    // -----------------------------------------------------------------------
    // Numeric values (used / total)
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

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.private.wmdock 1.0

/**
 * WMStorage – Mounted volume storage overview.
 *
 * Displays a scrollable list of mounted volumes, each showing:
 *   • Mount point (short name)
 *   • Horizontal usage bar (colour-coded green→yellow→red)
 *   • Percentage used and available space
 *
 * Data source: StorageMonitor C++ singleton (30-second refresh cycle).
 * The list auto-scrolls when there are more volumes than fit in the widget.
 */
Item {
    id: root

    // ----- background ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    // ----- title -----------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 2 }
        text: "DISK"
        color: "#00aaff"
        font { pixelSize: parent.height * 0.11; family: "monospace"; bold: true }
    }

    // ----- volume list -----------------------------------------------------
    ListView {
        id: volumeList
        anchors {
            top:          titleText.bottom; topMargin: 2
            left:         parent.left;  leftMargin:  3
            right:        parent.right; rightMargin: 3
            bottom:       parent.bottom; bottomMargin: 2
        }
        clip:    true
        model:   StorageMonitor.volumes
        spacing: 2

        // Auto-scroll when more volumes than visible
        property int scrollTick: 0
        Timer {
            interval: 3000
            repeat:   true
            running:  volumeList.contentHeight > volumeList.height
            onTriggered: {
                const maxY = volumeList.contentHeight - volumeList.height
                if (maxY <= 0) return
                volumeList.scrollTick++
                const pct  = (volumeList.scrollTick * 0.1) % 1.0
                volumeList.contentY = pct < 0.5 ? pct * 2 * maxY
                                                 : (1 - pct) * 2 * maxY
            }
        }

        delegate: Item {
            required property var modelData
            implicitWidth:  volumeList.width
            implicitHeight: root.height * 0.22

            // Mount-point name
            Text {
                id: nameLabel
                anchors { left: parent.left; top: parent.top }
                text:  modelData.displayName
                color: "#aaccff"
                font { pixelSize: parent.height * 0.42; family: "monospace" }
                width: parent.width * 0.32
                elide: Text.ElideRight
            }

            // Available space
            Text {
                anchors { right: parent.right; top: parent.top }
                text:  fmtBytes(modelData.availBytes) + " free"
                color: "#446688"
                font { pixelSize: parent.height * 0.40; family: "monospace" }
                horizontalAlignment: Text.AlignRight
            }

            // Usage bar background
            Rectangle {
                id: barBg
                anchors {
                    left:  parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: parent.height * 0.35
                color:  "#0a1a0a"
                radius: 1

                // Usage fill
                Rectangle {
                    width:  Math.max(0, Math.min(1, modelData.usedPct / 100)) * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: {
                        const p = modelData.usedPct
                        return p >= 90 ? "#dd2200"
                             : p >= 75 ? "#cc7700"
                             : p >= 50 ? "#aaaa00"
                             : "#00aa44"
                    }
                    Behavior on width { NumberAnimation { duration: 300 } }
                }

                // Percentage text overlay
                Text {
                    anchors.centerIn: parent
                    text:  modelData.usedPct + "%"
                    color: "#ffffff"
                    font { pixelSize: parent.height * 0.65; family: "monospace"; bold: true }
                }
            }

            Text {
                anchors.centerIn: volumeList
                visible: StorageMonitor.volumes.length === 0
                text: i18n("No volumes")
                color: "#666"
                font { pixelSize: parent.height * 0.11; family: "monospace" }
            }
        }
    }

    // ----- format bytes helper --------------------------------------------
    function fmtBytes(b) {
        if (b >= 1099511627776) return (b / 1099511627776).toFixed(1) + "T"
        if (b >= 1073741824)    return (b / 1073741824).toFixed(1)    + "G"
        if (b >= 1048576)       return (b / 1048576).toFixed(0)       + "M"
        return (b / 1024).toFixed(0) + "K"
    }
}

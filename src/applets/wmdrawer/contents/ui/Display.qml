// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.wmdock 1.0

/**
 * WMDrawer – Application launcher drawer button.
 *
 * Displays a single dock button. Left-click opens a popup showing all
 * configured launchers. The popup stays open until the user presses
 * the Close button or clicks outside.
 *
 * Configuration (when embedded in WMDock) is supplied via externalDrawerIcon,
 * externalDrawerLabel and externalLaunchers, injected by DockSlot.  When used
 * as a standalone plasmoid the values come from Plasmoid.configuration.
 */
Item {
    id: root

    // -----------------------------------------------------------------------
    // External config (injected by DockSlot when embedded in WMDock)
    // -----------------------------------------------------------------------
    property string externalDrawerIcon:  ""
    property string externalDrawerLabel: ""
    property var    externalLaunchers:   null   // array of {command,icon,label}

    // -----------------------------------------------------------------------
    // Resolved configuration
    // -----------------------------------------------------------------------
    property string drawerIcon:  externalDrawerIcon  || Plasmoid.configuration.drawerIcon  || "folder"
    property string drawerLabel: externalDrawerLabel || Plasmoid.configuration.drawerLabel || "Apps"
    property var    launchers: {
        if (externalLaunchers !== null) return externalLaunchers
        try { return JSON.parse(Plasmoid.configuration.launchersJson) }
        catch(e) { return [] }
    }

    property bool pressed: false

    // -----------------------------------------------------------------------
    // Drawer button body
    // -----------------------------------------------------------------------
    Rectangle {
        id: buttonBody
        anchors { fill: parent; margins: pressed ? 2 : 1 }
        color:   pressed ? "#111" : "#1e1e1e"
        radius:  4
        border.color: pressed ? "#333" : "#666"
        border.width: 1

        Behavior on anchors.margins { NumberAnimation { duration: 60 } }
        Behavior on color           { ColorAnimation  { duration: 60 } }

        Rectangle {
            visible: !pressed
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: "#888"
            radius: parent.radius
        }
        Rectangle {
            visible: !pressed
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: "#222"
            radius: parent.radius
        }
    }

    // -----------------------------------------------------------------------
    // Drawer icon
    // -----------------------------------------------------------------------
    Kirigami.Icon {
        id: drawerIconItem
        anchors {
            horizontalCenter: parent.horizontalCenter
            top:    parent.top
            bottom: drawerLabelText.visible ? drawerLabelText.top : parent.bottom
            topMargin:    6
            bottomMargin: 2
        }
        width:  Math.min(implicitWidth, parent.width - 12)
        height: width
        source: drawerIcon
        isMask: false
    }

    // Small "open" indicator arrow
    Text {
        anchors {
            bottom: drawerIconItem.bottom
            right:  drawerIconItem.right
        }
        text:  drawerPopup.visible ? "▲" : "▼"
        color: "#aaaaaa"
        font.pixelSize: Math.max(8, parent.height * 0.12)
    }

    // -----------------------------------------------------------------------
    // Drawer label
    // -----------------------------------------------------------------------
    Text {
        id: drawerLabelText
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 3
        }
        visible: drawerLabel.length > 0
        text:    drawerLabel
        color:   "#cccccc"
        font { pixelSize: parent.height * 0.12; family: "monospace" }
        elide:   Text.ElideRight
        width:   parent.width - 6
        horizontalAlignment: Text.AlignHCenter
    }

    // -----------------------------------------------------------------------
    // Click interaction
    // -----------------------------------------------------------------------
    TapHandler {
        id: tapHandler
        acceptedButtons: Qt.LeftButton
        onPressedChanged: root.pressed = tapHandler.pressed
        onTapped: {
            if (drawerPopup.visible) {
                drawerPopup.close()
            } else {
                drawerPopup.openDrawer()
            }
        }
    }

    QQC2.ToolTip {
        visible: hoverHandler.hovered && !drawerPopup.visible
        text:    root.drawerLabel
        delay:   700
    }
    HoverHandler { id: hoverHandler }

    // -----------------------------------------------------------------------
    // Drawer popup
    // -----------------------------------------------------------------------
    QQC2.Popup {
        id: drawerPopup

        parent: QQC2.Overlay.overlay
        modal: false
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent

        padding: 8

        function openDrawer() {
            // Position above (or below) the dock button
            var pt = root.mapToItem(QQC2.Overlay.overlay, 0, 0)
            var popW = Math.max(160, Math.ceil(Math.sqrt(Math.max(1, root.launchers.length))) * 62 + 24)
            var rowCount = Math.max(1, Math.ceil(root.launchers.length / Math.max(1, Math.ceil(Math.sqrt(Math.max(1, root.launchers.length))))))
            var popH = 44 + rowCount * 62 + 16

            width  = popW
            height = popH

            // Prefer opening above
            if (pt.y - popH - 4 >= 0) {
                x = pt.x + root.width / 2 - popW / 2
                y = pt.y - popH - 4
            } else {
                x = pt.x + root.width / 2 - popW / 2
                y = pt.y + root.height + 4
            }
            open()
        }

        background: Rectangle {
            color:   "#1c1c1c"
            border.color: "#555"
            border.width: 1
            radius: 6
            Rectangle {
                width: parent.width - 2
                height: parent.height - 2
                x: 1; y: 1
                color: "transparent"
                border.color: "#666"
                border.width: 1
                radius: parent.radius - 1
                opacity: 0.4
            }
        }

        contentItem: ColumnLayout {
            spacing: 4

            // Header bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.drawerLabel
                    color: "#cccccc"
                    font { pixelSize: 12; family: "monospace"; bold: true }
                    Layout.fillWidth: true
                }

                QQC2.ToolButton {
                    icon.name: "window-close"
                    flat: true
                    onClicked: drawerPopup.close()
                    implicitWidth:  20
                    implicitHeight: 20
                }
            }

            // Horizontal divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#444"
            }

            // Launcher grid
            Flow {
                id: launcherFlow
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.launchers

                    delegate: Item {
                        id: launchItem
                        width:  56
                        height: 56

                        property bool itemPressed: false

                        Rectangle {
                            anchors { fill: parent; margins: launchItem.itemPressed ? 2 : 1 }
                            color:   launchItem.itemPressed ? "#111" : "#252525"
                            radius:  4
                            border.color: launchItem.itemPressed ? "#333" : "#555"
                            border.width: 1

                            Behavior on anchors.margins { NumberAnimation { duration: 60 } }
                            Behavior on color           { ColorAnimation  { duration: 60 } }
                        }

                        Kirigami.Icon {
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                top: parent.top
                                bottom: itemLabel.top
                                topMargin: 5
                                bottomMargin: 1
                            }
                            width: Math.min(implicitWidth, parent.width - 10)
                            height: width
                            source: modelData.icon || "application-x-executable"
                            isMask: false
                        }

                        Text {
                            id: itemLabel
                            anchors {
                                bottom: parent.bottom
                                horizontalCenter: parent.horizontalCenter
                                bottomMargin: 3
                            }
                            text:  modelData.label || modelData.command || "Launch"
                            color: "#cccccc"
                            font { pixelSize: 9; family: "monospace" }
                            elide: Text.ElideRight
                            width: parent.width - 6
                            horizontalAlignment: Text.AlignHCenter
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onPressedChanged: launchItem.itemPressed = pressed
                            onTapped: {
                                var cmd = modelData.command || ""
                                if (cmd) ProcessLauncher.launch(cmd)
                            }
                        }

                        QQC2.ToolTip {
                            visible: itemHover.hovered
                            text:    modelData.command || ""
                            delay:   700
                        }
                        HoverHandler { id: itemHover }
                    }
                }

                // Empty state
                Text {
                    visible: root.launchers.length === 0
                    text:    i18n("No launchers configured.\nRight-click the drawer to configure.")
                    color:   "#888888"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    width:   200
                }
            }
        }
    }
}

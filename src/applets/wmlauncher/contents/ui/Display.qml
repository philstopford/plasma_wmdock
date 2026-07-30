// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.wmdock 1.0

/**
 * WMLauncher – Application launcher button.
 *
 * A single 64×64 button that launches a configured application.
 * The icon and command are configurable via right-click → Configure.
 * Left-click launches; middle-click shows a tooltip with the command.
 *
 * Styled as a raised dock button, inset when pressed (like a physical key).
 */
Item {
    id: root

    // Persisted configuration (used when running standalone)
    property string launchCommand:  externalCommand  || Plasmoid.configuration.command  || "konsole"
    property string launchIcon:     externalIcon     || Plasmoid.configuration.icon     || "utilities-terminal"
    property string launchLabel:    externalLabel    || Plasmoid.configuration.label    || "Launch"
    property bool   showLabel:      externalShowLabel !== null ? externalShowLabel
                                    : (Plasmoid.configuration.showLabel !== false)

    // External config injected by DockSlot when embedded in WMDock
    property string externalCommand:  ""
    property string externalIcon:     ""
    property string externalLabel:    ""
    property var    externalShowLabel: null

    property bool pressed: false

    // -----------------------------------------------------------------------
    // Background / button body
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

        // Highlight edge (top/left shine)
        Rectangle {
            visible: !pressed
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: "#888"
            radius: parent.radius
        }

        // Shadow edge (bottom/right)
        Rectangle {
            visible: !pressed
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: "#222"
            radius: parent.radius
        }
    }

    // -----------------------------------------------------------------------
    // Icon
    // -----------------------------------------------------------------------
    Kirigami.Icon {
        id: appIcon
        anchors {
            horizontalCenter: parent.horizontalCenter
            top:  parent.top
            bottom: labelText.visible ? labelText.top : parent.bottom
            topMargin: showLabel ? 6 : 8
            bottomMargin: 2
        }
        width:  height
        source: launchIcon
        isMask: false
    }

    // -----------------------------------------------------------------------
    // Label
    // -----------------------------------------------------------------------
    Text {
        id: labelText
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 3
        }
        visible: showLabel
        text:    launchLabel
        color:   "#cccccc"
        font { pixelSize: parent.height * 0.12; family: "monospace" }
        elide:   Text.ElideRight
        width:   parent.width - 6
        horizontalAlignment: Text.AlignHCenter
    }

    // -----------------------------------------------------------------------
    // Interaction
    // -----------------------------------------------------------------------
    TapHandler {
        id: tapHandler
        acceptedButtons: Qt.LeftButton
        onPressedChanged: root.pressed = tapHandler.pressed
        onTapped: launchApp()
    }

    function launchApp() {
        ProcessLauncher.launch(root.launchCommand)
    }

    // Tooltip showing command
    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: root.launchCommand
        location: Plasmoid.location
    }
}

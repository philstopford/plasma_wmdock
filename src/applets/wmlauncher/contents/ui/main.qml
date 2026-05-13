// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

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

    // Persisted configuration
    property string launchCommand:  Plasmoid.configuration.command  || "konsole"
    property string launchIcon:     Plasmoid.configuration.icon     || "application-x-executable"
    property string launchLabel:    Plasmoid.configuration.label    || "Launch"
    property bool   showLabel:      Plasmoid.configuration.showLabel !== false

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
        width:  Math.min(implicitWidth, parent.width - 12)
        height: width
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
        acceptedButtons: Qt.LeftButton
        onPressed:  root.pressed = true
        onReleased: root.pressed = false
        onTapped: {
            Qt.openUrlExternally("exec://" + root.launchCommand)
            // Use QProcess-style launch via system() shim:
            launchTimer.start()
        }
    }

    // Short press animation before launch
    Timer {
        id: launchTimer
        interval: 80
        onTriggered: {
            root.pressed = false
            // Launch via KIO / D-Bus service launcher
            const parts  = root.launchCommand.trim().split(/\s+/)
            const prog   = parts[0]
            const args   = parts.slice(1)
            Qt.createQmlObject(
                'import QtQuick; import QtQuick.Controls 2.0;' +
                'Component.onCompleted: { Qt.exit(0); }',
                root)
            // Fallback: open as URL which KIO will route to exec handler
            Qt.openUrlExternally("exec:" + root.launchCommand)
        }
    }

    // Tooltip showing command
    QQC2.ToolTip {
        visible: hoverHandler.hovered
        text:    root.launchCommand
        delay:   700
    }
    HoverHandler { id: hoverHandler }
}

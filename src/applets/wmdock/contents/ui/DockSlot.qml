// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

/**
 * DockSlot – hosts one mini-applet by embedding its QML as a Loader.
 *
 * The Loader resolves the applet QML from its package path.
 * A right-click context menu allows removing, moving, or configuring
 * the applet.
 */
Item {
    id: slot

    property string appletId:   ""
    property int    slotIndex:  0
    property int    totalCount: 1

    signal removeRequested()
    signal moveLeft()
    signal moveRight()

    // -----------------------------------------------------------------------
    // Outer slot border  (classic raised/inset WM look)
    // -----------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#555"
        border.width: 1
        radius: 2

        // inner highlight
        Rectangle {
            anchors { fill: parent; margins: 1 }
            color: "transparent"
            border.color: "#2a2a2a"
            border.width: 1
            radius: parent.radius
        }
    }

    // -----------------------------------------------------------------------
    // Applet loader
    // -----------------------------------------------------------------------
    Loader {
        id: appletLoader
        anchors { fill: parent; margins: 2 }
        source: resolveSource(appletId)
        asynchronous: true

        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("WMDock: failed to load applet", appletId, errorString())
            }
        }
    }

    // -----------------------------------------------------------------------
    // Busy indicator while loading
    // -----------------------------------------------------------------------
    PlasmaComponents.BusyIndicator {
        anchors.centerIn: parent
        running: appletLoader.status === Loader.Loading
        visible: running
    }

    // -----------------------------------------------------------------------
    // Error state
    // -----------------------------------------------------------------------
    PlasmaComponents.Label {
        anchors.centerIn: parent
        visible: appletLoader.status === Loader.Error
        text: "?"
        color: "#ff4444"
        font.pixelSize: parent.height * 0.4
    }

    // -----------------------------------------------------------------------
    // Context menu (right-click)
    // -----------------------------------------------------------------------
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: slotMenu.popup()
    }

    QQC2.Menu {
        id: slotMenu

        QQC2.MenuItem {
            text: i18n("Move Left")
            enabled: slotIndex > 0
            onTriggered: slot.moveLeft()
        }
        QQC2.MenuItem {
            text: i18n("Move Right")
            enabled: slotIndex < totalCount - 1
            onTriggered: slot.moveRight()
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: i18n("Remove")
            onTriggered: slot.removeRequested()
        }
    }

    // -----------------------------------------------------------------------
    // Helper: map applet ID → QML source URL
    // -----------------------------------------------------------------------
    function resolveSource(id) {
        const map = {
            "org.kde.plasma.wmclock":    Qt.resolvedUrl("../../../wmclock/contents/ui/main.qml"),
            "org.kde.plasma.wmcpu":      Qt.resolvedUrl("../../../wmcpu/contents/ui/main.qml"),
            "org.kde.plasma.wmmem":      Qt.resolvedUrl("../../../wmmem/contents/ui/main.qml"),
            "org.kde.plasma.wmbattery":  Qt.resolvedUrl("../../../wmbattery/contents/ui/main.qml"),
            "org.kde.plasma.wmnet":      Qt.resolvedUrl("../../../wmnet/contents/ui/main.qml"),
            "org.kde.plasma.wmmixer":    Qt.resolvedUrl("../../../wmmixer/contents/ui/main.qml"),
            "org.kde.plasma.wmload":     Qt.resolvedUrl("../../../wmload/contents/ui/main.qml"),
            "org.kde.plasma.wmcal":      Qt.resolvedUrl("../../../wmcal/contents/ui/main.qml"),
            "org.kde.plasma.wmlauncher": Qt.resolvedUrl("../../../wmlauncher/contents/ui/main.qml"),
            "org.kde.plasma.wmweather":  Qt.resolvedUrl("../../../wmweather/contents/ui/main.qml"),
        }
        return map[id] || ""
    }
}

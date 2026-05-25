// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
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
    property string slotConfig: ""   // JSON config for this slot

    signal removeRequested()
    signal moveLeft()
    signal moveRight()
    signal slotConfigSaved(int index, string config)

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
                console.warn("WMDock: failed to load applet", appletId, appletLoader.errorString)
            }
            if (status === Loader.Ready) {
                applySlotConfig()
                // When the drawer completes a drag-reorder, persist the new
                // order back into this slot's config so it survives restart.
                if (appletId === "org.kde.plasma.wmdrawer") {
                    appletLoader.item.launchersReordered.connect(function(newLaunchers) {
                        try {
                            var cfg = slotConfig ? JSON.parse(slotConfig) : {}
                            cfg.launchers = newLaunchers
                            slot.slotConfigSaved(slotIndex, JSON.stringify(cfg))
                        } catch(e) {
                            console.warn("WMDock: failed to parse or save reordered launchers for slot", slotIndex, e)
                        }
                    })
                }
            }
        }
    }

    // Apply slotConfig to the loaded item whenever config or item changes
    function applySlotConfig() {
        if (!appletLoader.item) return
        // Always propagate orientation so the drawer opens in the correct direction
        // regardless of whether slotConfig has been populated yet.
        // Plasma 6 location: 5 = LeftEdge, 6 = RightEdge → vertical dock; all others → horizontal dock.
        appletLoader.item.externalOrientation =
            (Plasmoid.location === 5 || Plasmoid.location === 6) ? "vertical" : "horizontal"
        if (!slotConfig) return
        try {
            var cfg = JSON.parse(slotConfig)
            // Pass to item via named properties (if the item exposes them)
            if (cfg.command    !== undefined) appletLoader.item.externalCommand   = cfg.command
            if (cfg.icon       !== undefined) appletLoader.item.externalIcon      = cfg.icon
            if (cfg.label      !== undefined) appletLoader.item.externalLabel     = cfg.label
            if (cfg.showLabel  !== undefined) appletLoader.item.externalShowLabel = cfg.showLabel
            if (cfg.drawerIcon !== undefined) appletLoader.item.externalDrawerIcon  = cfg.drawerIcon
            if (cfg.drawerLabel!== undefined) appletLoader.item.externalDrawerLabel = cfg.drawerLabel
            if (cfg.launchers  !== undefined) appletLoader.item.externalLaunchers  = cfg.launchers
        } catch(e) {
            console.warn("WMDock: failed to parse slotConfig for", appletId, e)
        }
    }

    onSlotConfigChanged: applySlotConfig()

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
    //
    // We use a MouseArea that fills the slot and explicitly accepts the right
    // button.  This runs at the QML level and fires before Plasma's panel
    // event-filter, so the slot-specific menu (Move/Configure/Remove) will
    // appear instead of the global "Remove Widget" menu.
    // -----------------------------------------------------------------------
    MouseArea {
        anchors.fill:    parent
        acceptedButtons: Qt.RightButton
        // Allow left-click to pass through to the embedded applet
        propagateComposedEvents: true
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                slotMenu.popup()
                mouse.accepted = true
            }
        }
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
            text: i18n("Configure Applet…")
            visible: appletId === "org.kde.plasma.wmlauncher" ||
                     appletId === "org.kde.plasma.wmdrawer"
            height: visible ? implicitHeight : 0
            onTriggered: {
                if (appletId === "org.kde.plasma.wmlauncher") {
                    launcherConfigDialog.openForSlot()
                } else if (appletId === "org.kde.plasma.wmdrawer") {
                    drawerConfigDialog.openForSlot()
                }
            }
        }
        QQC2.MenuSeparator {
            visible: appletId === "org.kde.plasma.wmlauncher" ||
                     appletId === "org.kde.plasma.wmdrawer"
            height: visible ? implicitHeight : 0
        }
        QQC2.MenuItem {
            text: i18n("Remove")
            onTriggered: slot.removeRequested()
        }
    }

    // -----------------------------------------------------------------------
    // Launcher configure dialog
    // -----------------------------------------------------------------------
    QQC2.Dialog {
        id: launcherConfigDialog
        title: i18n("Configure Launcher")
        modal: true
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: 340

        function openForSlot() {
            // Pre-fill from current slotConfig
            try {
                var cfg = slotConfig ? JSON.parse(slotConfig) : {}
                cmdField.text       = cfg.command   || "konsole"
                iconField.text      = cfg.icon      || "utilities-terminal"
                labelField.text     = cfg.label     || "Launch"
                showLabelBox.checked = cfg.showLabel !== false
            } catch(e) {
                cmdField.text       = "konsole"
                iconField.text      = "utilities-terminal"
                labelField.text     = "Launch"
                showLabelBox.checked = true
            }
            open()
        }

        contentItem: Kirigami.FormLayout {
            QQC2.TextField {
                id: cmdField
                Kirigami.FormData.label: i18n("Command:")
                placeholderText: "konsole"
            }
            // Icon field with live preview
            RowLayout {
                Kirigami.FormData.label: i18n("Icon name:")
                spacing: Kirigami.Units.smallSpacing
                QQC2.TextField {
                    id: iconField
                    Layout.fillWidth: true
                    placeholderText: "utilities-terminal"
                }
                Kirigami.Icon {
                    source: iconField.text || "utilities-terminal"
                    width:  Kirigami.Units.iconSizes.medium
                    height: Kirigami.Units.iconSizes.medium
                    isMask: false
                }
            }
            QQC2.TextField {
                id: labelField
                Kirigami.FormData.label: i18n("Label:")
                placeholderText: "Launch"
            }
            QQC2.CheckBox {
                id: showLabelBox
                Kirigami.FormData.label: i18n("Show label:")
                checked: true
            }
        }

        footer: QQC2.DialogButtonBox {
            QQC2.Button {
                text: i18n("OK")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
            }
            QQC2.Button {
                text: i18n("Cancel")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole
            }
        }

        onAccepted: {
            var cfg = {
                command:   cmdField.text   || "konsole",
                icon:      iconField.text  || "utilities-terminal",
                label:     labelField.text || "Launch",
                showLabel: showLabelBox.checked
            }
            slot.slotConfigSaved(slotIndex, JSON.stringify(cfg))
        }
    }

    // -----------------------------------------------------------------------
    // Drawer configure dialog
    // -----------------------------------------------------------------------
    QQC2.Dialog {
        id: drawerConfigDialog
        title: i18n("Configure Drawer")
        modal: true
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: 400
        height: 480

        property var editingLaunchers: []

        function openForSlot() {
            try {
                var cfg = slotConfig ? JSON.parse(slotConfig) : {}
                drawerIconField.text  = cfg.drawerIcon  || "folder"
                drawerLabelField.text = cfg.drawerLabel || "Apps"
                editingLaunchers = cfg.launchers ? JSON.parse(JSON.stringify(cfg.launchers)) : []
            } catch(e) {
                drawerIconField.text  = "folder"
                drawerLabelField.text = "Apps"
                editingLaunchers = []
            }
            launcherListView.reload()
            open()
        }

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true
                QQC2.TextField {
                    id: drawerIconField
                    Kirigami.FormData.label: i18n("Drawer icon:")
                    placeholderText: "folder"
                }
                QQC2.TextField {
                    id: drawerLabelField
                    Kirigami.FormData.label: i18n("Drawer label:")
                    placeholderText: "Apps"
                }
            }

            PlasmaComponents.Label { text: i18n("Launchers:") }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: launcherListView
                    model: ListModel { id: launcherListModel }

                    function reload() {
                        launcherListModel.clear()
                        for (var i = 0; i < drawerConfigDialog.editingLaunchers.length; i++) {
                            var item = drawerConfigDialog.editingLaunchers[i]
                            launcherListModel.append({
                                cmd:   item.command || "",
                                ico:   item.icon    || "",
                                lbl:   item.label   || ""
                            })
                        }
                    }

                    delegate: RowLayout {
                        width: ListView.view.width
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: model.ico || "application-x-executable"
                            width:  Kirigami.Units.iconSizes.small
                            height: Kirigami.Units.iconSizes.small
                        }
                        PlasmaComponents.Label {
                            text: model.lbl || model.cmd
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        QQC2.ToolButton {
                            icon.name: "document-edit"
                            onClicked: launcherEditDialog.openFor(index)
                        }
                        QQC2.ToolButton {
                            icon.name: "list-remove"
                            onClicked: {
                                drawerConfigDialog.editingLaunchers.splice(index, 1)
                                launcherListView.reload()
                            }
                        }
                    }
                }
            }

            QQC2.Button {
                text: i18n("Add Launcher…")
                Layout.alignment: Qt.AlignLeft
                onClicked: launcherEditDialog.openFor(-1)
            }
        }

        footer: QQC2.DialogButtonBox {
            QQC2.Button {
                text: i18n("OK")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
            }
            QQC2.Button {
                text: i18n("Cancel")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole
            }
        }

        onAccepted: {
            var cfg = {
                drawerIcon:   drawerIconField.text  || "folder",
                drawerLabel:  drawerLabelField.text || "Apps",
                launchers:    editingLaunchers
            }
            slot.slotConfigSaved(slotIndex, JSON.stringify(cfg))
        }
    }

    // Sub-dialog: edit a single launcher entry in the drawer
    QQC2.Dialog {
        id: launcherEditDialog
        title: i18n("Edit Launcher")
        modal: true
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: 320

        property int editIndex: -1

        function openFor(idx) {
            editIndex = idx
            if (idx >= 0 && idx < drawerConfigDialog.editingLaunchers.length) {
                var item = drawerConfigDialog.editingLaunchers[idx]
                editCmdField.text   = item.command || ""
                editIconField.text  = item.icon    || ""
                editLabelField.text = item.label   || ""
            } else {
                editCmdField.text   = ""
                editIconField.text  = ""
                editLabelField.text = ""
            }
            open()
        }

        contentItem: Kirigami.FormLayout {
            QQC2.TextField {
                id: editCmdField
                Kirigami.FormData.label: i18n("Command:")
                placeholderText: "konsole"
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Icon name:")
                spacing: Kirigami.Units.smallSpacing
                QQC2.TextField {
                    id: editIconField
                    Layout.fillWidth: true
                    placeholderText: "utilities-terminal"
                }
                Kirigami.Icon {
                    source: editIconField.text || "application-x-executable"
                    width:  Kirigami.Units.iconSizes.medium
                    height: Kirigami.Units.iconSizes.medium
                    isMask: false
                }
            }
            QQC2.TextField {
                id: editLabelField
                Kirigami.FormData.label: i18n("Label:")
                placeholderText: "Terminal"
            }
        }

        footer: QQC2.DialogButtonBox {
            QQC2.Button {
                text: i18n("OK")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
            }
            QQC2.Button {
                text: i18n("Cancel")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole
            }
        }

        onAccepted: {
            var entry = {
                command: editCmdField.text  || "konsole",
                icon:    editIconField.text || "application-x-executable",
                label:   editLabelField.text || editCmdField.text || "Launch"
            }
            if (editIndex >= 0 && editIndex < drawerConfigDialog.editingLaunchers.length) {
                drawerConfigDialog.editingLaunchers[editIndex] = entry
            } else {
                drawerConfigDialog.editingLaunchers.push(entry)
            }
            launcherListView.reload()
        }
    }

    // -----------------------------------------------------------------------
    // Helper: map applet ID → QML source URL
    // -----------------------------------------------------------------------
    function resolveSource(id) {
        const map = {
            "org.kde.plasma.wmclock":    Qt.resolvedUrl("../../../org.kde.plasma.wmclock/contents/ui/Display.qml"),
            "org.kde.plasma.wmcpu":      Qt.resolvedUrl("../../../org.kde.plasma.wmcpu/contents/ui/Display.qml"),
            "org.kde.plasma.wmmem":      Qt.resolvedUrl("../../../org.kde.plasma.wmmem/contents/ui/Display.qml"),
            "org.kde.plasma.wmbattery":  Qt.resolvedUrl("../../../org.kde.plasma.wmbattery/contents/ui/Display.qml"),
            "org.kde.plasma.wmnet":      Qt.resolvedUrl("../../../org.kde.plasma.wmnet/contents/ui/Display.qml"),
            "org.kde.plasma.wmmixer":    Qt.resolvedUrl("../../../org.kde.plasma.wmmixer/contents/ui/Display.qml"),
            "org.kde.plasma.wmload":     Qt.resolvedUrl("../../../org.kde.plasma.wmload/contents/ui/Display.qml"),
            "org.kde.plasma.wmcal":      Qt.resolvedUrl("../../../org.kde.plasma.wmcal/contents/ui/Display.qml"),
            "org.kde.plasma.wmlauncher": Qt.resolvedUrl("../../../org.kde.plasma.wmlauncher/contents/ui/Display.qml"),
            "org.kde.plasma.wmweather":  Qt.resolvedUrl("../../../org.kde.plasma.wmweather/contents/ui/Display.qml"),
            "org.kde.plasma.wmdrawer":   Qt.resolvedUrl("../../../org.kde.plasma.wmdrawer/contents/ui/Display.qml"),
            "org.kde.plasma.wmviz":      Qt.resolvedUrl("../../../org.kde.plasma.wmviz/contents/ui/Display.qml"),
            "org.kde.plasma.wmplay":     Qt.resolvedUrl("../../../org.kde.plasma.wmplay/contents/ui/Display.qml"),
            "org.kde.plasma.wmeyes":     Qt.resolvedUrl("../../../org.kde.plasma.wmeyes/contents/ui/Display.qml"),
            "org.kde.plasma.wmlava":     Qt.resolvedUrl("../../../org.kde.plasma.wmlava/contents/ui/Display.qml"),
            "org.kde.plasma.wmsensors":  Qt.resolvedUrl("../../../org.kde.plasma.wmsensors/contents/ui/Display.qml"),
            "org.kde.plasma.wmstorage":  Qt.resolvedUrl("../../../org.kde.plasma.wmstorage/contents/ui/Display.qml"),
        }
        return map[id] || ""
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    PlasmaCore.Action {
        id: addLauncherAction
        text: i18n("Add Launcher…")
        icon.name: "list-add"
        onTriggered: drawerDisplay.editLauncher(-1)
    }

    PlasmaCore.Action {
        id: importDrawerAction
        text: i18n("Import Drawer…")
        icon.name: "document-import"
        onTriggered: drawerDisplay.openImportDialog()
    }

    PlasmaCore.Action {
        id: exportDrawerAction
        text: i18n("Export Drawer…")
        icon.name: "document-export"
        onTriggered: drawerDisplay.openExportDialog()
    }

    Plasmoid.contextualActions: [addLauncherAction, importDrawerAction, exportDrawerAction]

    preferredRepresentation: fullRepresentation
    fullRepresentation: Display {
        id: drawerDisplay
        anchors.fill: parent
    }
}

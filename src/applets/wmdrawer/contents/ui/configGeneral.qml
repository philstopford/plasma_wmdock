// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents

/**
 * WMDrawer standalone configuration page.
 *
 * Used when the applet is placed directly on a panel/desktop rather
 * than embedded inside WMDock.  Provides fields for the drawer icon,
 * label and the list of launchers stored as a JSON string.
 */
Kirigami.ScrollablePage {
    id: configPage

    property alias cfg_drawerIcon:    drawerIconField.text
    property alias cfg_drawerLabel:   drawerLabelField.text
    property string cfg_launchersJson: "[]"

    // Internal editable list populated from cfg_launchersJson
    property var editingLaunchers: []

    Component.onCompleted: reloadFromJson()

    function reloadFromJson() {
        try {
            editingLaunchers = JSON.parse(cfg_launchersJson)
        } catch(e) {
            editingLaunchers = []
        }
        launcherModel.reload()
    }

    function saveToJson() {
        cfg_launchersJson = JSON.stringify(editingLaunchers)
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

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

        PlasmaComponents.Label {
            text: i18n("Launchers:")
            font.bold: true
        }

        ListView {
            id: launcherListView
            Layout.fillWidth: true
            implicitHeight: contentHeight
            clip: true
            model: ListModel { id: launcherModel }

            function reload() {
                launcherModel.clear()
                for (var i = 0; i < configPage.editingLaunchers.length; i++) {
                    var item = configPage.editingLaunchers[i]
                    launcherModel.append({
                        cmd: item.command || "",
                        ico: item.icon    || "",
                        lbl: item.label   || ""
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
                    onClicked: entryEditDialog.openFor(index)
                }
                QQC2.ToolButton {
                    icon.name: "list-remove"
                    onClicked: {
                        configPage.editingLaunchers.splice(index, 1)
                        launcherListView.reload()
                        configPage.saveToJson()
                    }
                }
            }
        }

        QQC2.Button {
            text: i18n("Add Launcher…")
            icon.name: "list-add"
            onClicked: entryEditDialog.openFor(-1)
        }
    }

    // Edit/add a single launcher entry
    QQC2.Dialog {
        id: entryEditDialog
        title: i18n("Edit Launcher")
        modal: true
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: 320

        property int editIndex: -1

        function openFor(idx) {
            editIndex = idx
            if (idx >= 0 && idx < configPage.editingLaunchers.length) {
                var item = configPage.editingLaunchers[idx]
                editCmd.text   = item.command || ""
                editIcon.text  = item.icon    || ""
                editLabel.text = item.label   || ""
            } else {
                editCmd.text   = ""
                editIcon.text  = ""
                editLabel.text = ""
            }
            open()
        }

        contentItem: Kirigami.FormLayout {
            QQC2.TextField {
                id: editCmd
                Kirigami.FormData.label: i18n("Command:")
                placeholderText: "konsole"
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Icon name:")
                spacing: Kirigami.Units.smallSpacing
                QQC2.TextField {
                    id: editIcon
                    Layout.fillWidth: true
                    placeholderText: "utilities-terminal"
                }
                Kirigami.Icon {
                    source: editIcon.text || "application-x-executable"
                    width:  Kirigami.Units.iconSizes.medium
                    height: Kirigami.Units.iconSizes.medium
                    isMask: false
                }
            }
            QQC2.TextField {
                id: editLabel
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
                command: editCmd.text   || "konsole",
                icon:    editIcon.text  || "application-x-executable",
                label:   editLabel.text || editCmd.text || "Launch"
            }
            if (editIndex >= 0 && editIndex < configPage.editingLaunchers.length) {
                configPage.editingLaunchers[editIndex] = entry
            } else {
                configPage.editingLaunchers.push(entry)
            }
            launcherListView.reload()
            configPage.saveToJson()
        }
    }
}

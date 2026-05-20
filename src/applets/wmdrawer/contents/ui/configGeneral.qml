// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: configPage

    property string cfg_drawerIcon:    ""
    property string cfg_drawerLabel:   ""
    property string cfg_launchersJson: "[]"

    property var editingLaunchers: []
    property int editIndex: -1

    Component.onCompleted: {
        drawerIconField.text  = cfg_drawerIcon
        drawerLabelField.text = cfg_drawerLabel
        reloadFromJson()
    }

    function reloadFromJson() {
        try {
            editingLaunchers = JSON.parse(cfg_launchersJson)
        } catch(e) {
            editingLaunchers = []
        }
        launcherListView.reload()
    }

    function saveToJson() {
        cfg_launchersJson = JSON.stringify(editingLaunchers)
    }

    function startEdit(idx) {
        editIndex = idx
        if (idx >= 0 && idx < editingLaunchers.length) {
            editCmd.text   = editingLaunchers[idx].command || ""
            editIcon.text  = editingLaunchers[idx].icon    || ""
            editLabel.text = editingLaunchers[idx].label   || ""
        } else {
            editCmd.text   = ""
            editIcon.text  = ""
            editLabel.text = ""
        }
    }

    ColumnLayout {
        anchors.left:  parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.TextField {
                id: drawerIconField
                Kirigami.FormData.label: i18n("Drawer icon:")
                placeholderText: "folder"
                onTextChanged: configPage.cfg_drawerIcon = text
            }
            QQC2.TextField {
                id: drawerLabelField
                Kirigami.FormData.label: i18n("Drawer label:")
                placeholderText: "Apps"
                onTextChanged: configPage.cfg_drawerLabel = text
            }
        }

        QQC2.Label {
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

                QQC2.Label {
                    text: model.lbl || model.cmd
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                QQC2.ToolButton {
                    icon.name: "document-edit"
                    onClicked: configPage.startEdit(index)
                }
                QQC2.ToolButton {
                    icon.name: "list-remove"
                    onClicked: {
                        var arr = configPage.editingLaunchers.slice()
                        arr.splice(index, 1)
                        configPage.editingLaunchers = arr
                        configPage.saveToJson()
                        launcherListView.reload()
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        QQC2.Label {
            text: configPage.editIndex >= 0 ? i18n("Edit Launcher:") : i18n("Add Launcher:")
            font.bold: true
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.TextField {
                id: editCmd
                Kirigami.FormData.label: i18n("Command:")
                placeholderText: "konsole"
            }
            QQC2.TextField {
                id: editIcon
                Kirigami.FormData.label: i18n("Icon name:")
                placeholderText: "utilities-terminal"
            }
            QQC2.TextField {
                id: editLabel
                Kirigami.FormData.label: i18n("Label:")
                placeholderText: "Terminal"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: configPage.editIndex >= 0 ? i18n("Update") : i18n("Add")
                icon.name: configPage.editIndex >= 0 ? "document-save" : "list-add"
                onClicked: {
                    var entry = {
                        command: editCmd.text   || "konsole",
                        icon:    editIcon.text  || "application-x-executable",
                        label:   editLabel.text || editCmd.text || "Launch"
                    }
                    var arr = configPage.editingLaunchers.slice()
                    if (configPage.editIndex >= 0 && configPage.editIndex < arr.length) {
                        arr[configPage.editIndex] = entry
                    } else {
                        arr.push(entry)
                    }
                    configPage.editingLaunchers = arr
                    configPage.saveToJson()
                    configPage.editIndex = -1
                    editCmd.text   = ""
                    editIcon.text  = ""
                    editLabel.text = ""
                    launcherListView.reload()
                }
            }

            QQC2.Button {
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                visible: configPage.editIndex >= 0
                onClicked: {
                    configPage.editIndex = -1
                    editCmd.text   = ""
                    editIcon.text  = ""
                    editLabel.text = ""
                }
            }
        }
    }
}

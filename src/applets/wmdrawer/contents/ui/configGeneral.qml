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

    // Which list-item is being edited (-1 = adding new)
    property int editIndex: -1

    // Reactive: re-parses cfg_launchersJson whenever it changes.
    // Using a binding expression (not Component.onCompleted) keeps this in
    // sync with Plasma's setInitialProperties() ordering.
    property var parsedLaunchers: {
        try { return JSON.parse(cfg_launchersJson) } catch(e) { return [] }
    }

    function commitLauncher(idx, cmd, ico, lbl) {
        var arr = parsedLaunchers.slice()
        var entry = { command: cmd, icon: ico, label: lbl }
        if (idx >= 0 && idx < arr.length) arr[idx] = entry
        else arr.push(entry)
        cfg_launchersJson = JSON.stringify(arr)
    }

    function removeLauncher(idx) {
        var arr = parsedLaunchers.slice()
        arr.splice(idx, 1)
        cfg_launchersJson = JSON.stringify(arr)
    }

    function startEdit(idx) {
        editIndex = idx
        var src = (idx >= 0 && idx < parsedLaunchers.length) ? parsedLaunchers[idx] : null
        editCmdInput.inputText   = src ? (src.command || "") : ""
        editIconInput.inputText  = src ? (src.icon    || "") : ""
        editLabelInput.inputText = src ? (src.label   || "") : ""
    }

    // -----------------------------------------------------------------------
    // Helper: styled text-input row (avoids QQC2.TextField which can cause
    // silent config-tab failures in Plasma 6's config-dialog QML context).
    // -----------------------------------------------------------------------
    component LabelledInput: Rectangle {
        id: wrapper
        property alias inputText: ti.text
        property string placeholder: ""
        implicitWidth: 200
        implicitHeight: Kirigami.Units.gridUnit * 2
        color:  Kirigami.Theme.backgroundColor
        border.color: ti.activeFocus
                      ? Kirigami.Theme.highlightColor
                      : Kirigami.Theme.disabledTextColor
        border.width: 1
        radius: 3

        Text {
            anchors { fill: parent; margins: 4 }
            text: wrapper.placeholder
            color: Kirigami.Theme.disabledTextColor
            visible: ti.text.length === 0
            verticalAlignment: Text.AlignVCenter
        }

        TextInput {
            id: ti
            anchors { fill: parent; margins: 4 }
            color: Kirigami.Theme.textColor
            selectedTextColor: Kirigami.Theme.highlightedTextColor
            selectionColor:    Kirigami.Theme.highlightColor
            selectByMouse:     true
            verticalAlignment: TextInput.AlignVCenter
        }
    }

    // -----------------------------------------------------------------------
    // Layout
    // -----------------------------------------------------------------------
    ColumnLayout {
        anchors.left:  parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            LabelledInput {
                id: drawerIconInput
                Kirigami.FormData.label: i18n("Drawer icon:")
                placeholder: "folder"
                inputText: configPage.cfg_drawerIcon
                onInputTextChanged: configPage.cfg_drawerIcon = inputText
            }

            LabelledInput {
                id: drawerLabelInput
                Kirigami.FormData.label: i18n("Drawer label:")
                placeholder: "Apps"
                inputText: configPage.cfg_drawerLabel
                onInputTextChanged: configPage.cfg_drawerLabel = inputText
            }
        }

        QQC2.Label {
            text: i18n("Launchers:")
            font.bold: true
        }

        ListView {
            id: launcherListView
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            clip: true
            model: configPage.parsedLaunchers

            ScrollBar.vertical: QQC2.ScrollBar {}

            delegate: RowLayout {
                width: ListView.view.width
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: modelData.label || modelData.command
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                QQC2.ToolButton {
                    icon.name: "document-edit"
                    onClicked: configPage.startEdit(index)
                }
                QQC2.ToolButton {
                    icon.name: "list-remove"
                    onClicked: configPage.removeLauncher(index)
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

            LabelledInput {
                id: editCmdInput
                Kirigami.FormData.label: i18n("Command:")
                placeholder: "konsole"
            }
            LabelledInput {
                id: editIconInput
                Kirigami.FormData.label: i18n("Icon name:")
                placeholder: "utilities-terminal"
            }
            LabelledInput {
                id: editLabelInput
                Kirigami.FormData.label: i18n("Label:")
                placeholder: "Terminal"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: configPage.editIndex >= 0 ? i18n("Update") : i18n("Add")
                icon.name: configPage.editIndex >= 0 ? "document-save" : "list-add"
                onClicked: {
                    var cmd = editCmdInput.inputText   || "konsole"
                    var ico = editIconInput.inputText  || "application-x-executable"
                    var lbl = editLabelInput.inputText || editCmdInput.inputText || "Launch"
                    configPage.commitLauncher(configPage.editIndex, cmd, ico, lbl)
                    configPage.editIndex = -1
                    editCmdInput.inputText   = ""
                    editIconInput.inputText  = ""
                    editLabelInput.inputText = ""
                }
            }

            QQC2.Button {
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                visible: configPage.editIndex >= 0
                onClicked: {
                    configPage.editIndex = -1
                    editCmdInput.inputText   = ""
                    editIconInput.inputText  = ""
                    editLabelInput.inputText = ""
                }
            }
        }
    }
}

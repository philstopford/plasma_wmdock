// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: configPage
    implicitHeight: mainLayout.implicitHeight

    property string cfg_drawerIcon:    ""
    property string cfg_drawerLabel:   ""
    property string cfg_launchersJson: "[]"

    property int editIndex: -1

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
        editCmdInput.text   = src ? (src.command || "") : ""
        editIconInput.text  = src ? (src.icon    || "") : ""
        editLabelInput.text = src ? (src.label   || "") : ""
    }

    // -----------------------------------------------------------------------
    // Layout
    // -----------------------------------------------------------------------
    ColumnLayout {
        id: mainLayout
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            // Drawer icon – plain Rectangle+TextInput avoids QQC2.TextField
            // which silently drops the config tab in Plasma 6's config context.
            Rectangle {
                Kirigami.FormData.label: i18n("Drawer icon:")
                implicitWidth:  200
                implicitHeight: Kirigami.Units.gridUnit * 2
                color:        Kirigami.Theme.backgroundColor
                border.color: drawerIconInput.activeFocus ? Kirigami.Theme.highlightColor
                                                          : Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: 3
                Text {
                    anchors { fill: parent; margins: 4 }
                    text:  "folder"
                    color: Kirigami.Theme.disabledTextColor
                    visible: drawerIconInput.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                }
                TextInput {
                    id: drawerIconInput
                    anchors { fill: parent; margins: 4 }
                    color:             Kirigami.Theme.textColor
                    selectedTextColor: Kirigami.Theme.highlightedTextColor
                    selectionColor:    Kirigami.Theme.highlightColor
                    selectByMouse:     true
                    verticalAlignment: TextInput.AlignVCenter
                    Component.onCompleted: text = configPage.cfg_drawerIcon
                    onTextChanged: configPage.cfg_drawerIcon = text
                }
            }

            // Drawer label
            Rectangle {
                Kirigami.FormData.label: i18n("Drawer label:")
                implicitWidth:  200
                implicitHeight: Kirigami.Units.gridUnit * 2
                color:        Kirigami.Theme.backgroundColor
                border.color: drawerLabelInput.activeFocus ? Kirigami.Theme.highlightColor
                                                           : Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: 3
                Text {
                    anchors { fill: parent; margins: 4 }
                    text:  "Apps"
                    color: Kirigami.Theme.disabledTextColor
                    visible: drawerLabelInput.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                }
                TextInput {
                    id: drawerLabelInput
                    anchors { fill: parent; margins: 4 }
                    color:             Kirigami.Theme.textColor
                    selectedTextColor: Kirigami.Theme.highlightedTextColor
                    selectionColor:    Kirigami.Theme.highlightColor
                    selectByMouse:     true
                    verticalAlignment: TextInput.AlignVCenter
                    Component.onCompleted: text = configPage.cfg_drawerLabel
                    onTextChanged: configPage.cfg_drawerLabel = text
                }
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

            // Command (edit form)
            Rectangle {
                Kirigami.FormData.label: i18n("Command:")
                implicitWidth:  200
                implicitHeight: Kirigami.Units.gridUnit * 2
                color:        Kirigami.Theme.backgroundColor
                border.color: editCmdInput.activeFocus ? Kirigami.Theme.highlightColor
                                                       : Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: 3
                Text {
                    anchors { fill: parent; margins: 4 }
                    text:  "konsole"
                    color: Kirigami.Theme.disabledTextColor
                    visible: editCmdInput.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                }
                TextInput {
                    id: editCmdInput
                    anchors { fill: parent; margins: 4 }
                    color:             Kirigami.Theme.textColor
                    selectedTextColor: Kirigami.Theme.highlightedTextColor
                    selectionColor:    Kirigami.Theme.highlightColor
                    selectByMouse:     true
                    verticalAlignment: TextInput.AlignVCenter
                }
            }

            // Icon name (edit form)
            Rectangle {
                Kirigami.FormData.label: i18n("Icon name:")
                implicitWidth:  200
                implicitHeight: Kirigami.Units.gridUnit * 2
                color:        Kirigami.Theme.backgroundColor
                border.color: editIconInput.activeFocus ? Kirigami.Theme.highlightColor
                                                        : Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: 3
                Text {
                    anchors { fill: parent; margins: 4 }
                    text:  "utilities-terminal"
                    color: Kirigami.Theme.disabledTextColor
                    visible: editIconInput.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                }
                TextInput {
                    id: editIconInput
                    anchors { fill: parent; margins: 4 }
                    color:             Kirigami.Theme.textColor
                    selectedTextColor: Kirigami.Theme.highlightedTextColor
                    selectionColor:    Kirigami.Theme.highlightColor
                    selectByMouse:     true
                    verticalAlignment: TextInput.AlignVCenter
                }
            }

            // Label (edit form)
            Rectangle {
                Kirigami.FormData.label: i18n("Label:")
                implicitWidth:  200
                implicitHeight: Kirigami.Units.gridUnit * 2
                color:        Kirigami.Theme.backgroundColor
                border.color: editLabelInput.activeFocus ? Kirigami.Theme.highlightColor
                                                         : Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: 3
                Text {
                    anchors { fill: parent; margins: 4 }
                    text:  "Terminal"
                    color: Kirigami.Theme.disabledTextColor
                    visible: editLabelInput.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                }
                TextInput {
                    id: editLabelInput
                    anchors { fill: parent; margins: 4 }
                    color:             Kirigami.Theme.textColor
                    selectedTextColor: Kirigami.Theme.highlightedTextColor
                    selectionColor:    Kirigami.Theme.highlightColor
                    selectByMouse:     true
                    verticalAlignment: TextInput.AlignVCenter
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: configPage.editIndex >= 0 ? i18n("Update") : i18n("Add")
                icon.name: configPage.editIndex >= 0 ? "document-save" : "list-add"
                onClicked: {
                    var cmd = editCmdInput.text   || "konsole"
                    var ico = editIconInput.text  || "application-x-executable"
                    var lbl = editLabelInput.text || editCmdInput.text || "Launch"
                    configPage.commitLauncher(configPage.editIndex, cmd, ico, lbl)
                    configPage.editIndex = -1
                    editCmdInput.text   = ""
                    editIconInput.text  = ""
                    editLabelInput.text = ""
                }
            }

            QQC2.Button {
                text: i18n("Cancel")
                icon.name: "dialog-cancel"
                visible: configPage.editIndex >= 0
                onClicked: {
                    configPage.editIndex = -1
                    editCmdInput.text   = ""
                    editIconInput.text  = ""
                    editLabelInput.text = ""
                }
            }
        }
    }
}

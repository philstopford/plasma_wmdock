// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Root must be plain Item so Plasma can embed it in its own config dialog.
// Use Kirigami.FormLayout anchored directly inside Item (no ColumnLayout wrapper)
// — this matches the proven wmlauncher pattern that works in Plasma 6.
Item {
    id: configPage

    property string cfg_drawerIcon:    ""
    property string cfg_drawerLabel:   ""
    property string cfg_launchersJson: ""

    property int editIndex: -1

    property var parsedLaunchers: {
        var raw = cfg_launchersJson
        if (!raw || raw.length === 0) return []
        try { return JSON.parse(raw) } catch(e) { return [] }
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
    // Proven Plasma 6 pattern: Kirigami.FormLayout with anchors.left/right
    // anchored directly to the root Item (same as working wmlauncher).
    // -----------------------------------------------------------------------
    Kirigami.FormLayout {
        id: topForm
        anchors.left:  parent.left
        anchors.right: parent.right

        // Plain Rectangle+TextInput avoids QQC2.TextField which silently
        // drops the config tab in Plasma 6's config-dialog context.
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

    // -----------------------------------------------------------------------
    // Launcher management section — anchored below the FormLayout.
    // Uses Column (not ColumnLayout) so childrenRect.height is always valid.
    // -----------------------------------------------------------------------
    Column {
        id: launcherSection
        anchors.top:   topForm.bottom
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.topMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Separator { width: parent.width }

        QQC2.Label {
            text: i18n("Launchers:")
            font.bold: true
        }

        ListView {
            id: launcherListView
            width: parent.width
            height: 180
            clip: true
            model: configPage.parsedLaunchers

            delegate: Item {
                width: ListView.view.width
                height: Kirigami.Units.gridUnit * 2

                RowLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: modelData.label || modelData.command
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
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
        }

        Kirigami.Separator { width: parent.width }

        QQC2.Label {
            text: configPage.editIndex >= 0 ? i18n("Edit Launcher:") : i18n("Add Launcher:")
            font.bold: true
        }

        // Command
        Row {
            width: parent.width
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                text: i18n("Command:")
                anchors.verticalCenter: parent.verticalCenter
                width: 90
            }
            Rectangle {
                width: parent.width - 90 - Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 2
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
        }

        // Icon name
        Row {
            width: parent.width
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                text: i18n("Icon name:")
                anchors.verticalCenter: parent.verticalCenter
                width: 90
            }
            Rectangle {
                width: parent.width - 90 - Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 2
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
        }

        // Label
        Row {
            width: parent.width
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                text: i18n("Label:")
                anchors.verticalCenter: parent.verticalCenter
                width: 90
            }
            Rectangle {
                width: parent.width - 90 - Kirigami.Units.smallSpacing
                height: Kirigami.Units.gridUnit * 2
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

        // Action buttons
        Row {
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

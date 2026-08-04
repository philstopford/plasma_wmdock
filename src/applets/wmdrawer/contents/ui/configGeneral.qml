// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Root must be plain Item so Plasma can embed it in its own config dialog.
// All content lives inside a single Kirigami.FormLayout anchored left/right
// directly to the root Item — this is the only proven-to-work pattern in
// Plasma 6 (matching wmlauncher/wmnet). Additional sections use
// Kirigami.FormData.isSection separators rather than extra children outside
// the FormLayout.
Item {
    id: configPage

    property string cfg_drawerIcon:          ""
    property string cfg_drawerIconDefault:   "folder"
    property string cfg_drawerLabel:         ""
    property string cfg_drawerLabelDefault:  "Apps"
    property string cfg_launchersJson:       ""
    property string cfg_launchersJsonDefault: "[]"
    property string cfg_openEffect:          ""
    property string cfg_openEffectDefault:   "slide"
    property string cfg_drawerClickMode:     ""
    property string cfg_drawerClickModeDefault: "open"
    property string title:                   ""

    property int editIndex: -1

    // Simple property — updated imperatively to avoid computed-binding with
    // return statements which can confuse the QML parser in some Qt 6 builds.
    property var parsedLaunchers: []

    function parseLaunchers() {
        try {
            parsedLaunchers = cfg_launchersJson ? JSON.parse(cfg_launchersJson) : []
        } catch(e) {
            parsedLaunchers = []
        }
    }

    // Initialise on first load (Plasma may have set cfg_launchersJson via
    // setInitialProperties() before the change signal was connected).
    Component.onCompleted: parseLaunchers()
    onCfg_launchersJsonChanged: parseLaunchers()

    function commitLauncher(idx, cmd, ico, lbl, desc, gpu) {
        var arr = parsedLaunchers.slice()
        var entry = { command: cmd, icon: ico, label: lbl, description: desc,
                      gpuPreference: gpu }
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
        editDescriptionInput.text = src ? (src.description || "") : ""
        var gpu = src ? (src.gpuPreference || "default") : "default"
        for (var i = 0; i < editGpuInput.model.length; ++i) {
            if (editGpuInput.model[i].value === gpu) {
                editGpuInput.currentIndex = i
                break
            }
        }
    }

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        // ── Drawer appearance ───────────────────────────────────────────────

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

        // ── Open effect ─────────────────────────────────────────────────────

        QQC2.ComboBox {
            id: openEffectCombo
            Kirigami.FormData.label: i18n("Open effect:")
            model: [
                { text: i18n("Slide"),   value: "slide"   },
                { text: i18n("Fade"),    value: "fade"    },
                { text: i18n("Instant"), value: "instant" }
            ]
            textRole: "text"
            Component.onCompleted: {
                var v = configPage.cfg_openEffect || "slide"
                for (var i = 0; i < model.length; i++) {
                    if (model[i].value === v) { currentIndex = i; break }
                }
            }
            onActivated: configPage.cfg_openEffect = model[currentIndex].value
        }

        QQC2.ComboBox {
            id: drawerClickModeCombo
            Kirigami.FormData.label: i18n("Trigger click:")
            model: [
                { text: i18n("Open drawer"),   value: "open"   },
                { text: i18n("Toggle drawer"), value: "toggle" }
            ]
            textRole: "text"
            Component.onCompleted: {
                var v = configPage.cfg_drawerClickMode || "open"
                for (var i = 0; i < model.length; i++) {
                    if (model[i].value === v) { currentIndex = i; break }
                }
            }
            onActivated: configPage.cfg_drawerClickMode = model[currentIndex].value
        }

        // ── Launcher list ───────────────────────────────────────────────────

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Launchers")
        }

        // ListView lives as a regular FormLayout child; explicit implicitWidth/
        // Height are required so FormLayout allocates the right amount of space.
        ListView {
            id: launcherListView
            Kirigami.FormData.label: ""
            implicitWidth:  Kirigami.Units.gridUnit * 20
            implicitHeight: Kirigami.Units.gridUnit * 8
            clip: true
            model: configPage.parsedLaunchers

            delegate: Item {
                width: ListView.view.width
                height: Kirigami.Units.gridUnit * 2

                RowLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: modelData.label || modelData.command || ""
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

        // ── Add / Edit launcher ─────────────────────────────────────────────

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: configPage.editIndex >= 0
                                         ? i18n("Edit Launcher")
                                         : i18n("Add Launcher")
        }

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

        Rectangle {
            Kirigami.FormData.label: i18n("Description:")
            implicitWidth: 200
            implicitHeight: Kirigami.Units.gridUnit * 2
            color: Kirigami.Theme.backgroundColor
            border.color: editDescriptionInput.activeFocus ? Kirigami.Theme.highlightColor
                                                           : Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: 3
            TextInput {
                id: editDescriptionInput
                anchors { fill: parent; margins: 4 }
                color: Kirigami.Theme.textColor
                selectedTextColor: Kirigami.Theme.highlightedTextColor
                selectionColor: Kirigami.Theme.highlightColor
                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter
            }
        }

        QQC2.ComboBox {
            id: editGpuInput
            Kirigami.FormData.label: i18n("Graphics processor:")
            textRole: "text"
            model: [
                { text: i18n("System default"), value: "default" },
                { text: i18n("Integrated GPU"), value: "integrated" },
                { text: i18n("Discrete GPU (PRIME)"), value: "discrete" }
            ]
        }

        Row {
            Kirigami.FormData.label: ""
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: configPage.editIndex >= 0 ? i18n("Update") : i18n("Add")
                icon.name: configPage.editIndex >= 0 ? "document-save" : "list-add"
                onClicked: {
                    var cmd = editCmdInput.text   || "konsole"
                    var ico = editIconInput.text  || "application-x-executable"
                    var lbl = editLabelInput.text || editCmdInput.text || "Launch"
                    configPage.commitLauncher(configPage.editIndex, cmd, ico, lbl,
                                              editDescriptionInput.text,
                                              editGpuInput.model[editGpuInput.currentIndex].value)
                    configPage.editIndex = -1
                    editCmdInput.text   = ""
                    editIconInput.text  = ""
                    editLabelInput.text = ""
                    editDescriptionInput.text = ""
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
                    editDescriptionInput.text = ""
                }
            }
        }
    }
}

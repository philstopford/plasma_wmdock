// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string cfg_command:   ""
    property string cfg_icon:      ""
    property string cfg_label:     ""
    property bool   cfg_showLabel: false

    // Helper: a labelled text-input row that avoids QQC2.TextField (which
    // can silently drop the config tab in Plasma 6's config-dialog context).
    component LabelledInput: Rectangle {
        id: inputWrapper
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
            text: inputWrapper.placeholder
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

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        LabelledInput {
            Kirigami.FormData.label: i18n("Command:")
            placeholder: "konsole"
            inputText: page.cfg_command
            onInputTextChanged: page.cfg_command = inputText
        }

        LabelledInput {
            Kirigami.FormData.label: i18n("Icon name:")
            placeholder: "utilities-terminal"
            inputText: page.cfg_icon
            onInputTextChanged: page.cfg_icon = inputText
        }

        LabelledInput {
            Kirigami.FormData.label: i18n("Label:")
            placeholder: "Launch"
            inputText: page.cfg_label
            onInputTextChanged: page.cfg_label = inputText
        }

        QQC2.CheckBox {
            id: showLabelCheck
            Kirigami.FormData.label: i18n("Show label:")
            checked: page.cfg_showLabel
            onCheckedChanged: page.cfg_showLabel = checked
        }
    }
}

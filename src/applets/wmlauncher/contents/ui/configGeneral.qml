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

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        // Command – plain Rectangle+TextInput avoids QQC2.TextField which
        // silently drops the config tab in Plasma 6's config-dialog context.
        Rectangle {
            Kirigami.FormData.label: i18n("Command:")
            implicitWidth:  200
            implicitHeight: Kirigami.Units.gridUnit * 2
            color:        Kirigami.Theme.backgroundColor
            border.color: cmdInput.activeFocus ? Kirigami.Theme.highlightColor
                                               : Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: 3
            Text {
                anchors { fill: parent; margins: 4 }
                text:  "konsole"
                color: Kirigami.Theme.disabledTextColor
                visible: cmdInput.text.length === 0
                verticalAlignment: Text.AlignVCenter
            }
            TextInput {
                id: cmdInput
                anchors { fill: parent; margins: 4 }
                color:             Kirigami.Theme.textColor
                selectedTextColor: Kirigami.Theme.highlightedTextColor
                selectionColor:    Kirigami.Theme.highlightColor
                selectByMouse:     true
                verticalAlignment: TextInput.AlignVCenter
                Component.onCompleted: text = page.cfg_command
                onTextChanged: page.cfg_command = text
            }
        }

        // Icon name
        Rectangle {
            Kirigami.FormData.label: i18n("Icon name:")
            implicitWidth:  200
            implicitHeight: Kirigami.Units.gridUnit * 2
            color:        Kirigami.Theme.backgroundColor
            border.color: iconInput.activeFocus ? Kirigami.Theme.highlightColor
                                                : Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: 3
            Text {
                anchors { fill: parent; margins: 4 }
                text:  "utilities-terminal"
                color: Kirigami.Theme.disabledTextColor
                visible: iconInput.text.length === 0
                verticalAlignment: Text.AlignVCenter
            }
            TextInput {
                id: iconInput
                anchors { fill: parent; margins: 4 }
                color:             Kirigami.Theme.textColor
                selectedTextColor: Kirigami.Theme.highlightedTextColor
                selectionColor:    Kirigami.Theme.highlightColor
                selectByMouse:     true
                verticalAlignment: TextInput.AlignVCenter
                Component.onCompleted: text = page.cfg_icon
                onTextChanged: page.cfg_icon = text
            }
        }

        // Label
        Rectangle {
            Kirigami.FormData.label: i18n("Label:")
            implicitWidth:  200
            implicitHeight: Kirigami.Units.gridUnit * 2
            color:        Kirigami.Theme.backgroundColor
            border.color: labelInput.activeFocus ? Kirigami.Theme.highlightColor
                                                 : Kirigami.Theme.disabledTextColor
            border.width: 1
            radius: 3
            Text {
                anchors { fill: parent; margins: 4 }
                text:  "Launch"
                color: Kirigami.Theme.disabledTextColor
                visible: labelInput.text.length === 0
                verticalAlignment: Text.AlignVCenter
            }
            TextInput {
                id: labelInput
                anchors { fill: parent; margins: 4 }
                color:             Kirigami.Theme.textColor
                selectedTextColor: Kirigami.Theme.highlightedTextColor
                selectionColor:    Kirigami.Theme.highlightColor
                selectByMouse:     true
                verticalAlignment: TextInput.AlignVCenter
                Component.onCompleted: text = page.cfg_label
                onTextChanged: page.cfg_label = text
            }
        }

        QQC2.CheckBox {
            id: showLabelCheck
            Kirigami.FormData.label: i18n("Show label:")
            checked: page.cfg_showLabel
            onCheckedChanged: page.cfg_showLabel = checked
        }
    }
}

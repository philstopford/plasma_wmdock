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

        QQC2.TextField {
            id: commandField
            Kirigami.FormData.label: i18n("Command:")
            placeholderText: "konsole"
            Component.onCompleted: text = page.cfg_command
            onTextChanged: page.cfg_command = text
        }

        QQC2.TextField {
            id: iconField
            Kirigami.FormData.label: i18n("Icon name:")
            placeholderText: "utilities-terminal"
            Component.onCompleted: text = page.cfg_icon
            onTextChanged: page.cfg_icon = text
        }

        QQC2.TextField {
            id: labelField
            Kirigami.FormData.label: i18n("Label:")
            placeholderText: "Launch"
            Component.onCompleted: text = page.cfg_label
            onTextChanged: page.cfg_label = text
        }

        QQC2.CheckBox {
            id: showLabelCheck
            Kirigami.FormData.label: i18n("Show label:")
            checked: page.cfg_showLabel
            onCheckedChanged: page.cfg_showLabel = checked
        }
    }
}

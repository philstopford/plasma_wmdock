// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/**
 * WMLauncher configuration page.
 *
 * Exposes cfg_* aliases that Plasma automatically reads/writes to the
 * applet's KConfig via the config/main.xml schema.
 */
Kirigami.FormLayout {
    property alias cfg_command:   commandField.text
    property alias cfg_icon:      iconField.text
    property alias cfg_label:     labelField.text
    property alias cfg_showLabel: showLabelCheck.checked

    QQC2.TextField {
        id: commandField
        Kirigami.FormData.label: i18n("Command:")
        placeholderText: "konsole"
    }

    QQC2.TextField {
        id: iconField
        Kirigami.FormData.label: i18n("Icon name:")
        placeholderText: "utilities-terminal"
    }

    QQC2.TextField {
        id: labelField
        Kirigami.FormData.label: i18n("Label:")
        placeholderText: "Launch"
    }

    QQC2.CheckBox {
        id: showLabelCheck
        Kirigami.FormData.label: i18n("Show label:")
    }
}

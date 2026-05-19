// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/**
 * WMLauncher configuration page.
 *
 * Exposes explicit cfg_* properties that Plasma reads/writes to the
 * applet's KConfig via the config/main.xml schema.
 * Property aliases are avoided because Plasma sets initial properties
 * before children are fully constructed, which can cause alias
 * resolution to fail silently and the tab to disappear.
 */
Kirigami.FormLayout {
    id: page

    property string cfg_command:   ""
    property string cfg_icon:      ""
    property string cfg_label:     ""
    property bool   cfg_showLabel: true

    onCfg_commandChanged:   commandField.text      = cfg_command
    onCfg_iconChanged:      iconField.text         = cfg_icon
    onCfg_labelChanged:     labelField.text        = cfg_label
    onCfg_showLabelChanged: showLabelCheck.checked = cfg_showLabel

    QQC2.TextField {
        id: commandField
        Kirigami.FormData.label: i18n("Command:")
        placeholderText: "konsole"
        onTextChanged: page.cfg_command = text
    }

    // Icon row: text field + live preview
    RowLayout {
        Kirigami.FormData.label: i18n("Icon name:")
        spacing: Kirigami.Units.smallSpacing

        QQC2.TextField {
            id: iconField
            Layout.fillWidth: true
            placeholderText: "utilities-terminal"
            onTextChanged: page.cfg_icon = text
        }

        Kirigami.Icon {
            source: iconField.text || "utilities-terminal"
            width:  Kirigami.Units.iconSizes.medium
            height: Kirigami.Units.iconSizes.medium
            isMask: false
        }
    }

    QQC2.TextField {
        id: labelField
        Kirigami.FormData.label: i18n("Label:")
        placeholderText: "Launch"
        onTextChanged: page.cfg_label = text
    }

    QQC2.CheckBox {
        id: showLabelCheck
        Kirigami.FormData.label: i18n("Show label:")
        onCheckedChanged: page.cfg_showLabel = checked
    }
}

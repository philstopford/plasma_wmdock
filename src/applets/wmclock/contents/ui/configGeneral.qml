// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property bool cfg_use24Hour:   false
    property bool cfg_showSeconds: false
    property bool cfg_showDate:    false

    onCfg_use24HourChanged:   use24HourCheck.checked   = cfg_use24Hour
    onCfg_showSecondsChanged: showSecondsCheck.checked = cfg_showSeconds
    onCfg_showDateChanged:    showDateCheck.checked     = cfg_showDate

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: use24HourCheck
            Kirigami.FormData.label: i18n("24-hour digital display:")
            onCheckedChanged: page.cfg_use24Hour = checked
        }

        QQC2.CheckBox {
            id: showSecondsCheck
            Kirigami.FormData.label: i18n("Show seconds hand:")
            onCheckedChanged: page.cfg_showSeconds = checked
        }

        QQC2.CheckBox {
            id: showDateCheck
            Kirigami.FormData.label: i18n("Show date line:")
            onCheckedChanged: page.cfg_showDate = checked
        }
    }
}

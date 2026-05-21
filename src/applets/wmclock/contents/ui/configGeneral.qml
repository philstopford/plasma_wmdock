// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property bool cfg_use24Hour:   false
    property bool cfg_showSeconds: false
    property bool cfg_showDate:    false

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: use24HourCheck
            Kirigami.FormData.label: i18n("24-hour digital display:")
            checked: page.cfg_use24Hour
            onCheckedChanged: page.cfg_use24Hour = checked
        }

        QQC2.CheckBox {
            id: showSecondsCheck
            Kirigami.FormData.label: i18n("Show seconds hand:")
            checked: page.cfg_showSeconds
            onCheckedChanged: page.cfg_showSeconds = checked
        }

        QQC2.CheckBox {
            id: showDateCheck
            Kirigami.FormData.label: i18n("Show date line:")
            checked: page.cfg_showDate
            onCheckedChanged: page.cfg_showDate = checked
        }
    }
}

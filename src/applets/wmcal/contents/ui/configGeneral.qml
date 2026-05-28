// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string title:                       ""
    property bool   cfg_weekStartsMonday:        false
    property bool   cfg_weekStartsMondayDefault: false

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: mondayCheck
            Kirigami.FormData.label: i18n("Week starts on Monday:")
            checked: page.cfg_weekStartsMonday
            onCheckedChanged: page.cfg_weekStartsMonday = checked
        }
    }
}

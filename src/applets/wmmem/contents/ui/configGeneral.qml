// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string title:               ""
    property bool   cfg_showTitle:       true
    property bool   cfg_showTitleDefault: true

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Show title:")
            checked: page.cfg_showTitle
            onToggled: page.cfg_showTitle = checked
        }
    }
}

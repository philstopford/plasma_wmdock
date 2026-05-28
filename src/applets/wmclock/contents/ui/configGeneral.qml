// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property bool   cfg_use24Hour:   false
    property bool   cfg_showSeconds: false
    property bool   cfg_showDate:    false
    property string cfg_clockStyle:  ""

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.ComboBox {
            id: styleCombo
            Kirigami.FormData.label: i18n("Display style:")
            model: [
                { text: i18n("Analog"),     value: "analog" },
                { text: i18n("Nixie Tube"), value: "nixie"  },
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                const v = page.cfg_clockStyle || "analog"
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === v) { currentIndex = i; return }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_clockStyle = currentValue
        }

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

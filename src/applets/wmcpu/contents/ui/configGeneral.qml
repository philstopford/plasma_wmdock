// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string title:               ""
    property int    cfg_histLen:         0
    property int    cfg_histLenDefault:  50
    property bool   cfg_showTitle:       true
    property bool   cfg_showTitleDefault: true
    property string cfg_loadAction:      ""
    property string cfg_loadActionDefault: "disabled"

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: histLenSpinBox
            Kirigami.FormData.label: i18n("Graph history length (samples):")
            from: 10
            to:   200
            stepSize: 10
            value: page.cfg_histLen
            onValueChanged: page.cfg_histLen = value
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Show title:")
            checked: page.cfg_showTitle
            onToggled: page.cfg_showTitle = checked
        }

        QQC2.ComboBox {
            id: loadActionCombo
            Kirigami.FormData.label: i18n("Load action:")
            model: [
                { text: i18n("Disabled"),                 value: "disabled"    },
                { text: i18n("Mouse wheel toggles slot"), value: "wheelToggle" },
                { text: i18n("Left click opens drawer"),  value: "clickDrawer" },
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                const v = page.cfg_loadAction || "disabled"
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === v) { currentIndex = i; return }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_loadAction = currentValue
        }
    }
}

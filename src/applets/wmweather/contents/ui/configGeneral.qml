// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property real   cfg_latitude:  0
    property real   cfg_longitude: 0
    property string cfg_tempUnit:  ""

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: latField
            Kirigami.FormData.label: i18n("Latitude (°):")
            from:    -90000
            to:       90000
            stepSize: 100
            value: Math.round(page.cfg_latitude * 1000)
            onValueChanged: page.cfg_latitude = value / 1000.0
            textFromValue: function(v) { return (v / 1000.0).toFixed(3) }
            valueFromText: function(t) { return Math.round(parseFloat(t) * 1000) }
        }

        QQC2.SpinBox {
            id: lonField
            Kirigami.FormData.label: i18n("Longitude (°):")
            from:    -180000
            to:       180000
            stepSize: 100
            value: Math.round(page.cfg_longitude * 1000)
            onValueChanged: page.cfg_longitude = value / 1000.0
            textFromValue: function(v) { return (v / 1000.0).toFixed(3) }
            valueFromText: function(t) { return Math.round(parseFloat(t) * 1000) }
        }

        QQC2.ComboBox {
            id: unitCombo
            Kirigami.FormData.label: i18n("Temperature unit:")
            model: [
                { text: i18n("Celsius (°C)"),    value: "celsius"    },
                { text: i18n("Fahrenheit (°F)"), value: "fahrenheit" }
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === page.cfg_tempUnit) {
                        currentIndex = i
                        return
                    }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_tempUnit = currentValue
        }
    }
}

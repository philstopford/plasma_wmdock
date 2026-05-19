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

    onCfg_latitudeChanged:  latField.value  = Math.round(cfg_latitude  * 1000)
    onCfg_longitudeChanged: lonField.value  = Math.round(cfg_longitude * 1000)
    onCfg_tempUnitChanged: {
        for (let i = 0; i < unitCombo.count; ++i) {
            if (unitCombo.model[i].value === cfg_tempUnit) {
                unitCombo.currentIndex = i
                return
            }
        }
        unitCombo.currentIndex = 0
    }

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: latField
            Kirigami.FormData.label: i18n("Latitude (°):")
            from:    -90000
            to:       90000
            stepSize: 100
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
            onActivated: page.cfg_tempUnit = currentValue
        }
    }
}

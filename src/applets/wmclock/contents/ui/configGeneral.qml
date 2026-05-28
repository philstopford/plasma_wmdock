// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string title:                   ""
    property bool   cfg_use24Hour:           false
    property bool   cfg_use24HourDefault:    true
    property bool   cfg_showSeconds:         false
    property bool   cfg_showSecondsDefault:  true
    property bool   cfg_showDate:            false
    property bool   cfg_showDateDefault:     true
    property string cfg_clockStyle:              ""
    property string cfg_clockStyleDefault:       "analog"
    property string cfg_nixieTransition:         ""
    property string cfg_nixieTransitionDefault:  "slot"
    property string cfg_nixieTubeStyle:          ""
    property string cfg_nixieTubeStyleDefault:   "classic"
    property real   cfg_nixieGlowRadius:         0
    property real   cfg_nixieGlowRadiusDefault:  0.35

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

        QQC2.ComboBox {
            id: nixieTransitionCombo
            visible: page.cfg_clockStyle === "nixie"
            Kirigami.FormData.label: i18n("Digit transition:")
            model: [
                { text: i18n("Slot-machine (spin)"),     value: "slot"    },
                { text: i18n("Cascade left-to-right"),   value: "cascade" },
                { text: i18n("Count up to value"),       value: "count"   },
                { text: i18n("Instant (no animation)"),  value: "none"    },
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                const v = page.cfg_nixieTransition || "slot"
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === v) { currentIndex = i; return }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_nixieTransition = currentValue
        }

        QQC2.ComboBox {
            id: nixieTubeStyleCombo
            visible: page.cfg_clockStyle === "nixie"
            Kirigami.FormData.label: i18n("Tube style:")
            model: [
                { text: i18n("Classic (rectangular)"),  value: "classic" },
                { text: i18n("Barrel (IN-14 bulge)"),   value: "barrel"  },
                { text: i18n("Slim (IN-18 narrow)"),    value: "slim"    },
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                const v = page.cfg_nixieTubeStyle || "classic"
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === v) { currentIndex = i; return }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_nixieTubeStyle = currentValue
        }

        QQC2.Label {
            visible: page.cfg_clockStyle === "nixie"
            Kirigami.FormData.label: i18n("Discharge glow radius:")
            text: Math.round(glowSlider.value * 100) + "% of tube radius"
        }

        QQC2.Slider {
            id: glowSlider
            visible: page.cfg_clockStyle === "nixie"
            from:     0.10
            to:       1.00
            stepSize: 0.05
            value:    page.cfg_nixieGlowRadius || 0.35
            onMoved: page.cfg_nixieGlowRadius = value
        }
    }
}

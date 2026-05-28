// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string title:                  ""
    property string cfg_blobColor:          ""
    property string cfg_blobColorDefault:   "red"
    property int    cfg_blobCount:          0
    property int    cfg_blobCountDefault:   5
    property int    cfg_resolution:         1
    property int    cfg_resolutionDefault:  1

    // Physics parameters (Double in kcfg → real in QML)
    property real   cfg_gravity:            0.08
    property real   cfg_gravityDefault:     0.08
    property real   cfg_buoyancy:           0.18
    property real   cfg_buoyancyDefault:    0.18
    property real   cfg_drag:              0.91
    property real   cfg_dragDefault:       0.91
    property real   cfg_baseHeat:           0.40
    property real   cfg_baseHeatDefault:    0.40
    property real   cfg_heatRate:           0.030
    property real   cfg_heatRateDefault:    0.030
    property real   cfg_coolRate:           0.010
    property real   cfg_coolRateDefault:    0.010
    property real   cfg_heatZoneY:          0.60
    property real   cfg_heatZoneYDefault:   0.60

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        // ── Appearance ────────────────────────────────────────────────────────
        QQC2.ComboBox {
            id: colorCombo
            Kirigami.FormData.label: i18n("Blob color:")
            model: [
                { text: i18n("Red/Orange"),  value: "red"    },
                { text: i18n("Blue/Cyan"),   value: "blue"   },
                { text: i18n("Green"),       value: "green"  },
                { text: i18n("Purple"),      value: "purple" },
                { text: i18n("Rainbow"),     value: "rainbow"},
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === page.cfg_blobColor) {
                        currentIndex = i; return
                    }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_blobColor = currentValue
        }

        QQC2.SpinBox {
            id: blobSpinBox
            Kirigami.FormData.label: i18n("Number of blobs:")
            from: 2; to: 10; stepSize: 1
            value: page.cfg_blobCount
            onValueChanged: page.cfg_blobCount = value
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Resolution:")
            spacing: 8

            QQC2.Slider {
                id: resolutionSlider
                Layout.preferredWidth: 140
                from: 1; to: 4; stepSize: 1
                value: page.cfg_resolution
                onMoved: page.cfg_resolution = Math.round(value)
            }

            Text {
                text: i18n("%1×", Math.round(resolutionSlider.value))
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 28
            }
        }

        // ── Physics parameters ────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Physics Parameters") }

        RowLayout {
            Kirigami.FormData.label: i18n("Gravity:")
            spacing: 8
            QQC2.Slider {
                id: gravitySlider
                Layout.preferredWidth: 140
                from: 0.01; to: 0.30; stepSize: 0.01
                value: page.cfg_gravity
                onMoved: page.cfg_gravity = value
            }
            Text {
                text: gravitySlider.value.toFixed(2)
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 36
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Buoyancy:")
            spacing: 8
            QQC2.Slider {
                id: buoyancySlider
                Layout.preferredWidth: 140
                from: 0.05; to: 0.50; stepSize: 0.01
                value: page.cfg_buoyancy
                onMoved: page.cfg_buoyancy = value
            }
            Text {
                text: buoyancySlider.value.toFixed(2)
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 36
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Drag (lower = more viscous):")
            spacing: 8
            QQC2.Slider {
                id: dragSlider
                Layout.preferredWidth: 140
                from: 0.70; to: 0.99; stepSize: 0.01
                value: page.cfg_drag
                onMoved: page.cfg_drag = value
            }
            Text {
                text: dragSlider.value.toFixed(2)
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 36
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Base heat (0 = CPU-only, 0.4 = always active):")
            spacing: 8
            QQC2.Slider {
                id: baseHeatSlider
                Layout.preferredWidth: 140
                from: 0.00; to: 0.80; stepSize: 0.05
                value: page.cfg_baseHeat
                onMoved: page.cfg_baseHeat = value
            }
            Text {
                text: baseHeatSlider.value.toFixed(2)
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 36
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Heat rate (temp/tick absorbed):")
            spacing: 8
            QQC2.Slider {
                id: heatRateSlider
                Layout.preferredWidth: 140
                from: 0.005; to: 0.100; stepSize: 0.005
                value: page.cfg_heatRate
                onMoved: page.cfg_heatRate = value
            }
            Text {
                text: heatRateSlider.value.toFixed(3)
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 44
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Cool rate (temp/tick radiated):")
            spacing: 8
            QQC2.Slider {
                id: coolRateSlider
                Layout.preferredWidth: 140
                from: 0.001; to: 0.050; stepSize: 0.001
                value: page.cfg_coolRate
                onMoved: page.cfg_coolRate = value
            }
            Text {
                text: coolRateSlider.value.toFixed(3)
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 44
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Heat zone size (fraction of height):")
            spacing: 8
            QQC2.Slider {
                id: heatZoneYSlider
                Layout.preferredWidth: 140
                from: 0.30; to: 0.90; stepSize: 0.05
                value: page.cfg_heatZoneY
                onMoved: page.cfg_heatZoneY = value
            }
            Text {
                text: heatZoneYSlider.value.toFixed(2)
                color: Kirigami.Theme.textColor
                Layout.preferredWidth: 36
            }
        }
    }
}

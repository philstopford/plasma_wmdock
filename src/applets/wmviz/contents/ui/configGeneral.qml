// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string cfg_effect:           ""
    property string cfg_colorScheme:      ""
    property bool   cfg_terrainRotate:    false
    property bool   cfg_terrainWireframe: false

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.ComboBox {
            id: effectCombo
            Kirigami.FormData.label: i18n("Visualization effect:")
            model: [
                { text: i18n("Bars"),           value: "bars"     },
                { text: i18n("Scope"),          value: "wave"     },
                { text: i18n("Starfield"),      value: "circles"  },
                { text: i18n("Tunnel"),         value: "plasma"   },
                { text: i18n("Terrain"),        value: "terrain"  },
                { text: i18n("Vortex"),         value: "vortex"   },
                { text: i18n("Warp"),           value: "warp"     },
                { text: i18n("Ripple"),         value: "ripple"   },
                { text: i18n("Kaleidoscope"),   value: "kaleid"   },
                { text: i18n("Nova"),           value: "nova"     },
                { text: i18n("Galaxy"),         value: "galaxy"   },
                { text: i18n("Aurora"),         value: "aurora"   },
                { text: i18n("Mandala"),        value: "mandala"  },
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === page.cfg_effect) {
                        currentIndex = i; return
                    }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_effect = currentValue
        }

        QQC2.ComboBox {
            id: colorCombo
            Kirigami.FormData.label: i18n("Color scheme:")
            model: [
                { text: i18n("Green"),   value: "green"  },
                { text: i18n("Blue"),    value: "blue"   },
                { text: i18n("Amber"),   value: "amber"  },
                { text: i18n("Rainbow"), value: "rainbow"},
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === page.cfg_colorScheme) {
                        currentIndex = i; return
                    }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_colorScheme = currentValue
        }

        // ── Terrain options ──────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Terrain Options") }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Rotate terrain view:")
            checked: page.cfg_terrainRotate
            onToggled: page.cfg_terrainRotate = checked
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Wireframe mode:")
            checked: page.cfg_terrainWireframe
            onToggled: page.cfg_terrainWireframe = checked
        }
    }
}

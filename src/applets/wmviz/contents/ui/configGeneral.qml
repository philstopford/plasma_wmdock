// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string cfg_effect:      ""
    property string cfg_colorScheme: ""

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.ComboBox {
            id: effectCombo
            Kirigami.FormData.label: i18n("Visualization effect:")
            model: [
                { text: i18n("Bars"),       value: "bars"     },
                { text: i18n("Waveform"),   value: "wave"     },
                { text: i18n("Circles"),    value: "circles"  },
                { text: i18n("Plasma"),     value: "plasma"   },
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
    }
}

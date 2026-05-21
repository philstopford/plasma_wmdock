// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string cfg_blobColor: ""
    property int    cfg_speed:      0
    property int    cfg_blobCount:  0

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

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
            id: speedSpinBox
            Kirigami.FormData.label: i18n("Speed (1–5):")
            from: 1; to: 5; stepSize: 1
            value: page.cfg_speed
            onValueChanged: page.cfg_speed = value
        }

        QQC2.SpinBox {
            id: blobSpinBox
            Kirigami.FormData.label: i18n("Number of blobs:")
            from: 2; to: 10; stepSize: 1
            value: page.cfg_blobCount
            onValueChanged: page.cfg_blobCount = value
        }
    }
}

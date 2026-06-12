// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.wmdock 1.0

Item {
    id: page

    property string title:                    ""
    property string cfg_gpu:                  ""
    property string cfg_gpuDefault:           ""
    property int    cfg_cycleInterval:        0
    property int    cfg_cycleIntervalDefault: 4
    property bool   cfg_cycleMode:            true
    property bool   cfg_cycleModeDefault:     true
    property bool   cfg_showTitle:            true
    property bool   cfg_showTitleDefault:     true

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.ComboBox {
            id: gpuCombo
            Kirigami.FormData.label: i18n("GPU:")

            model: {
                const items = [{ text: i18n("Auto (all GPUs)"), value: "" }]
                const gpus = GpuMonitor.gpus
                for (let i = 0; i < gpus.length; ++i) {
                    items.push({ text: gpus[i].name, value: gpus[i].key })
                }
                return items
            }

            textRole: "text"
            valueRole: "value"

            Component.onCompleted: {
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === page.cfg_gpu) {
                        currentIndex = i
                        return
                    }
                }
                currentIndex = 0
            }

            onActivated: page.cfg_gpu = currentValue
        }

        QQC2.CheckBox {
            id: cycleModeCheck
            Kirigami.FormData.label: i18n("Auto cycle GPUs:")
            enabled: page.cfg_gpu === ""
            checked: page.cfg_cycleMode
            onToggled: page.cfg_cycleMode = checked
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Auto cycle interval (seconds):")
            enabled: page.cfg_gpu === "" && cycleModeCheck.checked
            from: 1
            to: 30
            stepSize: 1
            value: Math.max(1, page.cfg_cycleInterval)
            onValueChanged: page.cfg_cycleInterval = value
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: i18n("Show GPU name:")
            checked: page.cfg_showTitle
            onToggled: page.cfg_showTitle = checked
        }
    }
}

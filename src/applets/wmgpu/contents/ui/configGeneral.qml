// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.wmdock 1.0

Item {
    id: page

    property string cfg_gpu: ""
    property int cfg_cycleInterval: 0

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

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Auto cycle interval (seconds):")
            from: 1
            to: 30
            stepSize: 1
            value: page.cfg_cycleInterval
            onValueChanged: page.cfg_cycleInterval = value
        }
    }
}

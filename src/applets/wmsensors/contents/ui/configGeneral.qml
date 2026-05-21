// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.wmdock 1.0

/**
 * WMSensors configuration page.
 *
 * Shows a checkbox for every sensor discovered by ThermalMonitor so the
 * user can choose which ones to cycle through.  Also exposes the display
 * interval (seconds per sensor).
 */
Item {
    id: page

    property var    cfg_enabledSensors:  []
    property int    cfg_displayInterval: 0

    Kirigami.FormLayout {
        id: form
        anchors.left:  parent.left
        anchors.right: parent.right

        // Section header
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Sensors to display")
        }

        // One checkbox per discovered sensor
        Repeater {
            model: ThermalMonitor.sensors

            QQC2.CheckBox {
                required property var   modelData
                required property int   index

                Kirigami.FormData.label: modelData.label + " (" + modelData.name + ")"

                checked: page.cfg_enabledSensors.indexOf(modelData.key) >= 0

                onCheckedChanged: {
                    let list = page.cfg_enabledSensors.slice()
                    const idx = list.indexOf(modelData.key)
                    if (checked && idx < 0)
                        list.push(modelData.key)
                    else if (!checked && idx >= 0)
                        list.splice(idx, 1)
                    page.cfg_enabledSensors = list
                }
            }
        }

        // Section header
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Display options")
        }

        QQC2.SpinBox {
            id: intervalSpinBox
            Kirigami.FormData.label: i18n("Seconds per sensor:")
            from: 1; to: 30; stepSize: 1
            value: page.cfg_displayInterval
            onValueChanged: page.cfg_displayInterval = value
        }
    }
}

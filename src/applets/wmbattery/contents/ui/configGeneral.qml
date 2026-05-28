// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string title:                          ""
    property int    cfg_lowBatteryThreshold:        0
    property int    cfg_lowBatteryThresholdDefault: 20

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: thresholdSpinBox
            Kirigami.FormData.label: i18n("Low battery warning threshold (%):")
            from: 1
            to:   50
            stepSize: 1
            value: page.cfg_lowBatteryThreshold
            onValueChanged: page.cfg_lowBatteryThreshold = value
        }
    }
}

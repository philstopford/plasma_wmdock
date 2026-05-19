// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: page

    property int cfg_histLen: 0

    onCfg_histLenChanged: histLenSpinBox.value = cfg_histLen

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        QQC2.SpinBox {
            id: histLenSpinBox
            Kirigami.FormData.label: i18n("Graph history length (samples):")
            from: 10
            to:   200
            stepSize: 10
            onValueChanged: page.cfg_histLen = value
        }
    }
}

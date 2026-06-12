// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

Item {
    Loader {
        id: vizLoader
        anchors.fill: parent
        source: Qt.resolvedUrl("../../../wmviz/contents/ui/Display.qml")
        onStatusChanged: {
            if (status === Loader.Error && source.toString().indexOf("/wmviz/") >= 0)
                source = Qt.resolvedUrl("../../../org.kde.plasma.wmviz/contents/ui/Display.qml")
        }
        onLoaded: {
            if (item)
                item.forcedEffect = "plasmaball"
        }
    }
}

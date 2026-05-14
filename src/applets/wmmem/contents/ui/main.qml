// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid

PlasmoidItem {
    preferredRepresentation: fullRepresentation
    fullRepresentation: Display {
        anchors.fill: parent
    }
}

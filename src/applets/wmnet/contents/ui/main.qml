// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid

PlasmoidItem {
    preferredRepresentation: fullRepresentation
    fullRepresentation: Display {
        anchors.fill: parent
        // Explicitly forward the saved interface so Display.qml always
        // receives it via externalIface (the same path used when embedded
        // in WMDock via Loader), rather than relying on
        // Plasmoid.configuration inside Display.qml where the Plasmoid
        // context may refer to a parent applet's configuration.
        externalIface: Plasmoid.configuration.iface || ""
    }
}

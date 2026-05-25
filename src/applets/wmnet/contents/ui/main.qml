// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid

PlasmoidItem {
    preferredRepresentation: fullRepresentation
    fullRepresentation: Display {
        anchors.fill: parent

        // Forward selected interfaces, falling back to the legacy singular
        // iface key for users upgrading from the old single-interface config.
        externalIfaces: {
            const ifaces = Plasmoid.configuration.ifaces || []
            if (ifaces.length > 0) return ifaces
            const iface = Plasmoid.configuration.iface || ""
            return iface ? [iface] : []
        }
        externalCycleMode:     Plasmoid.configuration.cycleMode
        externalCycleInterval: Math.max(1, Plasmoid.configuration.cycleInterval || 4)
    }
}

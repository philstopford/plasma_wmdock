// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.wmdock 1.0

/**
 * WMNet configuration page – lets the user choose which network interface
 * to monitor.  The interface list is populated from NetworkMonitor which
 * reads /proc/net/dev via the custom C++ plugin.
 */
Kirigami.FormLayout {
    id: page

    // Standard cfg_ alias wired to Plasmoid.configuration.iface
    property alias cfg_iface: ifaceCombo.currentValue

    QQC2.ComboBox {
        id: ifaceCombo
        Kirigami.FormData.label: i18n("Network interface:")

        // Build model: "Auto" entry + discovered interfaces
        model: {
            const items = [{ text: i18n("Auto (first non-loopback)"), value: "" }]
            const ifaces = NetworkMonitor.interfaces
            for (let i = 0; i < ifaces.length; ++i) {
                items.push({ text: ifaces[i], value: ifaces[i] })
            }
            return items
        }

        textRole:  "text"
        valueRole: "value"

        // Select the entry that matches the saved configuration
        Component.onCompleted: {
            const saved = cfg_iface
            for (let i = 0; i < model.length; ++i) {
                if (model[i].value === saved) {
                    currentIndex = i
                    return
                }
            }
            currentIndex = 0  // fallback to "Auto"
        }
    }
}

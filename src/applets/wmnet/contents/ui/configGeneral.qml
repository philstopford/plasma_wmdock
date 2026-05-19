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
Item {
    id: page

    // Writable cfg_ property that Plasma reads/writes.
    // (We can't alias ComboBox.currentValue directly because it is readonly.)
    property string cfg_iface: ""

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

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

            // Set initial selection after both model and cfg_iface are available
            Component.onCompleted: {
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === page.cfg_iface) {
                        currentIndex = i
                        return
                    }
                }
                currentIndex = 0  // fallback to "Auto"
            }

            // User-driven change → update cfg_iface so Plasma can save it
            onActivated: page.cfg_iface = currentValue
        }
    }
}

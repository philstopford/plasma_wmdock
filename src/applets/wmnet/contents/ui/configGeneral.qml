// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.wmdock 1.0

/**
 * WMNet configuration page.
 *
 * Lets the user choose which network interfaces to monitor and whether to
 * auto-cycle through them.  An empty ifaces list means "all non-loopback".
 */
Item {
    id: page

    // Writable cfg_ properties that Plasma reads/writes.
    property var  cfg_ifaces:        []
    property bool cfg_cycleMode:     false
    property int  cfg_cycleInterval: 0

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        // ---- Interface selection ----------------------------------------
        // Each discovered non-loopback interface gets a CheckBox.
        // Leaving all unchecked (or checking all) means "auto = all".

        Repeater {
            id: ifaceRepeater
            model: NetworkMonitor.interfaces.filter(function(i) {
                return !i.startsWith("lo")
            })

            QQC2.CheckBox {
                Kirigami.FormData.label: index === 0 ? i18n("Interfaces\n(none = all):") : ""

                text: modelData

                // Reactive binding: checked when ifaces is empty (all) or contains this iface.
                // Using a direct binding keeps all checkboxes in sync after any toggle.
                checked: page.cfg_ifaces.length === 0 ||
                         page.cfg_ifaces.indexOf(modelData) >= 0

                onToggled: {
                    // Collect the checked state of every checkbox via itemAt()
                    var newList = []
                    for (var i = 0; i < ifaceRepeater.count; i++) {
                        var item = ifaceRepeater.itemAt(i)
                        if (item && item.checked)
                            newList.push(item.text)
                    }
                    // If all are checked, treat as "auto" (empty list)
                    if (newList.length === ifaceRepeater.count)
                        newList = []
                    page.cfg_ifaces = newList
                }
            }
        }

        // ---- Cycle mode ------------------------------------------------

        QQC2.CheckBox {
            id: cycleModeCheck
            Kirigami.FormData.label: i18n("Auto cycle interfaces:")

            checked: page.cfg_cycleMode
            onToggled: page.cfg_cycleMode = checked
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Cycle interval (seconds):")
            enabled: cycleModeCheck.checked
            from: 1
            to: 60
            stepSize: 1

            value: Math.max(1, page.cfg_cycleInterval || 4)
            onValueChanged: page.cfg_cycleInterval = value
        }
    }
}

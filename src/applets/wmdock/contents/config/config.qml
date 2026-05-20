// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.configuration

/**
 * Plasma config model for WMDock.
 * Registers configGeneral.qml as the "General" tab in the Configure dialog.
 * Without this file Plasma shows only its basic auto-generated property list.
 */
ConfigModel {
    ConfigCategory {
        name:   i18n("General")
        icon:   "configure"
        source: "configGeneral.qml"
    }
}

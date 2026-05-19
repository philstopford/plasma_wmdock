// SPDX-License-Identifier: GPL-2.0-or-later
import org.kde.plasma.configuration 2.0

/**
 * Plasma config model for WMDrawer.
 * Registers configGeneral.qml as the "General" tab in the Configure dialog.
 * Without this file Plasma shows only its basic auto-generated property list.
 */
ConfigModel {
    ConfigCategory {
        name:   i18n("General")
        icon:   "folder"
        source: "configGeneral.qml"
    }
}

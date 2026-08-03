// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

/**
 * WM Dock – main container plasmoid.
 *
 * Arranges DockSlot items in a Flow layout, adapting to the panel
 * orientation (vertical / horizontal).  Each slot hosts one of the
 * built-in mini-applets identified by its plasmoid ID string, or an
 * external dockapp via XEmbed (X11 sessions only).
 */
PlasmoidItem {
    id: root

    // -----------------------------------------------------------------------
    // Configuration shortcuts
    // -----------------------------------------------------------------------
    readonly property int    slotSize    : Plasmoid.configuration.slotSize
    readonly property int    slotSpacing : Plasmoid.configuration.slotSpacing
    readonly property var    appletList  : Plasmoid.configuration.appletList
    readonly property var    slotConfigs : Plasmoid.configuration.slotConfigs || []
    readonly property bool   showBg      : Plasmoid.configuration.showBackground
    readonly property double bgOpacity   : Plasmoid.configuration.backgroundOpacity

    readonly property bool isVertical:
        Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // Fill full representation immediately (no compact icon)
    preferredRepresentation: fullRepresentation

    // -----------------------------------------------------------------------
    // Sizing
    // -----------------------------------------------------------------------
    readonly property int count: appletList.length
    readonly property int totalSlots: Math.max(1, count)

    readonly property int panelThickness : slotSize + 8
    readonly property int panelLength    : totalSlots * (slotSize + slotSpacing) + slotSpacing + 4

    implicitWidth:  isVertical ? panelThickness : panelLength
    implicitHeight: isVertical ? panelLength    : panelThickness

    // -----------------------------------------------------------------------
    // Full representation
    // -----------------------------------------------------------------------
    fullRepresentation: Item {
        id: dockRoot
        implicitWidth:  root.implicitWidth
        implicitHeight: root.implicitHeight

        // Background panel
        Rectangle {
            anchors.fill: parent
            color: "#1c1c1c"
            opacity: showBg ? bgOpacity : 0
            border.color: "#444"
            border.width: 1
            radius: 4

            // Raised-edge highlight (classic WM look)
            Rectangle {
                width: parent.width - 2
                height: parent.height - 2
                x: 1; y: 1
                color: "transparent"
                border.color: "#666"
                border.width: 1
                radius: parent.radius - 1
                opacity: 0.5
            }
        }

        // Slot grid
        Flow {
            id: slotFlow
            anchors {
                fill: parent
                margins: slotSpacing
            }
            flow:    isVertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: slotSpacing

            Repeater {
                id: slotRepeater
                model: appletList

                DockSlot {
                    width:      slotSize
                    height:     slotSize
                    appletId:   modelData
                    slotIndex:  index
                    totalCount: appletList.length
                    slotConfig: index < slotConfigs.length ? slotConfigs[index] : ""
                    dockOrientation: root.isVertical ? "vertical" : "horizontal"

                    onRemoveRequested: {
                        const lst = [...appletList]
                        lst.splice(index, 1)
                        Plasmoid.configuration.appletList = lst
                        // Also remove corresponding slotConfig
                        const cfgLst = [...slotConfigs]
                        if (index < cfgLst.length) cfgLst.splice(index, 1)
                        Plasmoid.configuration.slotConfigs = cfgLst
                    }

                    onMoveLeft: {
                        if (index === 0) return
                        const lst = [...appletList]
                        const tmp = lst[index - 1]
                        lst[index - 1] = lst[index]
                        lst[index]     = tmp
                        Plasmoid.configuration.appletList = lst
                        // Swap slotConfigs too
                        const cfgLst = [...slotConfigs]
                        while (cfgLst.length <= index) cfgLst.push("")
                        const tmpCfg = cfgLst[index - 1]
                        cfgLst[index - 1] = cfgLst[index]
                        cfgLst[index]     = tmpCfg
                        Plasmoid.configuration.slotConfigs = cfgLst
                    }

                    onMoveRight: {
                        if (index >= appletList.length - 1) return
                        const lst = [...appletList]
                        const tmp = lst[index + 1]
                        lst[index + 1] = lst[index]
                        lst[index]     = tmp
                        Plasmoid.configuration.appletList = lst
                        // Swap slotConfigs too
                        const cfgLst = [...slotConfigs]
                        while (cfgLst.length <= index + 1) cfgLst.push("")
                        const tmpCfg = cfgLst[index + 1]
                        cfgLst[index + 1] = cfgLst[index]
                        cfgLst[index]     = tmpCfg
                        Plasmoid.configuration.slotConfigs = cfgLst
                    }

                    onSlotConfigSaved: (idx, cfg) => {
                        const cfgLst = [...slotConfigs]
                        while (cfgLst.length <= idx) cfgLst.push("")
                        cfgLst[idx] = cfg
                        Plasmoid.configuration.slotConfigs = cfgLst
                    }
                }
            }
        }

        // "Add applet" button shown when dock is empty
        PlasmaComponents.ToolButton {
            anchors.centerIn: parent
            visible: appletList.length === 0
            icon.name: "list-add"
            text: i18n("Add Applet")
            onClicked: Plasmoid.action("configure").trigger()
        }
    }

    // -----------------------------------------------------------------------
    // Configuration page
    // -----------------------------------------------------------------------
    Plasmoid.configurationRequired: false

    // Context-menu action: Add applet
    PlasmaCore.Action {
        id: addAppletAction
        text: i18n("Add Applet…")
        icon.name: "list-add"
        onTriggered: addAppletDialog.open()
    }

    Plasmoid.contextualActions: [addAppletAction]

    // -----------------------------------------------------------------------
    // Add-Applet dialog
    // -----------------------------------------------------------------------
    QQC2.Dialog {
        id: addAppletDialog
        title: i18n("Add Applet")
        modal: true
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: 320
        height: 380

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("Select an applet to add to the dock:")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: appletPickerList
                    currentIndex: 0

                    model: ListModel {
                        ListElement { label: "WMClock – Analog/digital clock";    appletId: "org.kde.plasma.wmclock"   }
                        ListElement { label: "WMCPUMon – CPU usage graph";        appletId: "org.kde.plasma.wmcpu"     }
                        ListElement { label: "WMMemMon – Memory usage";           appletId: "org.kde.plasma.wmmem"     }
                        ListElement { label: "WMBattery – Battery status";        appletId: "org.kde.plasma.wmbattery" }
                        ListElement { label: "WMNet – Network traffic";           appletId: "org.kde.plasma.wmnet"     }
                        ListElement { label: "WMMixer – Volume control";          appletId: "org.kde.plasma.wmmixer"   }
                        ListElement { label: "WMLoad – Load average";             appletId: "org.kde.plasma.wmload"    }
                        ListElement { label: "WMCalendar – Date/calendar";        appletId: "org.kde.plasma.wmcal"     }
                        ListElement { label: "WMLauncher – App launcher button";  appletId: "org.kde.plasma.wmlauncher"}
                        ListElement { label: "WMDrawer – Expandable launcher drawer"; appletId: "org.kde.plasma.wmdrawer" }
                        ListElement { label: "WMWeather – Weather conditions";    appletId: "org.kde.plasma.wmweather" }
                        ListElement { label: "WMViz – Audio visualizer";          appletId: "org.kde.plasma.wmviz" }
                        ListElement { label: "WMMatrix – Matrix rain";            appletId: "org.kde.plasma.wmmatrix" }
                        ListElement { label: "WMPlasmaBall – Plasma ball";        appletId: "org.kde.plasma.wmplasmaball" }
                        ListElement { label: "WMPlay – Audio player";             appletId: "org.kde.plasma.wmplay" }
                        ListElement { label: "WMEyes – Mouse-tracking eyes";      appletId: "org.kde.plasma.wmeyes" }
                        ListElement { label: "WMLava – Lava lamp simulation";     appletId: "org.kde.plasma.wmlava" }
                        ListElement { label: "WMSensors – Thermal sensors";       appletId: "org.kde.plasma.wmsensors" }
                        ListElement { label: "WMStorage – Disk usage";            appletId: "org.kde.plasma.wmstorage" }
                        ListElement { label: "WMGPU – GPU load and VRAM";         appletId: "org.kde.plasma.wmgpu" }
                    }

                    delegate: QQC2.ItemDelegate {
                        width: ListView.view.width
                        text: model.label
                        highlighted: ListView.isCurrentItem
                        onClicked: appletPickerList.currentIndex = index
                    }
                }
            }
        }

        footer: QQC2.DialogButtonBox {
            QQC2.Button {
                text: i18n("Add")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
            }
            QQC2.Button {
                text: i18n("Cancel")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole
            }
        }

        onAccepted: {
            const picked = appletPickerList.model.get(appletPickerList.currentIndex)
            if (picked) {
                const lst = [...appletList, picked.appletId]
                Plasmoid.configuration.appletList = lst
            }
        }
    }
}

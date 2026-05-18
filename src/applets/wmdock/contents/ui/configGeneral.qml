// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/**
 * Configuration page for the WM Dock main applet.
 * Allows the user to add, remove and reorder applet slots.
 */
KCM.SimpleKCM {
    property alias cfg_slotSize:          slotSizeSpinBox.value
    property alias cfg_slotSpacing:       spacingSpinBox.value
    property alias cfg_showBackground:    showBgCheck.checked
    property alias cfg_backgroundOpacity: opacitySlider.value
    property var   cfg_appletList:        []

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // ---- Slot size -------------------------------------------------------
        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.SpinBox {
                id: slotSizeSpinBox
                Kirigami.FormData.label: i18n("Slot size (px):")
                from: 32; to: 128; stepSize: 8
            }

            QQC2.SpinBox {
                id: spacingSpinBox
                Kirigami.FormData.label: i18n("Slot spacing (px):")
                from: 0; to: 16; stepSize: 1
            }

            QQC2.CheckBox {
                id: showBgCheck
                Kirigami.FormData.label: i18n("Show background:")
            }

            QQC2.Slider {
                id: opacitySlider
                Kirigami.FormData.label: i18n("Background opacity:")
                from: 0.1; to: 1.0; stepSize: 0.05
                enabled: showBgCheck.checked
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ---- Applet list management -----------------------------------------
        PlasmaComponents.Label {
            text: i18n("Active applets (drag to reorder):")
            font.bold: true
        }

        ListView {
            id: appletListView
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            clip: true
            model: cfg_appletList

            move: Transition { NumberAnimation { properties: "y"; duration: 150 } }

            delegate: QQC2.ItemDelegate {
                id: listDelegate
                width: ListView.view.width
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "application-x-plasma"
                        Layout.preferredWidth:  Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }

                    PlasmaComponents.Label {
                        text: modelData.replace("org.kde.plasma.", "").replace(/^wm/, "WM")
                        Layout.fillWidth: true
                    }

                    QQC2.ToolButton {
                        icon.name: "arrow-up"
                        visible: index > 0
                        onClicked: {
                            const lst = [...cfg_appletList]
                            const tmp = lst[index - 1]; lst[index - 1] = lst[index]; lst[index] = tmp
                            cfg_appletList = lst
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "arrow-down"
                        visible: index < cfg_appletList.length - 1
                        onClicked: {
                            const lst = [...cfg_appletList]
                            const tmp = lst[index + 1]; lst[index + 1] = lst[index]; lst[index] = tmp
                            cfg_appletList = lst
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "list-remove"
                        onClicked: {
                            const lst = [...cfg_appletList]
                            lst.splice(index, 1)
                            cfg_appletList = lst
                        }
                    }
                }
            }

            ScrollBar.vertical: QQC2.ScrollBar {}
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.ComboBox {
                id: addCombo
                Layout.fillWidth: true
                model: [
                    { text: i18n("WMClock – Clock"),          value: "org.kde.plasma.wmclock"    },
                    { text: i18n("WMCPUMon – CPU"),           value: "org.kde.plasma.wmcpu"      },
                    { text: i18n("WMMemMon – Memory"),        value: "org.kde.plasma.wmmem"      },
                    { text: i18n("WMBattery – Battery"),      value: "org.kde.plasma.wmbattery"  },
                    { text: i18n("WMNet – Network"),          value: "org.kde.plasma.wmnet"      },
                    { text: i18n("WMMixer – Volume"),         value: "org.kde.plasma.wmmixer"    },
                    { text: i18n("WMLoad – Load average"),    value: "org.kde.plasma.wmload"     },
                    { text: i18n("WMCalendar – Calendar"),    value: "org.kde.plasma.wmcal"      },
                    { text: i18n("WMLauncher – Launcher"),    value: "org.kde.plasma.wmlauncher" },
                    { text: i18n("WMDrawer – App drawer"),    value: "org.kde.plasma.wmdrawer"   },
                    { text: i18n("WMWeather – Weather"),      value: "org.kde.plasma.wmweather"  },
                ]
                textRole: "text"
            }

            QQC2.Button {
                text: i18n("Add")
                icon.name: "list-add"
                onClicked: {
                    const picked = addCombo.model[addCombo.currentIndex]
                    if (picked) cfg_appletList = [...cfg_appletList, picked.value]
                }
            }
        }
    }
}

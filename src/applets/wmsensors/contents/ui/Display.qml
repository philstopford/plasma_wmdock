// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMSensors – Cycling hardware temperature display.
 *
 * Shows one sensor at a time and cycles through the user-selected set
 * on a configurable interval.  The temperature is displayed as:
 *   • A large numeric value (e.g. "53°C")
 *   • A colour-coded bar from cool (green) to hot (red) based on the
 *     typical 0–100 °C range
 *   • The sensor label beneath the value
 *
 * Data comes from ThermalMonitor (C++ singleton reading /sys/class/hwmon
 * and /sys/class/thermal).  When no sensors are enabled in configuration
 * all available sensors are cycled through.
 */
Item {
    id: root

    // ----- configuration ---------------------------------------------------
    readonly property var    enabledKeys:      Plasmoid.configuration.enabledSensors || []
    readonly property int    displayInterval:  Math.max(1, Plasmoid.configuration.displayInterval || 3)

    // ----- active sensor selection ----------------------------------------
    property int  cycleIndex:  0
    property var  activeSensor: null   // current QVariantMap or null

    function buildActiveSensors() {
        const all  = ThermalMonitor.sensors
        const keys = root.enabledKeys
        if (!all || all.length === 0) return []
        if (!keys || keys.length === 0) return all
        return all.filter(s => keys.indexOf(s.key) >= 0)
    }

    function advance() {
        const active = root.buildActiveSensors()
        if (active.length === 0) {
            root.activeSensor = null
            return
        }
        if (root.cycleIndex >= active.length)
            root.cycleIndex = 0
        root.activeSensor = active[root.cycleIndex]
        root.cycleIndex  = (root.cycleIndex + 1) % active.length
    }

    Component.onCompleted: advance()

    Timer {
        id: cycleTimer
        interval: root.displayInterval * 1000
        repeat:   true
        running:  true
        onTriggered: root.advance()
    }

    // Update current reading when ThermalMonitor refreshes
    Connections {
        target: ThermalMonitor
        function onSensorsChanged() {
            // Refresh active sensor without changing which one is shown
            const all  = ThermalMonitor.sensors
            const keys = root.enabledKeys
            let active = (!keys || keys.length === 0) ? all
                         : all.filter(s => keys.indexOf(s.key) >= 0)
            if (active.length === 0) { root.activeSensor = null; return }
            const prevKey = root.activeSensor ? root.activeSensor.key : ""
            const found   = active.find(s => s.key === prevKey)
            if (found) root.activeSensor = found
        }
    }

    // ----- colour for temperature ------------------------------------------
    function tempColor(t) {
        if (t >= 90) return "#ff2200"
        if (t >= 75) return "#ff8800"
        if (t >= 60) return "#ffcc00"
        if (t >= 45) return "#aacc00"
        return "#00cc44"
    }

    // ----- background ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    // ----- temperature bar -------------------------------------------------
    Item {
        id: barArea
        anchors {
            top:        parent.top; topMargin: 3
            left:       parent.left;  leftMargin: 5
            right:      parent.right; rightMargin: 5
        }
        height: parent.height * 0.08

        Rectangle {
            anchors.fill: parent
            color:  "#0a0a00"
            radius: 1
        }
        Rectangle {
            height: parent.height
            radius: 1
            width: {
                const t = root.activeSensor ? root.activeSensor.temp : 0
                return parent.width * Math.max(0, Math.min(1, t / 100))
            }
            color: root.activeSensor ? root.tempColor(root.activeSensor.temp) : "#222"
            Behavior on width { NumberAnimation { duration: 400 } }
        }
    }

    // ----- large temperature readout ---------------------------------------
    Text {
        id: tempLabel
        anchors {
            top:              barArea.bottom; topMargin: 4
            horizontalCenter: parent.horizontalCenter
        }
        text: root.activeSensor
              ? root.activeSensor.temp.toFixed(1) + "°C"
              : "—"
        color: root.activeSensor ? root.tempColor(root.activeSensor.temp) : "#444"
        font { pixelSize: parent.height * 0.22; family: "monospace"; bold: true }
    }

    // ----- sensor label ----------------------------------------------------
    Text {
        anchors {
            top:              tempLabel.bottom; topMargin: 2
            left:             parent.left; leftMargin: 3
            right:            parent.right; rightMargin: 3
        }
        text:   root.activeSensor ? root.activeSensor.label : i18n("No sensors")
        color:  "#888"
        font  { pixelSize: parent.height * 0.09; family: "monospace" }
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    // ----- sensor source (chip name) ----------------------------------------
    Text {
        anchors {
            bottom: parent.bottom; bottomMargin: 2
            horizontalCenter: parent.horizontalCenter
        }
        text: root.activeSensor ? "[" + root.activeSensor.name + "]" : ""
        color: "#444"
        font { pixelSize: parent.height * 0.08; family: "monospace" }
    }

    // ----- click: advance immediately -------------------------------------
    TapHandler {
        onTapped: { root.advance(); cycleTimer.restart() }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.ksystemstats 1.0

/**
 * WMCPUMon – CPU usage monitor.
 *
 * Uses KDE's org.kde.ksystemstats QML API (same backend as KDE's own
 * "Individual Core Usage" widget) so data flows correctly in all Plasma 6
 * configurations without depending on the custom C++ plugin for sensor values.
 *
 * • Scrolling bar-chart showing total CPU over the last ~50 samples
 * • Per-core usage bars at the top (one pixel per core)
 * • Numeric percentage readout
 * • Classic green-on-black dockapp palette
 */
Item {
    id: root

    // Rolling history (filled left→right, newest on right)
    property int histLen: 50
    property var history: []

    // Number of real CPU cores; detected once after ksystemstats connects
    property int coreCount: 0

    // -----------------------------------------------------------------------
    // ksystemstats sensors
    // -----------------------------------------------------------------------

    // Aggregate CPU usage (0–100 %)
    Sensor {
        id: cpuAllSensor
        sensorId: "cpu/all/usage"
        enabled:  true
        onValueChanged: {
            const v = Math.min(100, Math.max(0, value || 0))
            let h = [...root.history, v]
            if (h.length > root.histLen) h = h.slice(h.length - root.histLen)
            root.history = h
            graph.requestPaint()
            coreBar.requestPaint()
        }
    }

    // Per-core sensors — sensors list populated after core count is known
    SensorDataModel {
        id: coreModel
        sensors: []
        enabled:  true
        onDataChanged: coreBar.requestPaint()
    }

    // Detect online CPU core count from /sys (file:// XHR is allowed in Plasma)
    function detectCores() {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", "file:///sys/devices/system/cpu/present", true)
        xhr.onload = function () {
            const text = xhr.responseText.trim()           // e.g. "0-7"
            const m    = text.match(/(\d+)\s*$/)
            const n    = m ? (parseInt(m[1]) + 1) : 4
            root.coreCount = n
            const ids = []
            for (let i = 0; i < n; ++i) ids.push("cpu/cpu" + i + "/usage")
            coreModel.sensors = ids
            coreBar.requestPaint()
        }
        xhr.onerror = function () {
            console.warn("wmcpu: failed to read /sys/devices/system/cpu/present (status "
                         + xhr.status + "); falling back to 4 cores")
            root.coreCount = 4
            coreModel.sensors = ["cpu/cpu0/usage","cpu/cpu1/usage",
                                  "cpu/cpu2/usage","cpu/cpu3/usage"]
            coreBar.requestPaint()
        }
        xhr.send()
    }

    Component.onCompleted: {
        detectCores()
        graph.requestPaint()
        coreBar.requestPaint()
    }

    // -----------------------------------------------------------------------
    // Background
    // -----------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    // -----------------------------------------------------------------------
    // Header label
    // -----------------------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 2 }
        text: "CPU"
        color: "#00cc00"
        font { pixelSize: parent.height * 0.12; family: "monospace"; bold: true }
    }

    // -----------------------------------------------------------------------
    // Per-core bars (thin strip below title)
    // -----------------------------------------------------------------------
    Canvas {
        id: coreBar
        anchors {
            top:        titleText.bottom
            left:       parent.left
            right:      parent.right
            leftMargin: 3
            rightMargin: 3
        }
        // Height grows in 4-pixel steps, one row per 4 cores
        height: root.coreCount > 0 ? Math.max(4, Math.ceil(root.coreCount / 4) * 4) : 4

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const n = coreModel.sensors.length
            if (n === 0) return

            // Collect valid per-core values; SensorDataModel has 1 row × N columns.
            // Sensors that aren't connected yet return null/undefined for their Value.
            const vals = []
            for (let col = 0; col < n; ++col) {
                const v = coreModel.data(coreModel.index(0, col), SensorDataModel.Value)
                // null/undefined means not yet connected — skip silently
                if (v !== null && v !== undefined) vals.push(v)
            }
            if (vals.length === 0) return

            const barW = (width - 1) / vals.length
            const barH = height

            for (let i = 0; i < vals.length; ++i) {
                const pct = Math.min(100, Math.max(0, vals[i])) / 100
                const bh  = Math.round(pct * barH)
                const hue = pct > 0.75 ? "#ff4400" : pct > 0.5 ? "#aacc00" : "#00cc00"
                ctx.fillStyle = "#001100"
                ctx.fillRect(i * barW, 0, barW - 1, barH)
                ctx.fillStyle = hue
                ctx.fillRect(i * barW, barH - bh, barW - 1, bh)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Scrolling graph
    // -----------------------------------------------------------------------
    Canvas {
        id: graph
        anchors {
            top:         coreBar.bottom
            left:        parent.left
            right:       parent.right
            bottom:      pctLabel.top
            topMargin:   2
            leftMargin:  3
            rightMargin: 3
            bottomMargin: 2
        }

        onPaint: {
            const ctx  = getContext("2d")
            const w    = width, h = height
            ctx.clearRect(0, 0, w, h)

            // Grid
            ctx.strokeStyle = "#0a2200"
            ctx.lineWidth   = 0.5
            for (let pct = 25; pct < 100; pct += 25) {
                const y = h - (pct / 100) * h
                ctx.beginPath()
                ctx.moveTo(0, y); ctx.lineTo(w, y)
                ctx.stroke()
            }

            const hist = root.history
            if (hist.length < 2) return

            const barW = w / root.histLen

            for (let i = 0; i < hist.length; i++) {
                const pct  = hist[i] / 100
                const bh   = Math.max(1, Math.round(pct * h))
                const x    = i * barW
                const hue  = pct > 0.75 ? "#ff4400" : pct > 0.5 ? "#88cc00" : "#00cc00"
                ctx.fillStyle = hue
                ctx.fillRect(Math.round(x), h - bh, Math.max(1, Math.floor(barW) - 1), bh)
            }

            // Highlight the newest bar
            const last  = hist[hist.length - 1] / 100
            const lbh   = Math.max(1, Math.round(last * h))
            const lx    = (hist.length - 1) * barW
            ctx.fillStyle = "#ffffff"
            ctx.fillRect(Math.round(lx), h - lbh, 1, lbh)
        }
    }

    // -----------------------------------------------------------------------
    // Percentage readout
    // -----------------------------------------------------------------------
    Text {
        id: pctLabel
        anchors {
            bottom:           parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin:     2
        }
        text: (cpuAllSensor.value || 0).toFixed(0) + "%"
        color: {
            const v = cpuAllSensor.value || 0
            return v > 75 ? "#ff4400" : v > 50 ? "#aacc00" : "#00cc00"
        }
        font { pixelSize: parent.height * 0.14; family: "monospace"; bold: true }
    }
}

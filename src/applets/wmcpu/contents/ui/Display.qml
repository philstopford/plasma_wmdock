// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMCPUMon – CPU usage monitor.
 *
 * • Scrolling bar-chart showing total CPU over the last ~50 samples
 * • Per-core usage bars at the top (one pixel per core)
 * • Numeric percentage readout
 * • Classic green-on-black dockapp palette
 *
 * Data source: SystemMonitor singleton from the wmdockplugin C++ extension.
 */
Item {
    id: root

    // Rolling history (filled left→right, newest on right)
    property int histLen: Plasmoid.configuration.histLen ?? 50
    property var history: []

    // Core usage (array of 0–100 values)
    property var coreUsage: SystemMonitor.cpuCoreUsage

    Component.onCompleted: {
        Qt.callLater(function() {
            graph.requestPaint()
            coreBar.requestPaint()
        })
    }

    Connections {
        target: SystemMonitor
        function onCpuUsageChanged() {
            const v = Math.min(100, Math.max(0, SystemMonitor.cpuUsage))
            let h = [...root.history, v]
            if (h.length > root.histLen) h = h.slice(h.length - root.histLen)
            root.history = h
            graph.requestPaint()
            coreBar.requestPaint()
        }
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
    // Per-core bars (thin strip at top)
    // -----------------------------------------------------------------------
    Canvas {
        id: coreBar
        anchors {
            top:        parent.top
            left:       parent.left
            right:      parent.right
            topMargin:  3
            leftMargin: 3
            rightMargin: 3
        }
        height: Math.max(4, Math.ceil(SystemMonitor.cpuCoreCount / 4) * 4)

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const cores = root.coreUsage
            if (!cores || cores.length === 0) return

            const barW = (width  - 1) / cores.length
            const barH = height

            for (let i = 0; i < cores.length; i++) {
                const pct = Math.min(100, Math.max(0, cores[i])) / 100
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
        text: SystemMonitor.cpuUsage.toFixed(0) + "%"
        color: {
            const v = SystemMonitor.cpuUsage
            return v > 75 ? "#ff4400" : v > 50 ? "#aacc00" : "#00cc00"
        }
        font { pixelSize: parent.height * 0.14; family: "monospace"; bold: true }
    }
}

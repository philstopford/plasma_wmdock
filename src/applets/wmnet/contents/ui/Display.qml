// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.ksystemstats 1.0
import org.kde.plasma.private.wmdock 1.0

/**
 * WMNet – Network traffic monitor.
 *
 * Uses KDE's org.kde.ksystemstats QML API for rate data so values update
 * reliably in all Plasma 6 configurations.  NetworkMonitor (from the custom
 * C++ plugin) is retained only to supply the list of available interfaces
 * for the configuration dialog.
 *
 * The monitored interface is read from Plasmoid.configuration.iface; when
 * empty the first non-loopback interface reported by NetworkMonitor is used.
 *
 * Scrolling dual-channel graph: RX (green) stacked on TX (blue).
 * Auto-scales to the peak rate seen since startup.
 * Shows current interface name and rates below the graph.
 */
Item {
    id: root

    property int histLen: 50
    property var rxHistory: []
    property var txHistory: []

    // Peak rates for auto-scaling graph
    property real rxMax: 1.0
    property real txMax: 1.0

    // Resolved interface: prefer explicit config, fall back to first non-loopback
    readonly property string iface: {
        const cfg = Plasmoid.configuration.iface
        if (cfg && cfg.length > 0) return cfg
        // Auto-detect: use first non-loopback from NetworkMonitor
        const list = NetworkMonitor.interfaces
        for (let i = 0; i < list.length; ++i) {
            if (!list[i].startsWith("lo")) return list[i]
        }
        return ""
    }

    // -----------------------------------------------------------------------
    // ksystemstats sensors — sensor IDs rebuild when iface changes
    // -----------------------------------------------------------------------
    Sensor {
        id: rxSensor
        sensorId: root.iface.length > 0
                  ? "network/interfaces/" + root.iface + "/download/value"
                  : ""
        enabled:  root.iface.length > 0
        onValueChanged: {
            const rx = value || 0
            if (rx > root.rxMax) root.rxMax = rx
            let rh = [...root.rxHistory, rx]
            if (rh.length > root.histLen) rh = rh.slice(rh.length - root.histLen)
            root.rxHistory = rh
            graph.requestPaint()
        }
    }

    Sensor {
        id: txSensor
        sensorId: root.iface.length > 0
                  ? "network/interfaces/" + root.iface + "/upload/value"
                  : ""
        enabled:  root.iface.length > 0
        onValueChanged: {
            const tx = value || 0
            if (tx > root.txMax) root.txMax = tx
            let th = [...root.txHistory, tx]
            if (th.length > root.histLen) th = th.slice(th.length - root.histLen)
            root.txHistory = th
            graph.requestPaint()
        }
    }

    Component.onCompleted: graph.requestPaint()

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
    // Title + interface name
    // -----------------------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 1 }
        text: "NET " + (root.iface || "—")
        color: "#00aaff"
        font { pixelSize: parent.height * 0.11; family: "monospace"; bold: true }
        elide: Text.ElideRight
        width: parent.width - 4
        horizontalAlignment: Text.AlignHCenter
    }

    // -----------------------------------------------------------------------
    // Graph
    // -----------------------------------------------------------------------
    Canvas {
        id: graph
        anchors {
            top:         titleText.bottom
            left:        parent.left
            right:       parent.right
            bottom:      rateRow.top
            topMargin:   2
            leftMargin:  3
            rightMargin: 3
            bottomMargin: 2
        }

        onPaint: {
            const ctx = getContext("2d")
            const w = width, h = height
            ctx.clearRect(0, 0, w, h)

            const rxH  = root.rxHistory
            const txH  = root.txHistory
            const maxR = Math.max(1, root.rxMax)
            const maxT = Math.max(1, root.txMax)
            const bw   = w / root.histLen

            // Grid
            ctx.strokeStyle = "#00110a"
            ctx.lineWidth   = 0.5
            for (let g = 1; g < 4; g++) {
                const y = h - (g / 4) * h
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
            }

            // TX bars (blue, lower half)
            for (let i = 0; i < txH.length; i++) {
                const pct = txH[i] / maxT
                const bh  = Math.max(1, Math.round(pct * (h / 2)))
                ctx.fillStyle = "#0044bb"
                ctx.fillRect(Math.round(i * bw), h - bh, Math.max(1, Math.floor(bw) - 1), bh)
            }

            // RX bars (green, drawn on top)
            for (let i = 0; i < rxH.length; i++) {
                const pct = rxH[i] / maxR
                const bh  = Math.max(1, Math.round(pct * (h / 2)))
                ctx.fillStyle = "#00aa44"
                ctx.fillRect(Math.round(i * bw), h - (h/2) - bh, Math.max(1, Math.floor(bw) - 1), bh)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Rate readout
    // -----------------------------------------------------------------------
    function fmtRate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + "MB/s"
        if (b >= 1024)    return (b / 1024).toFixed(0)    + "KB/s"
        return b.toFixed(0) + "B/s"
    }

    Row {
        id: rateRow
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 2
        }
        spacing: 3

        Text {
            text: "↓" + fmtRate(rxSensor.value || 0)
            color: "#00aa44"
            font { pixelSize: parent.parent.height * 0.10; family: "monospace" }
        }
        Text {
            text: "↑" + fmtRate(txSensor.value || 0)
            color: "#4488ff"
            font { pixelSize: parent.parent.height * 0.10; family: "monospace" }
        }
    }
}

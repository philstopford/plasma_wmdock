// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMNet – Network traffic monitor.
 *
 * Scrolling dual-channel graph: RX (green) stacked on TX (blue).
 * Auto-scales to the peak rate seen since startup.
 * Shows current interface name and rates below the graph.
 *
 * Data source: NetworkMonitor singleton from the wmdockplugin C++ extension.
 * The active interface is read from Plasmoid.configuration.iface; when empty
 * NetworkMonitor auto-selects the first non-virtual interface.
 *
 * Debug output appears in: journalctl --user -f -g wmnet
 * or when plasmashell is run from a terminal.
 */
Item {
    id: root

    property int histLen: 50
    property var rxHistory: []
    property var txHistory: []

    // Apply saved interface preference once the component is ready
    Component.onCompleted: {
        const cfg = Plasmoid.configuration.iface
        console.log("[wmnet] Display loaded; configured iface='" + cfg
                    + "' detected iface='" + NetworkMonitor.iface + "'")
        if (cfg && cfg.length > 0) {
            NetworkMonitor.setIface(cfg)
            console.log("[wmnet] applied configured iface: " + cfg)
        }
        graph.requestPaint()
    }

    Connections {
        target: NetworkMonitor
        function onStatsChanged() {
            const rx = NetworkMonitor.rxBytesPerSec
            const tx = NetworkMonitor.txBytesPerSec
            console.log("[wmnet] statsChanged: iface=" + NetworkMonitor.iface
                        + " rx=" + rx.toFixed(0) + "B/s tx=" + tx.toFixed(0) + "B/s")

            let rh = [...root.rxHistory, rx]
            let th = [...root.txHistory, tx]
            if (rh.length > root.histLen) rh = rh.slice(rh.length - root.histLen)
            if (th.length > root.histLen) th = th.slice(th.length - root.histLen)
            root.rxHistory = rh
            root.txHistory = th
            graph.requestPaint()
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
    // Title + interface name
    // -----------------------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 1 }
        text: "NET " + NetworkMonitor.iface
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
            const maxR = Math.max(1, NetworkMonitor.rxMaxRate)
            const maxT = Math.max(1, NetworkMonitor.txMaxRate)
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
            text: "↓" + fmtRate(NetworkMonitor.rxBytesPerSec)
            color: "#00aa44"
            font { pixelSize: parent.parent.height * 0.10; family: "monospace" }
        }
        Text {
            text: "↑" + fmtRate(NetworkMonitor.txBytesPerSec)
            color: "#4488ff"
            font { pixelSize: parent.parent.height * 0.10; family: "monospace" }
        }
    }
}

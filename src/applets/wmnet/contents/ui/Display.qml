// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

/**
 * WMNet – Network traffic monitor.
 *
 * Supports two display modes:
 *
 *   Single / cycle mode (useSingleDisplay = true):
 *     Scrolling dual-channel graph (RX green, TX blue) for one interface.
 *     When multiple interfaces are selected and cycleMode is on, a Timer
 *     rotates through them at the configured interval.
 *
 *   Multi-interface mode (useSingleDisplay = false):
 *     All selected interfaces shown simultaneously with live RX/TX rates.
 *     Driven by NetworkMonitor.allIfaceStats which tracks every non-loopback
 *     interface in a single /proc/net/dev read per tick.
 *
 * Data source: NetworkMonitor singleton from the wmdockplugin C++ extension.
 *
 * External properties are set by main.qml (standalone) or by
 * DockSlot.applySlotConfig() (embedded in WMDock).
 */
Item {
    id: root

    // -----------------------------------------------------------------------
    // External config props (set by main.qml or DockSlot.applySlotConfig)
    // -----------------------------------------------------------------------

    // List of interface names to show; empty = all non-loopback
    property var  externalIfaces:        []
    // true = cycle through interfaces on a timer; false = show all simultaneously
    property bool externalCycleMode:     true
    // Cycle interval in seconds
    property int  externalCycleInterval: 4

    // Show "NET" title text at top
    readonly property bool showTitle: Plasmoid.configuration.showTitle ?? true

    // -----------------------------------------------------------------------
    // Derived state
    // -----------------------------------------------------------------------

    // Non-loopback interfaces currently present AND in the configured selection
    property var effectiveIfaces: {
        const allNonLo = NetworkMonitor.interfaces.filter(function(i) {
            return !i.startsWith("lo")
        })
        if (!root.externalIfaces || root.externalIfaces.length === 0)
            return allNonLo
        return root.externalIfaces.filter(function(i) {
            return allNonLo.indexOf(i) >= 0
        })
    }

    // true = show scrolling graph for one interface; false = multi-interface list
    readonly property bool useSingleDisplay:
        root.effectiveIfaces.length <= 1 || root.externalCycleMode || root.manualBrowse

    // Current index into effectiveIfaces (incremented by cycle timer)
    property int cycleIndex: 0
    property bool manualBrowse: false

    // Name of the interface currently shown in single/cycle mode
    property string activeIface: {
        if (root.effectiveIfaces.length === 0) return ""
        return root.effectiveIfaces[root.cycleIndex % root.effectiveIfaces.length]
    }

    // Scrolling graph history (single/cycle mode only)
    property int histLen: 50
    property var rxHistory: []
    property var txHistory: []

    // -----------------------------------------------------------------------
    // Rate formatter (shared by both display modes)
    // -----------------------------------------------------------------------
    function fmtRate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + "MB/s"
        if (b >= 1024)    return (b / 1024).toFixed(0)    + "KB/s"
        return b.toFixed(0) + "B/s"
    }

    function cycleIface(delta) {
        if (root.effectiveIfaces.length <= 1)
            return false
        if (!root.externalCycleMode)
            root.manualBrowse = true
        root.cycleIndex = (root.cycleIndex + delta + root.effectiveIfaces.length)
                          % root.effectiveIfaces.length
        return true
    }

    // -----------------------------------------------------------------------
    // React to active-interface changes (switch or initial load)
    // -----------------------------------------------------------------------
    onActiveIfaceChanged: {
        NetworkMonitor.setIface(root.activeIface)
        root.rxHistory = []
        root.txHistory = []
    }

    onUseSingleDisplayChanged: {
        root.rxHistory = []
        root.txHistory = []
        if (root.useSingleDisplay)
            NetworkMonitor.setIface(root.activeIface)
        graph.requestPaint()
    }

    onExternalCycleModeChanged: {
        if (root.externalCycleMode)
            root.manualBrowse = false
    }

    onEffectiveIfacesChanged: {
        if (root.effectiveIfaces.length <= 1)
            root.manualBrowse = false
        if (root.effectiveIfaces.length === 0) {
            root.cycleIndex = 0
            return
        }
        root.cycleIndex = root.cycleIndex % root.effectiveIfaces.length
    }

    Component.onCompleted: {
        NetworkMonitor.setIface(root.activeIface)
        Qt.callLater(function() { graph.requestPaint() })
    }

    // -----------------------------------------------------------------------
    // Auto-cycle timer (mirrors WMGPU cycle pattern)
    // -----------------------------------------------------------------------
    Timer {
        interval: Math.max(1, root.externalCycleInterval) * 1000
        repeat:   true
        running:  root.externalCycleMode && root.effectiveIfaces.length > 1
        onTriggered: {
            root.cycleIndex = (root.cycleIndex + 1) % root.effectiveIfaces.length
        }
    }

    // -----------------------------------------------------------------------
    // NetworkMonitor connections
    // -----------------------------------------------------------------------
    Connections {
        target: NetworkMonitor

        function onInterfacesChanged() {
            // effectiveIfaces recomputes automatically; re-assert our preference
            if (root.useSingleDisplay && root.activeIface !== "")
                NetworkMonitor.setIface(root.activeIface)
        }

        function onStatsChanged() {
            if (!root.useSingleDisplay) return   // multi mode: bindings auto-update

            // Belt-and-suspenders: re-assert if the active interface drifted
            if (root.activeIface !== "" && NetworkMonitor.iface !== root.activeIface)
                NetworkMonitor.setIface(root.activeIface)

            const rx = NetworkMonitor.rxBytesPerSec
            const tx = NetworkMonitor.txBytesPerSec
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
    // Mouse-wheel: manually cycle the active interface
    // -----------------------------------------------------------------------
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheelEvent) {
            if (root.externalCycleMode || root.effectiveIfaces.length < 2) {
                wheelEvent.accepted = false
                return
            }
            const delta = wheelEvent.angleDelta.y < 0 ? 1 : -1
            wheelEvent.accepted = root.cycleIface(delta)
        }
    }

    // -----------------------------------------------------------------------
    // Background (shared)
    // -----------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    // -----------------------------------------------------------------------
    // Title
    // -----------------------------------------------------------------------
    Text {
        id: titleText
        visible: root.showTitle
        anchors {
            top:        parent.top
            left:       parent.left
            right:      parent.right
            topMargin:  2
            leftMargin: 3
            rightMargin: 3
        }
        text: "NET"
        color: "#00aaff"
        font { pixelSize: parent.height * 0.12; family: "monospace"; bold: true }
        horizontalAlignment: Text.AlignHCenter
        height: visible ? implicitHeight : 0
    }

    // Interface name shown below NET title (single/cycle mode only)
    Text {
        id: ifaceText
        visible: root.showTitle && root.useSingleDisplay && root.activeIface !== ""
        anchors {
            top:        titleText.bottom
            left:       parent.left
            right:      parent.right
            leftMargin: 3
            rightMargin: 3
        }
        text: root.activeIface
        color: "#3377aa"
        font { pixelSize: parent.height * 0.09; family: "monospace" }
        horizontalAlignment: Text.AlignHCenter
        height: visible ? implicitHeight : 0
    }

    // -----------------------------------------------------------------------
    // Single / cycle mode: scrolling dual-channel graph
    // -----------------------------------------------------------------------
    Item {
        id: singleView
        visible: root.useSingleDisplay
        anchors {
            top:    root.showTitle ? (root.activeIface !== "" ? ifaceText.bottom : titleText.bottom) : parent.top
            left:   parent.left
            right:  parent.right
            bottom: parent.bottom
        }

        Canvas {
            id: graph
            anchors {
                top:          parent.top
                left:         parent.left
                right:        parent.right
                bottom:       rateRow.top
                topMargin:    2
                leftMargin:   3
                rightMargin:  3
                bottomMargin: 2
            }

            onWidthChanged:  Qt.callLater(requestPaint)
            onHeightChanged: Qt.callLater(requestPaint)

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

                // RX bars (green, upper half)
                for (let i = 0; i < rxH.length; i++) {
                    const pct = rxH[i] / maxR
                    const bh  = Math.max(1, Math.round(pct * (h / 2)))
                    ctx.fillStyle = "#00aa44"
                    ctx.fillRect(Math.round(i * bw), h - (h/2) - bh, Math.max(1, Math.floor(bw) - 1), bh)
                }
            }
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
                text: "↓" + root.fmtRate(NetworkMonitor.rxBytesPerSec)
                color: "#00aa44"
                font { pixelSize: singleView.height * 0.13; family: "monospace" }
            }
            Text {
                text: "↑" + root.fmtRate(NetworkMonitor.txBytesPerSec)
                color: "#4488ff"
                font { pixelSize: singleView.height * 0.13; family: "monospace" }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Multi-interface mode: compact per-interface rate list
    // -----------------------------------------------------------------------
    Item {
        id: multiView
        visible: !root.useSingleDisplay
        anchors {
            top:    root.showTitle ? titleText.bottom : parent.top  // multi-mode never shows ifaceText
            left:   parent.left
            right:  parent.right
            bottom: parent.bottom
        }

        Column {
            anchors { fill: parent; margins: 2 }
            spacing: 1
            clip: true

            // One row per effective interface; model is interface names (changes
            // rarely), so Repeater structure is stable across 1-second stat ticks.
            Repeater {
                model: root.effectiveIfaces

                // Each delegate is a two-line block: name + rates
                Item {
                    id: ifaceRow
                    width: parent.width
                    height: nameLabel.height + ratesLabel.height

                    // Reactive: re-reads allIfaceStats on every statsChanged tick
                    property var ifaceStat: {
                        const all = NetworkMonitor.allIfaceStats
                        for (var i = 0; i < all.length; i++) {
                            if (all[i].name === modelData) return all[i]
                        }
                        return { rxRate: 0, txRate: 0 }
                    }

                    Text {
                        id: nameLabel
                        anchors.top: parent.top
                        width: parent.width
                        text: modelData
                        color: "#00aaff"
                        font { pixelSize: root.height * 0.12; family: "monospace"; bold: true }
                        elide: Text.ElideRight
                    }
                    Row {
                        id: ratesLabel
                        anchors.top: nameLabel.bottom
                        spacing: 2
                        Text {
                            text: "↓" + root.fmtRate(ifaceRow.ifaceStat.rxRate)
                            color: "#00aa44"
                            font { pixelSize: root.height * 0.11; family: "monospace" }
                        }
                        Text {
                            text: "↑" + root.fmtRate(ifaceRow.ifaceStat.txRate)
                            color: "#4488ff"
                            font { pixelSize: root.height * 0.11; family: "monospace" }
                        }
                    }
                }
            }
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
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
    readonly property bool showTitle: Plasmoid.configuration.showTitle ?? true
    readonly property string loadAction: Plasmoid.configuration.loadAction || "disabled"
    readonly property bool loadClickToggles: loadAction === "clickToggleDrawer"
    property string externalOrientation: ""
    property bool loadInlineVisible: false
    property real _lastWheelToggleTime: 0

    readonly property bool isHorizontalDock: {
        if (externalOrientation === "vertical") return false
        if (externalOrientation === "horizontal") return true
        return Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    }

    readonly property url loadDisplaySource:
        Qt.resolvedUrl("../../../org.kde.plasma.wmload/contents/ui/Display.qml")

    // Core usage (array of 0–100 values)
    property var coreUsage: SystemMonitor.cpuCoreUsage

    onLoadActionChanged: {
        loadInlineVisible = false
        if (loadPopup.drawerOpen) loadPopup.closeDrawer()
    }

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
        visible: !root.loadInlineVisible
    }

    // -----------------------------------------------------------------------
    // Title
    // -----------------------------------------------------------------------
    Text {
        id: titleText
        visible: root.showTitle && !root.loadInlineVisible
        anchors {
            top:        parent.top
            left:       parent.left
            right:      parent.right
            topMargin:  2
            leftMargin: 3
            rightMargin: 3
        }
        text: "CPU"
        color: "#00aa44"
        font { pixelSize: parent.height * 0.12; family: "monospace"; bold: true }
        horizontalAlignment: Text.AlignHCenter
        height: visible ? implicitHeight : 0
    }

    // -----------------------------------------------------------------------
    // Per-core bars (thin strip at top)
    // -----------------------------------------------------------------------
    Canvas {
        id: coreBar
        visible: !root.loadInlineVisible
        anchors {
            top:         root.showTitle ? titleText.bottom : parent.top
            left:        parent.left
            right:       parent.right
            topMargin:   root.showTitle ? 1 : 3
            leftMargin:  3
            rightMargin: 3
        }
        height: Math.max(4, Math.ceil(SystemMonitor.cpuCoreCount / 4) * 4)

        onWidthChanged:  Qt.callLater(requestPaint)
        onHeightChanged: Qt.callLater(requestPaint)

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
        visible: !root.loadInlineVisible
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

        onWidthChanged:  Qt.callLater(requestPaint)
        onHeightChanged: Qt.callLater(requestPaint)

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
        visible: !root.loadInlineVisible
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

    Loader {
        id: inlineLoadLoader
        anchors.fill: parent
        active: root.loadAction === "wheelToggle" && root.loadInlineVisible
        visible: active
        source: root.loadDisplaySource
    }

    WheelHandler {
        enabled: root.loadAction === "wheelToggle"
        onWheel: function(event) {
            if (event.angleDelta.y === 0 && event.pixelDelta.y === 0) return
            const now = Date.now()
            if (now - root._lastWheelToggleTime < 250) {
                event.accepted = true
                return
            }
            root._lastWheelToggleTime = now
            root.loadInlineVisible = !root.loadInlineVisible
            event.accepted = true
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: root.loadAction === "clickDrawer" || root.loadAction === "clickToggleDrawer"
        onTapped: {
            if (loadPopup.drawerOpen || loadPopup.visible) {
                loadPopup.closeDrawer()
                return
            }
            loadPopup.openDrawer()
        }
    }

    PlasmaCore.Dialog {
        id: loadPopup
        visualParent: root
        location: root.isHorizontalDock
                    ? (Plasmoid.location === PlasmaCore.Types.TopEdge
                       ? PlasmaCore.Types.TopEdge : PlasmaCore.Types.BottomEdge)
                    : (Plasmoid.location === PlasmaCore.Types.RightEdge
                       ? PlasmaCore.Types.RightEdge : PlasmaCore.Types.LeftEdge)
        flags: Qt.WindowDoesNotAcceptFocus
        hideOnWindowDeactivate: false
        visible: false

        property bool drawerOpen: false
        property bool drawerDetached: false

        function openDrawer() {
            drawerOpen = true
            opacity = 1
            visible = true
        }

        function closeDrawer() {
            drawerOpen = false
            drawerDetached = false
            visible = false
        }

        mainItem: Item {
            id: loadContent
            implicitWidth: root.width + (root.isHorizontalDock ? 0 : 18)
            implicitHeight: root.height + (root.isHorizontalDock ? 18 : 0)

            Rectangle {
                anchors.fill: parent
                color: "#1c1c1c"
                border.color: "#555"
                border.width: 1
                radius: 4
            }

            Rectangle {
                id: loadGrip
                z: 2
                width: root.isHorizontalDock ? parent.width : 18
                height: root.isHorizontalDock ? 18 : parent.height
                color: "#252525"
                border.color: "#555"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.isHorizontalDock ? "≡" : "⋮"
                    color: "#888"
                    font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    property point pressGlobal
                    property point pressWindow
                    onPressed: function(mouse) {
                        pressGlobal = loadGrip.mapToGlobal(mouse.x, mouse.y)
                        pressWindow = Qt.point(loadPopup.x, loadPopup.y)
                    }
                    onPositionChanged: function(mouse) {
                        if (!(mouse.buttons & Qt.LeftButton)) return
                        loadPopup.drawerDetached = true
                        var p = loadGrip.mapToGlobal(mouse.x, mouse.y)
                        loadPopup.x = pressWindow.x + p.x - pressGlobal.x
                        loadPopup.y = pressWindow.y + p.y - pressGlobal.y
                    }
                }
                Text {
                    z: 3
                    anchors { right: parent.right; top: parent.top; margins: 2 }
                    text: "×"
                    color: "#aaa"
                    font.pixelSize: 12
                    MouseArea { anchors.fill: parent; anchors.margins: -3; onClicked: loadPopup.closeDrawer() }
                }
            }

            Loader {
                anchors {
                    left: root.isHorizontalDock ? parent.left : loadGrip.right
                    right: parent.right
                    top: root.isHorizontalDock ? loadGrip.bottom : parent.top
                    bottom: parent.bottom
                    margins: 1
                }
                active: loadPopup.visible
                source: root.loadDisplaySource
            }
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0

Item {
    id: root

    readonly property string configuredGpu: Plasmoid.configuration.gpu || ""
    readonly property int cycleIntervalSec: Math.max(1, Plasmoid.configuration.cycleInterval || 4)
    readonly property real barLabelScale: 0.65
    readonly property bool showTitle: Plasmoid.configuration.showTitle ?? true

    property int gpuIndex: 0
    property var activeGpu: null

    function filteredGpus() {
        const all = GpuMonitor.gpus || []
        if (root.configuredGpu === "")
            return all
        return all.filter(function(g) { return g.key === root.configuredGpu })
    }

    function refreshActiveGpu() {
        const active = root.filteredGpus()
        if (active.length === 0) {
            root.gpuIndex = 0
            root.activeGpu = null
            return
        }

        if (root.gpuIndex >= active.length)
            root.gpuIndex = 0

        root.activeGpu = active[root.gpuIndex]
    }

    Component.onCompleted: root.refreshActiveGpu()

    Connections {
        target: GpuMonitor
        function onGpusChanged() {
            root.refreshActiveGpu()
        }
    }

    Timer {
        interval: root.cycleIntervalSec * 1000
        repeat: true
        running: root.configuredGpu === "" && root.filteredGpus().length > 1
        onTriggered: {
            const active = root.filteredGpus()
            if (active.length <= 1)
                return
            root.gpuIndex = (root.gpuIndex + 1) % active.length
            root.activeGpu = active[root.gpuIndex]
        }
    }

    function fmtMiB(bytes) {
        return (bytes / 1048576).toFixed(0) + " MiB"
    }

    function fmtGiB(bytes) {
        return (bytes / (1048576 * 1024)).toFixed(0) + "G"
    }

    function barColor(pct) {
        if (pct >= 90) return "#dd2200"
        if (pct >= 70) return "#cc7700"
        if (pct >= 50) return "#aaaa00"
        return "#00aa44"
    }

    Rectangle {
        anchors.fill: parent
        color: "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    Text {
        id: nameText
        visible: root.showTitle
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 2
            leftMargin: 3
            rightMargin: 3
        }
        text: root.activeGpu ? root.activeGpu.name : i18n("No GPU detected")
        color: "#888"
        font { pixelSize: parent.height * 0.10; family: "monospace" }
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        height: visible ? implicitHeight : 0
    }

    // GPU load bar
    Rectangle {
        id: loadBarBg
        anchors {
            top: root.showTitle ? nameText.bottom : parent.top
            left: parent.left
            right: parent.right
            topMargin: 4
            leftMargin: 5
            rightMargin: 5
        }
        height: parent.height * 0.18
        color: "#0a1a0a"
        radius: 1

        Rectangle {
            readonly property real loadPct: (root.activeGpu && root.activeGpu.hasBusy) ? root.activeGpu.busyPercent : 0
            width: (loadPct / 100) * parent.width
            height: parent.height
            radius: parent.radius
            color: root.barColor(loadPct)
            Behavior on width { NumberAnimation { duration: 250 } }
        }

        Text {
            anchors.centerIn: parent
            text: (root.activeGpu && root.activeGpu.hasBusy)
                  ? ("Load " + root.activeGpu.busyPercent.toFixed(0) + "%")
                  : i18n("Load N/A")
            color: "#fff"
            font { pixelSize: parent.height * root.barLabelScale; family: "monospace"; bold: true }
        }
    }

    // VRAM bar
    Rectangle {
        id: vramBarBg
        anchors {
            top: loadBarBg.bottom
            left: parent.left
            right: parent.right
            topMargin: 4
            leftMargin: 5
            rightMargin: 5
        }
        height: parent.height * 0.18
        color: "#0a0f1a"
        radius: 1

        Rectangle {
            readonly property real vramPct: (root.activeGpu && root.activeGpu.hasVram) ? root.activeGpu.vramPercent : 0
            width: (vramPct / 100) * parent.width
            height: parent.height
            radius: parent.radius
            color: "#4466dd"
            Behavior on width { NumberAnimation { duration: 250 } }
        }

        Text {
            anchors.centerIn: parent
            text: (root.activeGpu && root.activeGpu.hasVram)
                  ? ("VRAM " + root.activeGpu.vramPercent.toFixed(0) + "%")
                  : i18n("VRAM N/A")
            color: "#fff"
            font { pixelSize: parent.height * root.barLabelScale; family: "monospace"; bold: true }
        }
    }

    Text {
        anchors {
            top: vramBarBg.bottom
            left: parent.left
            right: parent.right
            topMargin: 4
            leftMargin: 4
            rightMargin: 4
        }
        text: (root.activeGpu && root.activeGpu.hasVram)
              ? (root.fmtGiB(root.activeGpu.vramUsedBytes) + "/" + root.fmtGiB(root.activeGpu.vramTotalBytes))
              : ""
        color: "#77aaff"
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font { pixelSize: parent.height * 0.12; family: "monospace" }
    }

    TapHandler {
        onTapped: {
            const active = root.filteredGpus()
            if (active.length <= 1)
                return
            root.gpuIndex = (root.gpuIndex + 1) % active.length
            root.activeGpu = active[root.gpuIndex]
        }
    }
}

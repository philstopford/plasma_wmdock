// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.wmdock 1.0
import QtMultimedia

/**
 * WMPlay – Compact audio player applet.
 *
 * Supports MP3, M4A, FLAC, OGG, WAV and other formats via Qt Multimedia.
 * Files and folders can be loaded by dragging them onto the widget.
 * A simple internal playlist is maintained in order.
 *
 * Controls:
 *   ▶/⏸  left-click the play area or press play button
 *   ⏮⏭   previous / next track buttons
 *   ⏹    stop button
 *   scroll wheel on progress bar → seek ±5 s
 *   scroll wheel on widget → previous / next track
 *
 * Folder drop: uses MediaScanner C++ singleton to enumerate audio files.
 */
Item {
    id: root

    // ----- playlist --------------------------------------------------------
    property var  playlist:      []   // array of "file:///…" URL strings
    property int  currentIndex:  -1

    function loadTrack(idx) {
        if (idx < 0 || idx >= root.playlist.length) return
        root.currentIndex = idx
        player.source    = root.playlist[idx]
        player.play()
    }

    function addPaths(paths) {
        // paths: array of local absolute file paths
        let newList = root.playlist.slice()
        for (let i = 0; i < paths.length; i++) {
            const url = paths[i].startsWith("file://") ? paths[i]
                                                       : "file://" + paths[i]
            if (!newList.includes(url))
                newList.push(url)
        }
        root.playlist = newList
        if (root.currentIndex < 0 && newList.length > 0)
            root.loadTrack(0)
    }

    // Short display name from URL
    function trackName(url) {
        if (!url) return "—"
        const s = url.toString()
        const slash = s.lastIndexOf("/")
        const name  = slash >= 0 ? s.substring(slash + 1) : s
        // Strip common audio extensions
        return name.replace(/\.(mp3|m4a|flac|ogg|opus|wav|aac|wma|ape|aiff|mp4)$/i, "")
                   .replace(/%20/g, " ")
    }

    // ----- Qt Multimedia ---------------------------------------------------
    MediaPlayer {
        id: player
        audioOutput: AudioOutput { id: audioOut; volume: 1.0 }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                // auto-advance to next track
                if (root.currentIndex + 1 < root.playlist.length)
                    root.loadTrack(root.currentIndex + 1)
            }
        }
    }

    // ----- background ------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#000"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    // ----- title bar -------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 2 }
        text: "PLAY"
        color: "#00aaff"
        font { pixelSize: parent.height * 0.11; family: "monospace"; bold: true }
    }

    // ----- scrolling track name --------------------------------------------
    Item {
        id: trackRow
        anchors {
            top: titleText.bottom; topMargin: 2
            left: parent.left; right: parent.right
            leftMargin: 3; rightMargin: 3
        }
        height: parent.height * 0.14
        clip: true

        // Named constant for scroll speed (ms per pixel of overflow)
        readonly property int scrollSpeedMsPerPx: 25

        Text {
            id: trackLabel
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: root.currentIndex >= 0
                  ? root.trackName(root.playlist[root.currentIndex])
                  : i18n("Drop files here")
            color: "#88ccff"
            font { pixelSize: parent.height * 0.72; family: "monospace" }
            // Scroll text when too long
            property real offset: 0
            x: -offset
            NumberAnimation on offset {
                id: scrollAnim
                running: trackLabel.implicitWidth > trackRow.width
                loops:  Animation.Infinite
                from:   0
                to:     Math.max(0, trackLabel.implicitWidth - trackRow.width + 8)
                duration: Math.max(2000, (trackLabel.implicitWidth - trackRow.width) * trackRow.scrollSpeedMsPerPx)
                onStopped: trackLabel.offset = 0
            }
        }
    }

    // ----- progress bar ----------------------------------------------------
    Rectangle {
        id: progressBg
        anchors {
            top: trackRow.bottom; topMargin: 2
            left: parent.left; right: parent.right
            leftMargin: 3; rightMargin: 3
        }
        height: 4
        color: "#111"
        radius: 2

        Rectangle {
            width: player.duration > 0
                   ? parent.width * player.position / player.duration
                   : 0
            height: parent.height
            color:  "#0077dd"
            radius: parent.radius
            Behavior on width { NumberAnimation { duration: 200 } }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const seek = player.position + (event.angleDelta.y > 0 ? 5000 : -5000)
                player.position = Math.max(0, Math.min(player.duration, seek))
            }
        }
    }

    // ----- time readout ----------------------------------------------------
    Text {
        id: timeText
        anchors {
            top: progressBg.bottom; topMargin: 1
            horizontalCenter: parent.horizontalCenter
        }
        function fmt(ms) {
            const s = Math.floor(ms / 1000)
            const m = Math.floor(s / 60)
            return m + ":" + String(s % 60).padStart(2, "0")
        }
        text: fmt(player.position) + "/" + fmt(player.duration)
        color: "#446688"
        font { pixelSize: parent.height * 0.09; family: "monospace" }
    }

    // ----- transport controls ----------------------------------------------
    Row {
        id: controls
        anchors {
            bottom: parent.bottom; bottomMargin: 3
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 4

        // Previous
        Text {
            text: "⏮"
            color: "#0088cc"
            font.pixelSize: root.height * 0.14
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.currentIndex > 0)
                        root.loadTrack(root.currentIndex - 1)
                }
            }
        }

        // Play/Pause
        Text {
            text: player.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
            color: "#00ccff"
            font.pixelSize: root.height * 0.17
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (player.playbackState === MediaPlayer.PlayingState)
                        player.pause()
                    else if (player.playbackState === MediaPlayer.PausedState)
                        player.play()
                    else if (root.playlist.length > 0)
                        root.loadTrack(Math.max(0, root.currentIndex))
                }
            }
        }

        // Stop
        Text {
            text: "⏹"
            color: "#cc4400"
            font.pixelSize: root.height * 0.14
            MouseArea {
                anchors.fill: parent
                onClicked: { player.stop(); root.currentIndex = -1 }
            }
        }

        // Next
        Text {
            text: "⏭"
            color: "#0088cc"
            font.pixelSize: root.height * 0.14
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.currentIndex + 1 < root.playlist.length)
                        root.loadTrack(root.currentIndex + 1)
                }
            }
        }
    }

    // ----- scroll wheel: change track --------------------------------------
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const dir = event.angleDelta.y < 0 ? 1 : -1
            const next = root.currentIndex + dir
            if (next >= 0 && next < root.playlist.length)
                root.loadTrack(next)
        }
    }

    // ----- drag-and-drop ---------------------------------------------------
    DropArea {
        anchors.fill: parent
        onEntered: function(drag) {
            drag.accepted = drag.hasUrls
        }

        onDropped: function(drop) {
            if (!drop.hasUrls) {
                drop.accepted = false
                return
            }
            const urls = drop.urls
            let paths = []
            for (let i = 0; i < urls.length; i++) {
                // Convert dropped URL to local path for MediaScanner
                let p = ""
                if (urls[i] && urls[i].toLocalFile)
                    p = urls[i].toLocalFile()
                if (!p) {
                    p = urls[i].toString()
                    if (p.startsWith("file://"))
                        p = decodeURIComponent(p.substring(7))
                }
                if (!p)
                    continue
                const scanned = MediaScanner.scan(p)
                for (let j = 0; j < scanned.length; j++)
                    paths.push(scanned[j])
            }
            if (paths.length > 0)
                root.addPaths(paths)
            drop.accepted = true
        }
    }
}

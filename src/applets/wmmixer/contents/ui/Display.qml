// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.private.wmdock 1.0

/**
 * WMMixer – Audio volume control applet.
 *
 * Displays a vertical LED bar showing current volume, a mute indicator,
 * and responds to mouse-wheel scrolling and click-to-mute.
 * Styled after the classic wmmixer dockapp.
 */
Item {
    id: root

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
    // Title
    // -----------------------------------------------------------------------
    Text {
        id: titleText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 2 }
        text: "VOL"
        color: AudioManager.available ? "#ffaa00" : "#444"
        font { pixelSize: parent.height * 0.12; family: "monospace"; bold: true }
    }

    // -----------------------------------------------------------------------
    // LED bar (Canvas)
    // -----------------------------------------------------------------------
    Canvas {
        id: volCanvas
        anchors {
            top:         titleText.bottom
            left:        parent.left
            right:       parent.right
            bottom:      muteLabel.top
            topMargin:   3
            leftMargin:  10
            rightMargin: 10
            bottomMargin: 3
        }
        antialiasing: false

        Connections {
            target: AudioManager
            function onVolumeChanged() { volCanvas.requestPaint() }
            function onMutedChanged()  { volCanvas.requestPaint() }
        }

        onPaint: {
            const ctx  = getContext("2d")
            const w    = width, h = height
            ctx.clearRect(0, 0, w, h)

            const vol    = AudioManager.volume          // 0–150 (PA allows over 100)
            const muted  = AudioManager.muted
            const avail  = AudioManager.available
            const nLEDs  = 20
            const ledH   = (h - nLEDs + 1) / nLEDs
            const ledW   = w

            for (let i = 0; i < nLEDs; i++) {
                const pct     = (nLEDs - 1 - i) / (nLEDs - 1)   // 0=bottom,1=top
                const active  = avail && !muted && (vol / 100) >= pct
                const ledCol  = muted  ? "#330000"
                              : !avail  ? "#111"
                              : pct > 0.85 ? (active ? "#ff2200" : "#220000")
                              : pct > 0.65 ? (active ? "#ffaa00" : "#221100")
                              :               (active ? "#00cc44" : "#001a00")

                const y = i * (ledH + 1)
                ctx.fillStyle = ledCol
                ctx.fillRect(0, y, ledW, Math.max(1, ledH))
            }

            // Knob position line
            if (avail && !muted) {
                const ky = (1 - vol / 100) * h
                ctx.fillStyle   = "#ffffff"
                ctx.fillRect(0, Math.round(ky) - 1, w, 2)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Mute / percentage label
    // -----------------------------------------------------------------------
    Text {
        id: muteLabel
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 2
        }
        text: !AudioManager.available    ? "N/A"
            : AudioManager.muted         ? "MUTE"
            : AudioManager.volume + "%"
        color: AudioManager.muted ? "#ff3333" : "#ffaa00"
        font { pixelSize: parent.height * 0.13; family: "monospace"; bold: true }
    }

    // -----------------------------------------------------------------------
    // Mouse interactions
    // -----------------------------------------------------------------------
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const step = 3
            AudioManager.setVolume(AudioManager.volume + (event.angleDelta.y > 0 ? step : -step))
        }
    }

    TapHandler {
        onTapped: AudioManager.toggleMute()
    }
}

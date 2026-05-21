// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.private.wmdock 1.0

/**
 * WMEyes – Mouse-tracking eyes applet.
 *
 * Two eyes follow the global cursor position, just like the classic
 * xeyes / wmeyes dockapp.  Cursor position is obtained from the
 * CursorTracker C++ singleton (polls QCursor::pos every 50 ms).
 *
 * Each eye is drawn with a Canvas: white sclera, coloured iris, and a
 * pupil that moves toward the cursor within the eye bounds.
 */
Item {
    id: root

    // Map global cursor coordinates to local (applet-relative) coordinates.
    // mapFromGlobal is available in Qt 6 QML.
    function localPos() {
        return root.mapFromGlobal(CursorTracker.cursorX, CursorTracker.cursorY)
    }

    // ----- pupil position for one eye -----------------------------------------
    // eyeCx/Cy: eye centre in local coords
    // eyeR:     eye outer radius
    // Returns {x, y} for the pupil centre, clamped within the iris area.
    function pupilPos(eyeCx, eyeCy, eyeR) {
        const p    = root.localPos()
        const dx   = p.x - eyeCx
        const dy   = p.y - eyeCy
        const dist = Math.sqrt(dx * dx + dy * dy)
        const maxD = eyeR * 0.40     // how far the pupil travels
        if (dist < 0.5)
            return { x: eyeCx, y: eyeCy }
        const clamp = Math.min(dist, maxD) / dist
        return {
            x: eyeCx + dx * clamp,
            y: eyeCy + dy * clamp
        }
    }

    // ----- background -----------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color:  "#1a1a1a"
        radius: 2
        border.color: "#2a2a2a"
        border.width: 1
    }

    // ----- left eye -------------------------------------------------------------
    Canvas {
        id: leftEye
        x: parent.width  * 0.08
        y: parent.height * 0.12
        width:  parent.width  * 0.40
        height: parent.height * 0.76

        Connections {
            target: CursorTracker
            function onPositionChanged() { leftEye.requestPaint() }
        }

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx  = getContext("2d")
            const cx   = width  / 2
            const cy   = height / 2
            const rx   = width  / 2 - 1
            const ry   = height / 2 - 1
            ctx.clearRect(0, 0, width, height)

            // Sclera (white)
            ctx.beginPath()
            ctx.ellipse(1, 1, width - 2, height - 2)
            ctx.fillStyle = "#e8e8e8"
            ctx.fill()
            ctx.strokeStyle = "#555"
            ctx.lineWidth   = 1
            ctx.stroke()

            // Iris
            const irisR = Math.min(rx, ry) * 0.45
            ctx.beginPath()
            ctx.arc(cx, cy, irisR, 0, 2 * Math.PI)
            ctx.fillStyle   = "#3366cc"
            ctx.fill()

            // Pupil
            const gCx = root.width  * 0.08 + cx
            const gCy = root.height * 0.12 + cy
            const pp  = root.pupilPos(gCx, gCy, Math.min(rx, ry))
            const pupR = irisR * 0.55
            ctx.beginPath()
            ctx.arc(pp.x - (root.width * 0.08 + cx) + cx,
                    pp.y - (root.height * 0.12 + cy) + cy,
                    pupR, 0, 2 * Math.PI)
            ctx.fillStyle = "#000"
            ctx.fill()

            // Highlight
            ctx.beginPath()
            ctx.arc(pp.x - (root.width * 0.08 + cx) + cx - pupR * 0.3,
                    pp.y - (root.height * 0.12 + cy) + cy - pupR * 0.3,
                    pupR * 0.25, 0, 2 * Math.PI)
            ctx.fillStyle = "rgba(255,255,255,0.7)"
            ctx.fill()
        }
    }

    // ----- right eye ------------------------------------------------------------
    Canvas {
        id: rightEye
        x: parent.width  * 0.52
        y: parent.height * 0.12
        width:  parent.width  * 0.40
        height: parent.height * 0.76

        Connections {
            target: CursorTracker
            function onPositionChanged() { rightEye.requestPaint() }
        }

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx  = getContext("2d")
            const cx   = width  / 2
            const cy   = height / 2
            const rx   = width  / 2 - 1
            const ry   = height / 2 - 1
            ctx.clearRect(0, 0, width, height)

            // Sclera (white)
            ctx.beginPath()
            ctx.ellipse(1, 1, width - 2, height - 2)
            ctx.fillStyle = "#e8e8e8"
            ctx.fill()
            ctx.strokeStyle = "#555"
            ctx.lineWidth   = 1
            ctx.stroke()

            // Iris
            const irisR = Math.min(rx, ry) * 0.45
            ctx.beginPath()
            ctx.arc(cx, cy, irisR, 0, 2 * Math.PI)
            ctx.fillStyle   = "#3366cc"
            ctx.fill()

            // Pupil
            const gCx = root.width  * 0.52 + cx
            const gCy = root.height * 0.12 + cy
            const pp  = root.pupilPos(gCx, gCy, Math.min(rx, ry))
            const pupR = irisR * 0.55
            ctx.beginPath()
            ctx.arc(pp.x - (root.width * 0.52 + cx) + cx,
                    pp.y - (root.height * 0.12 + cy) + cy,
                    pupR, 0, 2 * Math.PI)
            ctx.fillStyle = "#000"
            ctx.fill()

            // Highlight
            ctx.beginPath()
            ctx.arc(pp.x - (root.width * 0.52 + cx) + cx - pupR * 0.3,
                    pp.y - (root.height * 0.12 + cy) + cy - pupR * 0.3,
                    pupR * 0.25, 0, 2 * Math.PI)
            ctx.fillStyle = "rgba(255,255,255,0.7)"
            ctx.fill()
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.wmdock 1.0

/**
 * WMDrawer – Application launcher drawer button.
 *
 * Displays a single dock button. Left-click opens a strip of launcher
 * buttons, each matching the drawer button's own size.
 *
 * Orientation: for a horizontal dock the strip opens vertically; for a
 * vertical dock the strip opens horizontally.
 *
 * Opening effects are selectable: instant, slide, or fade.
 *
 * Launchers can be drag-reordered inside the open strip.
 *
 * Drag-and-drop creation: dragging a .desktop file onto the button
 * auto-opens the drawer after 600 ms; releasing over the button appends
 * the launcher to the end of the list.  Dropping onto the open popup
 * inserts at the position closest to the drop point.
 *
 * Configuration (when embedded in WMDock) is supplied via external*
 * properties injected by DockSlot.  When used as a standalone plasmoid
 * the values come from Plasmoid.configuration.
 */
Item {
    id: root

    // -----------------------------------------------------------------------
    // External config (injected by DockSlot when embedded in WMDock)
    // -----------------------------------------------------------------------
    property string externalDrawerIcon:  ""
    property string externalDrawerLabel: ""
    property var    externalLaunchers:   null   // array of {command,icon,label}
    property string externalOrientation: ""     // "horizontal" or "vertical"

    // Emitted after a drag-reorder so the dock can persist the new order.
    signal launchersReordered(var newLaunchers)

    // -----------------------------------------------------------------------
    // Resolved configuration
    // -----------------------------------------------------------------------
    property string drawerIcon:  externalDrawerIcon  || Plasmoid.configuration.drawerIcon  || "folder"
    property string drawerLabel: externalDrawerLabel || Plasmoid.configuration.drawerLabel || "Apps"
    property var    launchers: {
        if (externalLaunchers !== null) return externalLaunchers
        try { return JSON.parse(Plasmoid.configuration.launchersJson) }
        catch(e) { return [] }
    }

    // True when the parent dock sits on a horizontal edge (top/bottom).
    // Falls back to Plasmoid.location when running standalone.
    //   Plasma 6: 5 = LeftEdge, 6 = RightEdge → vertical dock
    //   3 = TopEdge, 4 = BottomEdge, 0 = Floating → horizontal dock
    readonly property bool isHorizontalDock: {
        if (externalOrientation === "vertical")   return false
        if (externalOrientation === "horizontal") return true
        return Plasmoid.location !== 5 && Plasmoid.location !== 6
    }

    readonly property string openEffect: Plasmoid.configuration.openEffect || "slide"

    property bool pressed: false

    // -----------------------------------------------------------------------
    // Save reordered launchers back to the appropriate store.
    // Called when a drag-reorder completes.
    // -----------------------------------------------------------------------
    function saveLaunchersFromModel() {
        var arr = []
        for (var i = 0; i < launcherModel.count; i++) {
            var item = launcherModel.get(i)
            arr.push({ command: item.command, icon: item.icon, label: item.label })
        }
        if (root.externalLaunchers !== null) {
            root.launchersReordered(arr)
        } else {
            Plasmoid.configuration.launchersJson = JSON.stringify(arr)
        }
    }

    // -----------------------------------------------------------------------
    // Desktop-file drag-and-drop helper
    // -----------------------------------------------------------------------

    // Process a list of dropped URLs: read each .desktop file via the C++
    // DesktopFileReader singleton (which uses QFile, avoiding QML sandbox
    // restrictions on file:// XHR) and insert the resulting launcher entries
    // starting at insertIndex.  Pass insertIndex < 0 to append at the end.
    // Multiple files are inserted consecutively at successive positions.
    function addLauncherFromUrls(urls, insertIndex) {
        // Collect all valid entries synchronously before mutating state.
        var entries = []
        for (var i = 0; i < urls.length; i++) {
            var url = urls[i].toString()
            if (!url.toLowerCase().endsWith(".desktop")) continue
            var entry = DesktopFileReader.read(url)
            if (entry && entry.command) entries.push(entry)
        }
        if (entries.length === 0) return

        if (drawerPopup.drawerOpen) {
            var ins = (insertIndex >= 0 && insertIndex <= launcherModel.count)
                      ? insertIndex : launcherModel.count
            for (var j = 0; j < entries.length; j++) {
                launcherModel.insert(ins + j, entries[j])
            }
            root.saveLaunchersFromModel()
        } else {
            var arr = root.launchers ? root.launchers.slice() : []
            var pos = (insertIndex >= 0 && insertIndex <= arr.length)
                      ? insertIndex : arr.length
            for (var k = 0; k < entries.length; k++) {
                arr.splice(pos + k, 0, entries[k])
            }
            if (root.externalLaunchers !== null) {
                root.launchersReordered(arr)
            } else {
                Plasmoid.configuration.launchersJson = JSON.stringify(arr)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Timer: auto-open the drawer when a drag lingers over the button.
    // -----------------------------------------------------------------------
    Timer {
        id: hoverOpenTimer
        interval: 600
        repeat: false
        onTriggered: { if (!drawerPopup.drawerOpen && !drawerPopup.visible) drawerPopup.openDrawer() }
    }

    // -----------------------------------------------------------------------
    // Drawer button body
    // -----------------------------------------------------------------------
    Rectangle {
        id: buttonBody
        anchors { fill: parent; margins: pressed ? 2 : 1 }
        color:   pressed ? "#111" : "#1e1e1e"
        radius:  4
        border.color: pressed ? "#333" : (buttonDropArea.containsDrag ? "#5599ff" : "#666")
        border.width: 1

        Behavior on anchors.margins { NumberAnimation { duration: 60 } }
        Behavior on color           { ColorAnimation  { duration: 60 } }

        Rectangle {
            visible: !pressed
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1
            color: "#888"
            radius: parent.radius
        }
        Rectangle {
            visible: !pressed
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: "#222"
            radius: parent.radius
        }
    }

    // -----------------------------------------------------------------------
    // Drawer icon
    // -----------------------------------------------------------------------
    Kirigami.Icon {
        id: drawerIconItem
        anchors {
            horizontalCenter: parent.horizontalCenter
            top:    parent.top
            bottom: drawerLabelText.visible ? drawerLabelText.top : parent.bottom
            topMargin:    6
            bottomMargin: 2
        }
        width:  height
        source: drawerIcon
        isMask: false
    }

    // Returns the indicator arrow for the current open/close and orientation state.
    function _arrowText(open) {
        if (root.isHorizontalDock) return open ? "\u25B2" : "\u25BC"  // ▲ / ▼
        // Vertical dock: arrow points away from the panel edge
        return (Plasmoid.location === 6) === open ? "\u25BA" : "\u25C4"  // ► / ◄
    }

    // Small open/close indicator arrow
    Text {
        anchors {
            bottom: drawerIconItem.bottom
            right:  drawerIconItem.right
        }
        text:  root._arrowText(drawerPopup.visible)
        color: "#aaaaaa"
        font.pixelSize: Math.max(8, parent.height * 0.12)
    }

    // -----------------------------------------------------------------------
    // Drawer label
    // -----------------------------------------------------------------------
    Text {
        id: drawerLabelText
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 3
        }
        visible: drawerLabel.length > 0
        text:    drawerLabel
        color:   "#cccccc"
        font { pixelSize: parent.height * 0.12; family: "monospace" }
        elide:   Text.ElideRight
        width:   parent.width - 6
        horizontalAlignment: Text.AlignHCenter
    }

    // -----------------------------------------------------------------------
    // Click interaction
    // -----------------------------------------------------------------------
    TapHandler {
        id: tapHandler
        acceptedButtons: Qt.LeftButton
        onPressedChanged: root.pressed = tapHandler.pressed
        onTapped: {
            // If the drawer is open or still animating closed, close it on a tap.
            if (drawerPopup.drawerOpen || drawerPopup.visible) {
                drawerPopup.closeDrawer()
                return
            }
            drawerPopup.openDrawer()
        }
    }

    QQC2.ToolTip {
        visible: hoverHandler.hovered && !drawerPopup.visible
        text:    root.drawerLabel
        delay:   700
    }
    HoverHandler { id: hoverHandler }

    // -----------------------------------------------------------------------
    // Drop-area on the drawer button: hover-to-open + drop-to-add launcher.
    //
    // Hovering with a drag for ≥ 600 ms auto-opens the drawer so the user
    // can drop onto a specific slot. Releasing the drag directly on the
    // button (without moving to the popup) appends the launcher(s) at the
    // end of the list.
    // -----------------------------------------------------------------------
    DropArea {
        id: buttonDropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: hoverOpenTimer.start()
        onExited:  hoverOpenTimer.stop()
        onDropped: function(drop) {
            hoverOpenTimer.stop()
            drop.acceptProposedAction()
            root.addLauncherFromUrls(drop.urls, -1)
        }
    }

    // -----------------------------------------------------------------------
    // Launcher model – populated on each open so a previous reorder is
    // reflected without requiring a re-parse of the config.
    // -----------------------------------------------------------------------
    ListModel { id: launcherModel }

    // -----------------------------------------------------------------------
    // Drawer window – uses a non-modal top-level tool window so it can appear
    // outside the panel bounds without grabbing clicks from other applets.
    // -----------------------------------------------------------------------
    Window {
        id: drawerPopup

        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        modality: Qt.NonModal
        color: "transparent"
        visible: false

        // Open/closed state set by openDrawer()/closeDrawer() and synchronized
        // if the window is hidden externally.
        property bool drawerOpen: false

        onVisibleChanged: {
            if (!visible) {
                drawerOpen = false
            }
        }

        // Saved so closeDrawer() can animate back to the button.
        property real _hiddenPos: 0    // y (horiz dock) or x (vert dock)
        property real _targetPos: 0   // y (horiz dock) or x (vert dock)
        property real _fixedX:    0   // fixed x when sliding vertically
        property real _fixedY:    0   // fixed y when sliding horizontally

        // --- Animations ---------------------------------------------------
        NumberAnimation {
            id: fadeInAnim
            target: drawerPopup; property: "opacity"
            from: 0; to: 1; duration: 200; easing.type: Easing.InQuad
        }
        SequentialAnimation {
            id: fadeOutAnim
            NumberAnimation {
                target: drawerPopup; property: "opacity"
                to: 0; duration: 200; easing.type: Easing.OutQuad
            }
            ScriptAction { script: drawerPopup.visible = false }
        }
        PropertyAnimation {
            id: slideInAnim
            target: drawerPopup; duration: 200; easing.type: Easing.OutQuad
        }
        SequentialAnimation {
            id: slideOutAnim
            PropertyAnimation {
                id: slideOutPropAnim
                target: drawerPopup; duration: 200; easing.type: Easing.InQuad
            }
            ScriptAction { script: drawerPopup.visible = false }
        }

        // --- Open / close -------------------------------------------------
        function openDrawer() {
            fadeOutAnim.stop()
            slideOutAnim.stop()
            drawerOpen = true
            // Rebuild model from current launcher list
            launcherModel.clear()
            var ls = root.launchers
            for (var i = 0; i < ls.length; i++) {
                launcherModel.append({
                    command: ls[i].command || "",
                    icon:    ls[i].icon    || "application-x-executable",
                    label:   ls[i].label   || ls[i].command || "Launch"
                })
            }

            var n    = Math.max(1, ls.length)
            var cellW = root.width
            var cellH = root.height
            var popW  = root.isHorizontalDock ? cellW      : cellW * n
            var popH  = root.isHorizontalDock ? cellH * n  : cellH

            width  = popW
            height = popH

            var btnPos = root.mapToGlobal(0, 0)
            var scr    = root.Screen
            var targetX, targetY

            if (root.isHorizontalDock) {
                targetX = btnPos.x
                if (btnPos.y - popH - 4 >= scr.virtualY) {
                    targetY    = btnPos.y - popH - 4
                    _hiddenPos = btnPos.y - 4  // popup bottom at button's top
                } else {
                    targetY    = btnPos.y + root.height + 4
                    _hiddenPos = targetY - popH  // popup top at button's bottom
                }
                _targetPos = targetY
                _fixedX    = targetX
            } else {
                targetY = btnPos.y
                if (Plasmoid.location === 6) {  // 6=RightEdge: popup to the left
                    targetX    = btnPos.x - popW - 4
                    _hiddenPos = btnPos.x - 4   // popup right edge at button's left
                } else {                         // LeftEdge: popup to the right
                    targetX    = btnPos.x + root.width + 4
                    _hiddenPos = targetX - popW  // popup left edge at button's right
                }
                _targetPos = targetX
                _fixedY    = targetY
            }

            // Clamp to current screen
            targetX = Math.max(scr.virtualX, Math.min(targetX, scr.virtualX + scr.width  - popW))
            targetY = Math.max(scr.virtualY, Math.min(targetY, scr.virtualY + scr.height - popH))

            var effect = root.openEffect
            if (effect === "fade") {
                x = targetX; y = targetY
                opacity = 0
                visible = true
                fadeInAnim.start()
            } else if (effect === "slide") {
                if (root.isHorizontalDock) {
                    x = targetX; y = _hiddenPos
                } else {
                    x = _hiddenPos; y = targetY
                }
                opacity = 1
                visible = true
                slideInAnim.property = root.isHorizontalDock ? "y" : "x"
                slideInAnim.from     = _hiddenPos
                slideInAnim.to       = root.isHorizontalDock ? targetY : targetX
                slideInAnim.start()
            } else {
                x = targetX; y = targetY
                opacity = 1
                visible = true
            }
        }

        function closeDrawer() {
            if (!visible) {
                drawerOpen = false
                return
            }
            fadeInAnim.stop()
            slideInAnim.stop()
            drawerOpen = false
            var effect = root.openEffect
            if (effect === "fade") {
                fadeOutAnim.start()
            } else if (effect === "slide") {
                slideOutPropAnim.property = root.isHorizontalDock ? "y" : "x"
                slideOutPropAnim.to       = _hiddenPos
                slideOutAnim.start()
            } else {
                visible = false
            }
        }

        // --- Background ---------------------------------------------------
        Rectangle {
            anchors.fill: parent
            color:        "#1c1c1c"
            border.color: "#555"
            border.width: 1
            radius: 4
        }

        // --- Launcher strip -----------------------------------------------
        ListView {
            id: launcherList
            anchors.fill: parent
            model:       launcherModel
            orientation: root.isHorizontalDock ? ListView.Vertical : ListView.Horizontal
            spacing:     0
            clip:        true
            interactive: false

            // Track the model index of the item currently being drag-reordered.
            property int draggedItemIndex: -1

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 80 }
            }

            delegate: Item {
                id: delItem

                // Make delegate index available to drag handler
                readonly property int delegateIndex: index

                width:  root.width
                height: root.height

                property bool itemPressed: false

                // Button background
                Rectangle {
                    anchors { fill: parent; margins: delItem.itemPressed ? 2 : 1 }
                    color:        delItem.itemPressed ? "#111" : "#252525"
                    radius:       3
                    border.color: delItem.itemPressed ? "#333" : "#555"
                    border.width: 1
                    Behavior on anchors.margins { NumberAnimation { duration: 60 } }
                    Behavior on color           { ColorAnimation  { duration: 60 } }
                }

                // Launcher icon
                Kirigami.Icon {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        bottom: itemLabel.top
                        topMargin:    5
                        bottomMargin: 1
                    }
                    width:  height
                    source: model.icon || "application-x-executable"
                    isMask: false
                }

                // Launcher label
                Text {
                    id: itemLabel
                    anchors {
                        bottom: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                        bottomMargin: 3
                    }
                    text:  model.label || model.command || "Launch"
                    color: "#cccccc"
                    font { pixelSize: 9; family: "monospace" }
                    elide: Text.ElideRight
                    width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter
                }

                // ----- Drag to reorder ------------------------------------
                DragHandler {
                    id: dragH
                    target: null
                    onActiveChanged: {
                        if (active) {
                            launcherList.draggedItemIndex = index
                        } else {
                            if (launcherList.draggedItemIndex >= 0) {
                                root.saveLaunchersFromModel()
                                launcherList.draggedItemIndex = -1
                            }
                        }
                    }
                    onCentroidChanged: {
                        if (!active) return
                        // Convert centroid to ListView-local coordinates, then
                        // compute which slot the drag is over and move the item.
                        var listPos  = launcherList.mapFromItem(
                                           delItem,
                                           dragH.centroid.position.x,
                                           dragH.centroid.position.y)
                        var cellSize = root.isHorizontalDock ? root.height : root.width
                        var coord    = root.isHorizontalDock ? listPos.y : listPos.x
                        var targetIdx = Math.floor(coord / cellSize)
                        targetIdx = Math.max(0, Math.min(targetIdx, launcherModel.count - 1))
                        if (targetIdx !== index) {
                            launcherModel.move(index, targetIdx, 1)
                        }
                    }
                }

                // ----- Launch on tap (only when not dragging) -------------
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onPressedChanged: delItem.itemPressed = pressed
                    onTapped: {
                        if (launcherList.draggedItemIndex < 0) {
                            var cmd = model.command || ""
                            if (cmd) ProcessLauncher.launch(cmd)
                        }
                    }
                }

                QQC2.ToolTip {
                    visible: itemHover.hovered && launcherList.draggedItemIndex < 0
                    text:    model.command || ""
                    delay:   700
                }
                HoverHandler { id: itemHover }
            }
        }

        // Empty-state message
        Text {
            anchors.centerIn: parent
            visible: launcherModel.count === 0
            text:    i18n("No launchers configured.\nRight-click the drawer to configure.")
            color:   "#888888"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            width:   parent.width - 16
            horizontalAlignment: Text.AlignHCenter
        }

        // -------------------------------------------------------------------
        // Drop-area inside the open popup: lets the user drag a .desktop file
        // onto a specific position in the launcher strip.
        //
        // The insertion slot is computed from the drop coordinates:
        //   horizontal dock → vertical strip → use drop.y
        //   vertical dock   → horizontal strip → use drop.x
        // A drop past the last slot appends at the end.
        // -------------------------------------------------------------------
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: function(drop) {
                drop.acceptProposedAction()
                var cellSize = root.isHorizontalDock ? root.height : root.width
                var coord    = root.isHorizontalDock ? drop.y : drop.x
                var idx      = Math.max(0, Math.min(
                                   Math.floor(coord / cellSize),
                                   launcherModel.count))
                root.addLauncherFromUrls(drop.urls, idx)
            }
        }
    }
}

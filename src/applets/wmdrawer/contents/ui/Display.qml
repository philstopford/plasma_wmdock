// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
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
    property string externalDrawerClickMode: ""
    property var    externalLaunchers:   null   // array of {command,icon,label}
    property string externalOrientation: ""     // "horizontal" or "vertical"

    // Emitted after a drag-reorder so the dock can persist the new order.
    signal launchersReordered(var newLaunchers)

    // A torn-off drawer is a persistent tool palette.  It is deliberately a
    // runtime state: closing it attaches it back to the dock ready for the
    // next open.
    property bool drawerDetached: false

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
    // Falls back to the actual Plasma form factor when running standalone;
    // floating widgets cannot infer their layout direction from location.
    readonly property bool isHorizontalDock: {
        if (externalOrientation === "vertical")   return false
        if (externalOrientation === "horizontal") return true
        return Plasmoid.formFactor !== PlasmaCore.Types.Vertical
    }

    readonly property string openEffect: Plasmoid.configuration.openEffect || "slide"
    readonly property string drawerClickMode: externalDrawerClickMode || Plasmoid.configuration.drawerClickMode || "open"
    readonly property bool triggerClickToggles: drawerClickMode === "toggle"

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

    function droppedValues(drop) {
        var values = []
        if (drop.hasUrls) {
            for (var i = 0; i < drop.urls.length; ++i)
                values.push(drop.urls[i].toString())
        } else if (drop.hasText) {
            var lines = drop.text.trim().split(/\r?\n/)
            for (var j = 0; j < lines.length; ++j)
                if (lines[j].trim()) values.push(lines[j].trim())
        }
        return values
    }

    function addLauncherFromDrop(drop, insertIndex) {
        var values = droppedValues(drop)
        var entries = []
        for (var i = 0; i < values.length; ++i) {
            var value = values[i]
            var entry = DesktopFileReader.launcherForUrl(value)
            if (entry && entry.command) entries.push(entry)
        }
        if (entries.length === 0) return

        if (drawerPopup.drawerOpen) {
            var at = insertIndex < 0 ? launcherModel.count
                                     : Math.min(insertIndex, launcherModel.count)
            for (var j = 0; j < entries.length; ++j)
                launcherModel.insert(at + j, entries[j])
            saveLaunchersFromModel()
        } else {
            var arr = root.launchers ? root.launchers.slice() : []
            var pos = insertIndex < 0 ? arr.length : Math.min(insertIndex, arr.length)
            for (var k = 0; k < entries.length; ++k)
                arr.splice(pos + k, 0, entries[k])
            if (root.externalLaunchers !== null) root.launchersReordered(arr)
            else Plasmoid.configuration.launchersJson = JSON.stringify(arr)
        }
        drop.accept(Qt.CopyAction)
    }

    function launchDroppedFiles(command, drop) {
        var values = droppedValues(drop)
        if (!command || values.length === 0) return
        var args = []
        for (var i = 0; i < values.length; ++i) {
            var value = values[i]
            if (value.startsWith("file://"))
                value = decodeURIComponent(value.slice(7))
            args.push(JSON.stringify(value))
        }
        ProcessLauncher.launch(command + " " + args.join(" "))
        drop.accept(Qt.CopyAction)
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
            // The activation gadget always toggles drawer visibility.  Drawer
            // lifetime is explicit; focus changes never hide it.
            if (drawerPopup.drawerOpen || drawerPopup.visible) {
                drawerPopup.closeDrawer()
                return
            }
            drawerPopup.openDrawer()
        }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: root.drawerLabel
        location: Plasmoid.location
        active: !drawerPopup.visible
    }

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
            root.addLauncherFromDrop(drop, -1)
        }
    }

    // -----------------------------------------------------------------------
    // Launcher model – populated on each open so a previous reorder is
    // reflected without requiring a re-parse of the config.
    // -----------------------------------------------------------------------
    ListModel { id: launcherModel }

    // -----------------------------------------------------------------------
    // PlasmaCore.Dialog remains a Plasma-managed popup for its entire life.
    // Tear-off only disables auto-hide and permits manual positioning; it
    // never changes the native Wayland surface role.
    // -----------------------------------------------------------------------
    PlasmaCore.Dialog {
        id: drawerPopup
        visualParent: buttonBody
        // Let Plasma create the xdg-positioner anchor from the actual button.
        // Direct Window.x/y assignments are not authoritative for Wayland
        // popups and were being constrained to the panel's first row.
        location: root.isHorizontalDock
                    ? (Plasmoid.location === PlasmaCore.Types.TopEdge
                       ? PlasmaCore.Types.TopEdge : PlasmaCore.Types.BottomEdge)
                    : (Plasmoid.location === PlasmaCore.Types.RightEdge
                       ? PlasmaCore.Types.RightEdge : PlasmaCore.Types.LeftEdge)
        flags: Qt.WindowDoesNotAcceptFocus
        hideOnWindowDeactivate: false
        visible: false

        // Open/closed state set by openDrawer()/closeDrawer() and synchronized
        // if the window is hidden externally.
        property bool drawerOpen: false

        function detachDrawer(globalX, globalY) {
            if (root.drawerDetached) return
            fadeInAnim.stop()
            slideInAnim.stop()
            root.drawerDetached = true
            drawerOpen = true
        }

        function attachAndHide() {
            visible = false
            drawerOpen = false
            root.drawerDetached = false
        }

        onVisibleChanged: {
            if (!visible) {
                if (!root.drawerDetached) autoCloseStateResetTimer.restart()
            }
        }

        // Saved so closeDrawer() can animate back to the button.
        property real _hiddenPos: 0    // y (horiz dock) or x (vert dock)
        property real _targetPos: 0   // y (horiz dock) or x (vert dock)
        property real _fixedX:    0   // fixed x when sliding vertically
        property real _fixedY:    0   // fixed y when sliding horizontally

        // --- Open / close -------------------------------------------------
        function openDrawer() {
            autoCloseStateResetTimer.stop()
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
            var titleSize = 18
            var popW  = root.isHorizontalDock ? cellW : cellW * n + titleSize
            var popH  = root.isHorizontalDock ? cellH * n + titleSize : cellH
            drawerContent.implicitWidth  = popW
            drawerContent.implicitHeight = popH

            var effect = root.openEffect
            if (effect === "fade") {
                opacity = 0
                visible = true
                fadeInAnim.start()
            } else {
                opacity = 1
                visible = true
            }
        }

        function closeDrawer() {
            autoCloseStateResetTimer.stop()
            if (root.drawerDetached) {
                attachAndHide()
                return
            }
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
            } else {
                visible = false
            }
        }

        mainItem: Item {
            id: drawerContent
            implicitWidth: root.width
            implicitHeight: root.height + 18

            Timer {
                id: autoCloseStateResetTimer
                interval: 250
                repeat: false
                onTriggered: {
                    if (!drawerPopup.visible && !root.drawerDetached)
                        drawerPopup.drawerOpen = false
                }
            }

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

            // --- Background ---------------------------------------------------
            Rectangle {
                anchors.fill: parent
                color:        "#1c1c1c"
                border.color: "#555"
                border.width: 1
                radius: 4
            }

            // --- Tear-off grip ------------------------------------------------
            Rectangle {
                id: tearOffGrip
                z: 2
                anchors {
                    left: parent.left
                    top: parent.top
                    right: root.isHorizontalDock ? parent.right : undefined
                    bottom: root.isHorizontalDock ? undefined : parent.bottom
                }
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

                Text {
                    z: 3
                    anchors { right: parent.right; top: parent.top; margins: 2 }
                    text: "×"
                    color: "#aaaaaa"
                    font.pixelSize: 12

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.ArrowCursor
                        onClicked: drawerPopup.attachAndHide()
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.SizeAllCursor
                    property point pressGlobal
                    property point pressWindow
                    onPressed: function(mouse) {
                        pressGlobal = tearOffGrip.mapToGlobal(mouse.x, mouse.y)
                        pressWindow = Qt.point(drawerPopup.x, drawerPopup.y)
                    }
                    onPositionChanged: function(mouse) {
                        if (!(mouse.buttons & Qt.LeftButton)) return
                        var p = tearOffGrip.mapToGlobal(mouse.x, mouse.y)
                        if (!root.drawerDetached) drawerPopup.detachDrawer(p.x, p.y)
                        drawerPopup.x = pressWindow.x + p.x - pressGlobal.x
                        drawerPopup.y = pressWindow.y + p.y - pressGlobal.y
                    }
                    onDoubleClicked: drawerPopup.attachAndHide()
                }
            }

            // --- Launcher strip -----------------------------------------------
            ListView {
                id: launcherList
                z: 2
                anchors {
                    left: root.isHorizontalDock ? parent.left : tearOffGrip.right
                    right: parent.right
                    top: root.isHorizontalDock ? tearOffGrip.bottom : parent.top
                    bottom: parent.bottom
                }
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
                            if (cmd) {
                                ProcessLauncher.launch(cmd)
                            }
                        }
                    }
                }

                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    mainText: model.command || ""
                    location: Plasmoid.location
                    active: launcherList.draggedItemIndex < 0
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: function(drag) { drag.accept(Qt.CopyAction) }
                    onDropped: function(drop) {
                        root.launchDroppedFiles(model.command || "", drop)
                    }
                }
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
            z: 1
            onDropped: function(drop) {
                var cellSize = root.isHorizontalDock ? root.height : root.width
                var coord    = root.isHorizontalDock ? drop.y - 18 : drop.x - 18
                var idx      = Math.max(0, Math.min(
                                   Math.floor(coord / cellSize),
                                   launcherModel.count))
                root.addLauncherFromDrop(drop, idx)
            }
        }
    }

    }
}

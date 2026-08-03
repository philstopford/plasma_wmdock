// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.plasma.plasmoid

/**
 * WMCalendar – Date and mini-calendar applet.
 *
 * Shows:
 *   • Current month/year header
 *   • A 7-column mini month-grid (Sun–Sat) with today highlighted
 *   • Weekday name and day number in large digits
 *
 * Styled after classic wmcalendar / wmdesktopclock dockapps.
 */
Item {
    id: root

    readonly property bool weekStartsMonday: Plasmoid.configuration.weekStartsMonday ?? false

    property var _now: new Date()
    property int viewYear: _now.getFullYear()
    property int viewMonth: _now.getMonth()

    Timer {
        interval: 60000   // update every minute
        running:  true
        repeat:   true
        onTriggered: root._now = new Date()
    }

    onWeekStartsMondayChanged: root._now = new Date()  // force cells rebuild

    // Derived date fields
    readonly property int  todayYear:  _now.getFullYear()
    readonly property int  todayMonth: _now.getMonth()       // 0-based
    readonly property int  todayDay:   _now.getDate()
    readonly property int  todayWDay:  _now.getDay()         // 0=Sun

    readonly property var  dayNames:   weekStartsMonday
                                        ? ["Mo","Tu","We","Th","Fr","Sa","Su"]
                                        : ["Su","Mo","Tu","We","Th","Fr","Sa"]
    readonly property var  dayNamesFull: ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    readonly property var  monthNames: ["Jan","Feb","Mar","Apr","May","Jun",
                                        "Jul","Aug","Sep","Oct","Nov","Dec"]

    // Build array of day cells for current month (with leading blanks).
    // When weekStartsMonday is true, Sunday (getDay()=0) maps to column 6.
    readonly property var  cells: buildCells()

    function changeMonth(delta) {
        const date = new Date(viewYear, viewMonth + delta, 1)
        viewYear = date.getFullYear()
        viewMonth = date.getMonth()
    }

    function buildCells() {
        let firstDay = new Date(viewYear, viewMonth, 1).getDay()  // 0=Sun
        if (weekStartsMonday) firstDay = (firstDay + 6) % 7         // 0=Mon
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        let arr = []
        for (let i = 0; i < firstDay; i++)    arr.push(-1)
        for (let d = 1; d <= daysInMonth; d++) arr.push(d)
        return arr
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
    // Month / year header
    // -----------------------------------------------------------------------
    Row {
        id: monthHeader
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 1 }
        height: Math.max(previousMonth.implicitHeight, monthLabel.implicitHeight)

        Text {
            id: previousMonth
            width: root.width * 0.2
            text: "◀"
            color: previousMouse.containsMouse ? "#ffffff" : "#0088ff"
            font { pixelSize: root.height * 0.11; family: "monospace"; bold: true }
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
                id: previousMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.changeMonth(-1)
            }
        }

        Text {
            id: monthLabel
            width: root.width * 0.6
            text: monthNames[viewMonth] + " " + viewYear
            color: "#0088ff"
            font { pixelSize: root.height * 0.11; family: "monospace"; bold: true }
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            id: nextMonth
            width: root.width * 0.2
            text: "▶"
            color: nextMouse.containsMouse ? "#ffffff" : "#0088ff"
            font { pixelSize: root.height * 0.11; family: "monospace"; bold: true }
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.changeMonth(1)
            }
        }
    }

    // -----------------------------------------------------------------------
    // Day-of-week column headers
    // -----------------------------------------------------------------------
    Row {
        id: dowRow
        anchors { top: monthHeader.bottom; left: parent.left; right: parent.right; topMargin: 1 }
        Repeater {
            model: dayNames
            Text {
                width: root.width / 7
                text: modelData
                color: {
                    if (root.weekStartsMonday)
                        return (index >= 5) ? "#884400" : "#445566"
                    return (index === 0 || index === 6) ? "#884400" : "#445566"
                }
                font { pixelSize: root.height * 0.09; family: "monospace" }
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // -----------------------------------------------------------------------
    // Calendar grid
    // -----------------------------------------------------------------------
    Grid {
        id: calGrid
        anchors {
            top:    dowRow.bottom
            left:   parent.left
            right:  parent.right
            bottom: dayBadge.top
            topMargin:    1
            bottomMargin: 2
        }
        columns: 7
        rows:    Math.ceil(cells.length / 7)

        Repeater {
            model: cells
            Item {
                width:  root.width / 7
                height: calGrid.height / calGrid.rows

                readonly property bool isToday: modelData === todayDay &&
                                                viewMonth === todayMonth &&
                                                viewYear === todayYear

                Rectangle {
                    anchors.centerIn: parent
                    width:  Math.min(parent.width, parent.height) * 0.85
                    height: width
                    radius: width / 2
                    color:  isToday ? "#0066cc" : "transparent"
                    visible: modelData > 0
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData > 0 ? modelData : ""
                    color: isToday ? "#ffffff"
                         : (root.weekStartsMonday ? (index % 7 >= 5) : (index % 7 === 0 || index % 7 === 6))
                           ? "#884400" : "#aaaaaa"
                    font { pixelSize: root.height * 0.09; family: "monospace";
                           bold: isToday }
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Large day badge at the bottom
    // -----------------------------------------------------------------------
    Row {
        id: dayBadge
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 1 }
        spacing: 2

        Text {
            text: dayNamesFull[todayWDay].substring(0, 3).toUpperCase()
            color: "#0066bb"
            font { pixelSize: root.height * 0.13; family: "monospace"; bold: true }
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: String(todayDay).padStart(2, "0")
            color: "#ffffff"
            font { pixelSize: root.height * 0.17; family: "monospace"; bold: true }
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}

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

    function buildCells() {
        let firstDay = new Date(todayYear, todayMonth, 1).getDay()  // 0=Sun
        if (weekStartsMonday) firstDay = (firstDay + 6) % 7         // 0=Mon
        const daysInMonth = new Date(todayYear, todayMonth + 1, 0).getDate()
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
    Text {
        id: monthHeader
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 1 }
        text: monthNames[todayMonth] + " " + todayYear
        color: "#0088ff"
        font { pixelSize: parent.height * 0.11; family: "monospace"; bold: true }
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

                readonly property bool isToday: modelData === todayDay

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
                         : {
                             const col = index % 7
                             const isWeekend = root.weekStartsMonday ? col >= 5 : (col === 0 || col === 6)
                             return isWeekend ? "#884400" : "#aaaaaa"
                         }
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

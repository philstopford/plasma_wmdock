// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property real   cfg_latitude:  0
    property real   cfg_longitude: 0
    property string cfg_tempUnit:  ""

    // Geocoding state (not persisted)
    property var    _geoResults:   []
    property bool   _geoSearching: false
    property string _geoError:     ""

    // 1 degree = 1000 SpinBox steps (three decimal places of precision)
    readonly property int _coordScale:     1000
    readonly property int _maxSearchLength: 200

    function _doGeocode(query) {
        if (query.length === 0) return
        _geoSearching = true
        _geoError     = ""
        _geoResults   = []
        geocodeTimer.restart()

        var xhr = new XMLHttpRequest()
        var url = "https://geocoding-api.open-meteo.com/v1/search?name=" +
                  encodeURIComponent(query.substring(0, page._maxSearchLength)) +
                  "&count=10&language=en&format=json"
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            geocodeTimer.stop()
            _geoSearching = false
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    _geoResults = data.results || []
                    if (_geoResults.length === 0)
                        _geoError = i18n("No results found.")
                } catch (e) {
                    _geoError = i18n("Failed to parse response.")
                }
            } else if (xhr.status === 0) {
                _geoError = i18n("Search timed out.")
            } else {
                _geoError = i18n("Search failed (HTTP %1).").arg(xhr.status)
            }
        }
        xhr.send()
    }

    // Abort guard: reset searching state if the request never completes
    Timer {
        id:       geocodeTimer
        interval: 10000
        repeat:   false
        onTriggered: {
            if (page._geoSearching) {
                page._geoSearching = false
                page._geoError     = i18n("Search timed out.")
            }
        }
    }

    Kirigami.FormLayout {
        anchors.left:  parent.left
        anchors.right: parent.right

        // ── Location Search ──────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Location Search") }

        Row {
            Kirigami.FormData.label: i18n("Search:")
            spacing: 4

            Rectangle {
                width:        220
                height:       26
                color:        Kirigami.Theme.backgroundColor
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1
                radius:       3

                Text {
                    anchors { fill: parent; margins: 5 }
                    text:              i18n("City, postcode, country…")
                    color:             Kirigami.Theme.disabledTextColor
                    font.pixelSize:    12
                    visible:           searchInput.text.length === 0 && !searchInput.activeFocus
                    verticalAlignment: Text.AlignVCenter
                }

                TextInput {
                    id:                searchInput
                    anchors { fill: parent; margins: 5 }
                    color:             Kirigami.Theme.textColor
                    selectionColor:    Kirigami.Theme.highlightColor
                    selectedTextColor: Kirigami.Theme.highlightedTextColor
                    font.pixelSize:    12
                    clip:              true
                    maximumLength:     page._maxSearchLength
                    verticalAlignment: TextInput.AlignVCenter
                    onAccepted:        page._doGeocode(text)
                }
            }

            QQC2.Button {
                text:    page._geoSearching ? i18n("Searching…") : i18n("Search")
                enabled: !page._geoSearching && searchInput.text.length > 0
                onClicked: page._doGeocode(searchInput.text)
            }
        }

        // Inline results list (shown when geocoding returns hits)
        ListView {
            id: resultsList
            Kirigami.FormData.label: i18n("Results:")
            visible:        page._geoResults.length > 0
            implicitWidth:  320
            implicitHeight: Math.min(page._geoResults.length, 6) * 32
            model:          page._geoResults
            clip:           true

            delegate: Rectangle {
                width:  resultsList.width
                height: 32
                color:  resultDelegateArea.containsMouse
                        ? Kirigami.Theme.highlightColor
                        : (index % 2 === 0 ? Kirigami.Theme.backgroundColor
                                           : Kirigami.Theme.alternateBackgroundColor)
                radius: 2

                Text {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 6; rightMargin: 6
                    }
                    text: {
                        var s = modelData.name || ""
                        if (modelData.admin1)  s += ", " + modelData.admin1
                        if (modelData.country) s += ", " + modelData.country
                        s += "  (" + (modelData.latitude  || 0).toFixed(2) +
                             ", "  + (modelData.longitude || 0).toFixed(2) + ")"
                        return s
                    }
                    color:          resultDelegateArea.containsMouse
                                    ? Kirigami.Theme.highlightedTextColor
                                    : Kirigami.Theme.textColor
                    font.pixelSize: 11
                    elide:          Text.ElideRight
                }

                MouseArea {
                    id:           resultDelegateArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        var lat = modelData.latitude  || 0
                        var lon = modelData.longitude || 0
                        page.cfg_latitude  = lat
                        page.cfg_longitude = lon
                        latField.value = Math.round(lat * page._coordScale)
                        lonField.value = Math.round(lon * page._coordScale)
                        page._geoResults = []
                    }
                }
            }
        }

        // Error / no-results message
        Text {
            Kirigami.FormData.label: ""
            visible:        page._geoError.length > 0
            text:           page._geoError
            color:          Kirigami.Theme.negativeTextColor
            font.pixelSize: 12
        }

        // ── Coordinates ───────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Coordinates") }

        QQC2.SpinBox {
            id: latField
            Kirigami.FormData.label: i18n("Latitude (°):")
            from:     -90000
            to:        90000
            stepSize:  100
            value:     Math.round(page.cfg_latitude * page._coordScale)
            onValueChanged: page.cfg_latitude = value / page._coordScale
            textFromValue: function(v) { return (v / page._coordScale).toFixed(3) }
            valueFromText: function(t) { return Math.round(parseFloat(t) * page._coordScale) }
        }

        QQC2.SpinBox {
            id: lonField
            Kirigami.FormData.label: i18n("Longitude (°):")
            from:     -180000
            to:        180000
            stepSize:  100
            value:     Math.round(page.cfg_longitude * page._coordScale)
            onValueChanged: page.cfg_longitude = value / page._coordScale
            textFromValue: function(v) { return (v / page._coordScale).toFixed(3) }
            valueFromText: function(t) { return Math.round(parseFloat(t) * page._coordScale) }
        }

        // ── Display ───────────────────────────────────────────────────────
        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Display") }

        QQC2.ComboBox {
            id: unitCombo
            Kirigami.FormData.label: i18n("Temperature unit:")
            model: [
                { text: i18n("Celsius (°C)"),    value: "celsius"    },
                { text: i18n("Fahrenheit (°F)"), value: "fahrenheit" }
            ]
            textRole:  "text"
            valueRole: "value"
            Component.onCompleted: {
                for (let i = 0; i < count; ++i) {
                    if (model[i].value === page.cfg_tempUnit) {
                        currentIndex = i
                        return
                    }
                }
                currentIndex = 0
            }
            onActivated: page.cfg_tempUnit = currentValue
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.private.wmdock 1.0
import org.kde.kirigami as Kirigami

/**
 * WMWeather – Current weather conditions.
 *
 * Uses Open-Meteo (no API key) to show temperature, wind, humidity
 * and a weather icon.  Latitude/longitude default to London;
 * configure via right-click → Configure.
 *
 * Styled after classic wmWeather dockapps.
 */
Item {
    id: root

    // Each instance creates its own WeatherProvider
    WeatherProvider {
        id: wp
        latitude:  Plasmoid.configuration.latitude  || 51.5
        longitude: Plasmoid.configuration.longitude || -0.12
        tempUnit:  Plasmoid.configuration.tempUnit  || "celsius"
        updateIntervalMinutes: 30
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
    // Loading spinner
    // -----------------------------------------------------------------------
    QQC2.BusyIndicator {
        anchors.centerIn: parent
        running: wp.loading
        visible: running
    }

    // -----------------------------------------------------------------------
    // Error state
    // -----------------------------------------------------------------------
    Text {
        anchors.centerIn: parent
        visible: !wp.loading && wp.error.length > 0
        text:    "ERR"
        color:   "#ff3300"
        font { pixelSize: parent.height * 0.18; family: "monospace"; bold: true }
        QQC2.ToolTip.visible: hoverHandlerErr.hovered
        QQC2.ToolTip.text:   wp.error
        HoverHandler { id: hoverHandlerErr }
    }

    // -----------------------------------------------------------------------
    // Weather icon (KDE icon name)
    // -----------------------------------------------------------------------
    Kirigami.Icon {
        id: weatherIcon
        anchors {
            top:   parent.top
            left:  parent.left
            right: parent.right
            topMargin:  3
        }
        height: parent.height * 0.38
        source: wp.iconName
        visible: !wp.loading && wp.error.length === 0
    }

    // -----------------------------------------------------------------------
    // Temperature (large)
    // -----------------------------------------------------------------------
    Text {
        id: tempText
        anchors {
            top:              weatherIcon.bottom
            horizontalCenter: parent.horizontalCenter
        }
        visible: !wp.loading && wp.error.length === 0
        text: wp.temperature.toFixed(1) + (wp.tempUnit === "fahrenheit" ? "°F" : "°C")
        color: "#ffdd44"
        font { pixelSize: parent.height * 0.16; family: "monospace"; bold: true }
    }

    // -----------------------------------------------------------------------
    // Description (small)
    // -----------------------------------------------------------------------
    Text {
        id: descText
        anchors {
            top:   tempText.bottom
            left:  parent.left
            right: parent.right
            topMargin: 1
        }
        visible: !wp.loading && wp.error.length === 0
        text: wp.description
        color: "#888"
        font { pixelSize: parent.height * 0.09; family: "monospace" }
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.NoWrap
    }

    // -----------------------------------------------------------------------
    // Wind + humidity
    // -----------------------------------------------------------------------
    Row {
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 2
        }
        spacing: 3
        visible: !wp.loading && wp.error.length === 0

        Text {
            text: "💨" + wp.windSpeed.toFixed(0) + "km/h"
            color: "#5588bb"
            font { pixelSize: parent.height * 0.09; family: "monospace" }
        }
        Text {
            text: "💧" + wp.humidity.toFixed(0) + "%"
            color: "#448888"
            font { pixelSize: parent.height * 0.09; family: "monospace" }
        }
    }

    // -----------------------------------------------------------------------
    // Refresh on click
    // -----------------------------------------------------------------------
    TapHandler {
        onDoubleTapped: wp.refresh()
    }
    QQC2.ToolTip {
        visible: hoverH.hovered
        text:    (wp.error.length > 0 ? wp.error : wp.description) +
                 "\nLat: " + wp.latitude.toFixed(2) +
                 " Lon: " + wp.longitude.toFixed(2) +
                 "\nDouble-click to refresh"
        delay: 700
    }
    HoverHandler { id: hoverH }
}

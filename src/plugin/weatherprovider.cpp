// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "weatherprovider.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <QUrl>

namespace {
constexpr int RequestTimeoutMs = 15000;
}

WeatherProvider::WeatherProvider(QObject *parent)
    : QObject(parent)
{
    connect(&m_nam, &QNetworkAccessManager::finished,
            this, &WeatherProvider::onReplyFinished);

    connect(&m_timer, &QTimer::timeout, this, &WeatherProvider::refresh);
    m_timer.setInterval(30 * 60 * 1000); // 30 minutes
    m_timer.start();

    // Coalesce rapid lat/lon/unit changes from QML property bindings.
    // 400 ms is shorter than the startup delay intentionally: on startup we
    // need the full 500 ms for QML to set all properties; for subsequent
    // user-initiated changes (e.g. config page edits) 400 ms is enough.
    m_debounceTimer.setSingleShot(true);
    m_debounceTimer.setInterval(400);
    connect(&m_debounceTimer, &QTimer::timeout, this, &WeatherProvider::refresh);

    // A disconnected network can otherwise leave requests pending for an
    // implementation-defined amount of time.  Keep at most one bounded
    // request per applet instance so it can never accumulate stalled replies.
    m_requestTimeout.setSingleShot(true);
    m_requestTimeout.setInterval(RequestTimeoutMs);
    connect(&m_requestTimeout, &QTimer::timeout, this, [this] {
        if (m_reply) {
            m_requestTimedOut = true;
            m_reply->abort();
        }
    });

    // Delay the first fetch so QML has time to apply all Plasmoid.configuration
    // bindings before the network request fires.  Without this delay the
    // constructor fires refresh() with the default London co-ordinates and the
    // correct configured location is only applied on subsequent QML-triggered
    // setter calls.
    QTimer::singleShot(500, this, &WeatherProvider::refresh);
}

int WeatherProvider::updateIntervalMinutes() const
{
    return m_timer.interval() / 60000;
}

void WeatherProvider::setUpdateIntervalMinutes(int minutes)
{
    const int ms = qMax(1, minutes) * 60000;
    if (ms != m_timer.interval()) {
        m_timer.setInterval(ms);
        Q_EMIT updateIntervalChanged();
    }
}

void WeatherProvider::setLatitude(double lat)
{
    if (qFuzzyCompare(m_lat, lat)) return;
    m_lat = lat;
    Q_EMIT locationChanged();
    m_debounceTimer.start();
}

void WeatherProvider::setLongitude(double lon)
{
    if (qFuzzyCompare(m_lon, lon)) return;
    m_lon = lon;
    Q_EMIT locationChanged();
    m_debounceTimer.start();
}

void WeatherProvider::setLocationName(const QString &n) { m_locationName = n; Q_EMIT locationChanged(); }

void WeatherProvider::setTempUnit(const QString &u)
{
    if (m_tempUnit == u) return;
    m_tempUnit = u;
    Q_EMIT tempUnitChanged();
    m_debounceTimer.start();
}

void WeatherProvider::refresh()
{
    // Timers, configuration changes, and user clicks can all request a
    // refresh.  Do not start another connection while one is still pending.
    if (m_reply)
        return;

    m_loading = true;
    if (!m_error.isEmpty()) {
        m_error.clear();
        Q_EMIT errorChanged();
    }
    Q_EMIT loadingChanged();

    QUrl url(QStringLiteral("https://api.open-meteo.com/v1/forecast"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("latitude"),           QString::number(m_lat, 'f', 4));
    query.addQueryItem(QStringLiteral("longitude"),          QString::number(m_lon, 'f', 4));
    query.addQueryItem(QStringLiteral("current_weather"),    QStringLiteral("true"));
    query.addQueryItem(QStringLiteral("hourly"),             QStringLiteral("relativehumidity_2m"));
    query.addQueryItem(QStringLiteral("temperature_unit"),   m_tempUnit);
    query.addQueryItem(QStringLiteral("windspeed_unit"),     QStringLiteral("kmh"));
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setTransferTimeout(RequestTimeoutMs);
    request.setHeader(QNetworkRequest::UserAgentHeader,
                      QStringLiteral("Plasma-WMDock/1.0"));
    m_requestTimedOut = false;
    m_reply = m_nam.get(request);
    m_requestTimeout.start();
}

void WeatherProvider::onReplyFinished(QNetworkReply *reply)
{
    // QNetworkAccessManager only creates replies for this provider, but guard
    // against a stale reply defensively if its lifetime changes in the future.
    if (reply != m_reply) {
        reply->deleteLater();
        return;
    }

    m_requestTimeout.stop();
    m_reply = nullptr;
    reply->deleteLater();
    m_loading = false;
    Q_EMIT loadingChanged();

    if (m_requestTimedOut) {
        m_error = QStringLiteral("Weather request timed out");
        Q_EMIT errorChanged();
        return;
    }

    if (reply->error() != QNetworkReply::NoError) {
        m_error = QStringLiteral("Weather request failed: %1").arg(reply->errorString());
        Q_EMIT errorChanged();
        return;
    }

    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (httpStatus < 200 || httpStatus >= 300) {
        m_error = QStringLiteral("Weather service returned HTTP %1").arg(httpStatus);
        Q_EMIT errorChanged();
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (doc.isNull()) {
        m_error = QStringLiteral("Invalid JSON response");
        Q_EMIT errorChanged();
        return;
    }

    const QJsonObject root = doc.object();
    const QJsonObject cw   = root[QLatin1String("current_weather")].toObject();

    if (cw.isEmpty() || !cw.contains(QLatin1String("temperature")) ||
        !cw.contains(QLatin1String("windspeed")) ||
        !cw.contains(QLatin1String("weathercode"))) {
        m_error = QStringLiteral("Weather service returned incomplete data");
        Q_EMIT errorChanged();
        return;
    }

    m_temperature = cw[QLatin1String("temperature")].toDouble();
    m_windSpeed   = cw[QLatin1String("windspeed")].toDouble();
    m_weatherCode = cw[QLatin1String("weathercode")].toInt();

    // Grab humidity from first hourly entry
    const QJsonObject hourly = root[QLatin1String("hourly")].toObject();
    const QJsonArray  rhArr  = hourly[QLatin1String("relativehumidity_2m")].toArray();
    m_humidity = rhArr.isEmpty() ? 0.0 : rhArr[0].toDouble();

    Q_EMIT weatherUpdated();
}

// WMO Weather interpretation codes → human description
QString WeatherProvider::description() const
{
    switch (m_weatherCode) {
    case  0: return QStringLiteral("Clear sky");
    case  1: return QStringLiteral("Mainly clear");
    case  2: return QStringLiteral("Partly cloudy");
    case  3: return QStringLiteral("Overcast");
    case 45: return QStringLiteral("Foggy");
    case 48: return QStringLiteral("Icy fog");
    case 51: return QStringLiteral("Light drizzle");
    case 53: return QStringLiteral("Drizzle");
    case 55: return QStringLiteral("Heavy drizzle");
    case 61: return QStringLiteral("Light rain");
    case 63: return QStringLiteral("Rain");
    case 65: return QStringLiteral("Heavy rain");
    case 71: return QStringLiteral("Light snow");
    case 73: return QStringLiteral("Snow");
    case 75: return QStringLiteral("Heavy snow");
    case 77: return QStringLiteral("Snow grains");
    case 80: return QStringLiteral("Light showers");
    case 81: return QStringLiteral("Showers");
    case 82: return QStringLiteral("Heavy showers");
    case 85: return QStringLiteral("Snow showers");
    case 86: return QStringLiteral("Heavy snow showers");
    case 95: return QStringLiteral("Thunderstorm");
    case 96: return QStringLiteral("Thunderstorm w/ hail");
    case 99: return QStringLiteral("Thunderstorm w/ heavy hail");
    default: return QStringLiteral("Unknown");
    }
}

// Map WMO codes to KDE weather icon names
QString WeatherProvider::iconName() const
{
    if (m_weatherCode == 0)             return QStringLiteral("weather-clear");
    if (m_weatherCode <= 2)             return QStringLiteral("weather-few-clouds");
    if (m_weatherCode == 3)             return QStringLiteral("weather-clouds");
    if (m_weatherCode <= 48)            return QStringLiteral("weather-fog");
    if (m_weatherCode <= 57)            return QStringLiteral("weather-showers-scattered");
    if (m_weatherCode <= 67)            return QStringLiteral("weather-showers");
    if (m_weatherCode <= 77)            return QStringLiteral("weather-snow");
    if (m_weatherCode <= 82)            return QStringLiteral("weather-showers");
    if (m_weatherCode <= 86)            return QStringLiteral("weather-snow-scattered");
    if (m_weatherCode <= 99)            return QStringLiteral("weather-storm");
    return QStringLiteral("weather-none-available");
}

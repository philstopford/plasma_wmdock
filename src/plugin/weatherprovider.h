// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QString>
#include <QVariantMap>

/**
 * @brief Fetches weather data from the Open-Meteo API (no API key required).
 *
 * Queries https://api.open-meteo.com/v1/forecast for the configured
 * latitude/longitude and exposes a set of current-condition properties
 * for display in the wmweather applet.
 */
class WeatherProvider : public QObject
{
    Q_OBJECT

    Q_PROPERTY(double  latitude    READ latitude    WRITE setLatitude  NOTIFY locationChanged)
    Q_PROPERTY(double  longitude   READ longitude   WRITE setLongitude NOTIFY locationChanged)
    Q_PROPERTY(QString locationName READ locationName WRITE setLocationName NOTIFY locationChanged)

    Q_PROPERTY(int     weatherCode READ weatherCode NOTIFY weatherUpdated)
    Q_PROPERTY(double  temperature READ temperature NOTIFY weatherUpdated)
    Q_PROPERTY(QString tempUnit    READ tempUnit    WRITE setTempUnit  NOTIFY tempUnitChanged)
    Q_PROPERTY(double  windSpeed   READ windSpeed   NOTIFY weatherUpdated)
    Q_PROPERTY(double  humidity    READ humidity    NOTIFY weatherUpdated)
    Q_PROPERTY(QString description READ description NOTIFY weatherUpdated)
    Q_PROPERTY(QString iconName    READ iconName    NOTIFY weatherUpdated)
    Q_PROPERTY(bool    loading     READ loading     NOTIFY loadingChanged)
    Q_PROPERTY(QString error       READ error       NOTIFY errorChanged)

    Q_PROPERTY(int updateIntervalMinutes
               READ  updateIntervalMinutes
               WRITE setUpdateIntervalMinutes
               NOTIFY updateIntervalChanged)

public:
    explicit WeatherProvider(QObject *parent = nullptr);

    double  latitude()             const { return m_lat; }
    double  longitude()            const { return m_lon; }
    QString locationName()         const { return m_locationName; }
    int     weatherCode()          const { return m_weatherCode; }
    double  temperature()          const { return m_temperature; }
    QString tempUnit()             const { return m_tempUnit; }
    double  windSpeed()            const { return m_windSpeed; }
    double  humidity()             const { return m_humidity; }
    QString description()          const;
    QString iconName()             const;
    bool    loading()              const { return m_loading; }
    QString error()                const { return m_error; }
    int     updateIntervalMinutes() const;

    void setLatitude(double lat);
    void setLongitude(double lon);
    void setLocationName(const QString &name);
    void setTempUnit(const QString &unit);
    void setUpdateIntervalMinutes(int minutes);

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void locationChanged();
    void weatherUpdated();
    void tempUnitChanged();
    void loadingChanged();
    void errorChanged();
    void updateIntervalChanged();

private Q_SLOTS:
    void onReplyFinished(QNetworkReply *reply);

private:
    QNetworkAccessManager m_nam;
    QTimer  m_timer;
    double  m_lat         = 51.5;   // default: London
    double  m_lon         = -0.12;
    QString m_locationName;
    int     m_weatherCode = -1;
    double  m_temperature = 0.0;
    QString m_tempUnit    = QStringLiteral("celsius");
    double  m_windSpeed   = 0.0;
    double  m_humidity    = 0.0;
    bool    m_loading     = false;
    QString m_error;
};

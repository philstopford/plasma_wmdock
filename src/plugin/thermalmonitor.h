// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>

// Monitors hardware temperature sensors.
//
// Reads temperatures from two kernel interfaces:
//   - /sys/class/hwmon/hwmon<N>/temp<N>_input  (millidegrees Celsius)
//   - /sys/class/thermal/thermal_zone<N>/temp   (millidegrees Celsius)
//
// Each sensor is described by a QVariantMap with keys:
//   key        - unique identifier string (e.g. "hwmon0_temp1")
//   name       - source device name (hwmon chip name or thermal_zone type)
//   label      - human-readable label (temp<N>_label or zone type)
//   temp       - current temperature in degrees Celsius (double)
//   available  - bool: false when the sysfs node is unreadable
//
// Exposed to QML as a singleton via the wmdockplugin QML extension.
class ThermalMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList sensors
               READ sensors
               NOTIFY sensorsChanged)

    Q_PROPERTY(int updateInterval
               READ  updateInterval
               WRITE setUpdateInterval
               NOTIFY updateIntervalChanged)

public:
    explicit ThermalMonitor(QObject *parent = nullptr);

    QVariantList sensors()      const { return m_sensors; }
    int  updateInterval()       const;
    void setUpdateInterval(int ms);

Q_SIGNALS:
    void sensorsChanged();
    void updateIntervalChanged();

private Q_SLOTS:
    void update();

private:
    void scanSensors();
    void readTemperatures();

    struct SensorInfo {
        QString key;       // unique ID
        QString name;      // chip / zone name
        QString label;     // human label
        QString tempPath;  // absolute sysfs path for temperature value
        bool    available = true;
        double  temp = 0.0;
    };

    QTimer       m_timer;
    QVariantList m_sensors;
    QList<SensorInfo> m_sensorInfos;
};

// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "thermalmonitor.h"

#include <QDir>
#include <QFile>
#include <QVariantMap>

ThermalMonitor::ThermalMonitor(QObject *parent)
    : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &ThermalMonitor::update);
    m_timer.setInterval(3000);   // refresh every 3 s
    m_timer.start();

    scanSensors();
    readTemperatures();
}

int ThermalMonitor::updateInterval() const
{
    return m_timer.interval();
}

void ThermalMonitor::setUpdateInterval(int ms)
{
    if (ms == m_timer.interval())
        return;
    m_timer.setInterval(ms);
    Q_EMIT updateIntervalChanged();
}

// ---------------------------------------------------------------------------
// Scan /sys/class/hwmon and /sys/class/thermal for available sensors.
// This is done once at startup; new hardware showing up afterwards is not
// detected, which is acceptable for a desktop applet.
// ---------------------------------------------------------------------------
void ThermalMonitor::scanSensors()
{
    m_sensorInfos.clear();

    // --- hwmon sensors -----------------------------------------------------
    const QString hwmonBase = QStringLiteral("/sys/class/hwmon");
    QDir hwmonDir(hwmonBase);
    const QStringList hwmonEntries = hwmonDir.entryList(
        QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    for (const QString &hwmonName : hwmonEntries) {
        const QString hwmonPath = hwmonBase + QLatin1Char('/') + hwmonName;

        // Read chip name
        QString chipName = hwmonName;
        {
            QFile nameFile(hwmonPath + QStringLiteral("/name"));
            if (nameFile.open(QIODevice::ReadOnly))
                chipName = QString::fromLatin1(nameFile.readAll()).trimmed();
        }

        // Enumerate temp*_input nodes
        QDir hwmonNodeDir(hwmonPath);
        const QStringList tempFiles = hwmonNodeDir.entryList(
            QStringList() << QStringLiteral("temp*_input"),
            QDir::Files, QDir::Name);

        for (const QString &tempFile : tempFiles) {
            // Extract the index number (e.g. "temp1_input" → 1)
            const QString idx = tempFile.mid(4, tempFile.indexOf(QLatin1Char('_')) - 4);

            // Try to read a human label
            QString label;
            {
                QFile labelFile(hwmonPath + QStringLiteral("/temp") + idx + QStringLiteral("_label"));
                if (labelFile.open(QIODevice::ReadOnly))
                    label = QString::fromLatin1(labelFile.readAll()).trimmed();
            }
            if (label.isEmpty())
                label = chipName + QLatin1Char(' ') + idx;

            SensorInfo si;
            si.key      = hwmonName + QLatin1Char('_') + QStringLiteral("temp") + idx;
            si.name     = chipName;
            si.label    = label;
            si.tempPath = hwmonPath + QLatin1Char('/') + tempFile;
            m_sensorInfos.append(si);
        }
    }

    // --- thermal_zone sensors ----------------------------------------------
    const QString thermalBase = QStringLiteral("/sys/class/thermal");
    QDir thermalDir(thermalBase);
    const QStringList thermalEntries = thermalDir.entryList(
        QStringList() << QStringLiteral("thermal_zone*"),
        QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    for (const QString &zoneName : thermalEntries) {
        const QString zonePath = thermalBase + QLatin1Char('/') + zoneName;

        QString zoneType = zoneName;
        {
            QFile typeFile(zonePath + QStringLiteral("/type"));
            if (typeFile.open(QIODevice::ReadOnly))
                zoneType = QString::fromLatin1(typeFile.readAll()).trimmed();
        }

        SensorInfo si;
        si.key      = zoneName;
        si.name     = QStringLiteral("thermal");
        si.label    = zoneType;
        si.tempPath = zonePath + QStringLiteral("/temp");
        m_sensorInfos.append(si);
    }
}

// ---------------------------------------------------------------------------
// Read current temperatures and rebuild the exported QVariantList.
// ---------------------------------------------------------------------------
void ThermalMonitor::readTemperatures()
{
    QVariantList newSensors;
    newSensors.reserve(m_sensorInfos.size());

    for (SensorInfo &si : m_sensorInfos) {
        QFile f(si.tempPath);
        if (f.open(QIODevice::ReadOnly)) {
            bool ok = false;
            const qint64 milli = f.readAll().trimmed().toLongLong(&ok);
            if (ok) {
                si.temp      = milli / 1000.0;
                si.available = true;
            } else {
                si.available = false;
            }
        } else {
            si.available = false;
        }

        QVariantMap m;
        m[QStringLiteral("key")]       = si.key;
        m[QStringLiteral("name")]      = si.name;
        m[QStringLiteral("label")]     = si.label;
        m[QStringLiteral("temp")]      = si.temp;
        m[QStringLiteral("available")] = si.available;
        newSensors.append(m);
    }

    m_sensors = newSensors;
    Q_EMIT sensorsChanged();
}

void ThermalMonitor::update()
{
    if (m_sensorInfos.isEmpty()) {
        scanSensors();
    }
    readTemperatures();
}

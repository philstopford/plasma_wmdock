// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QDBusInterface>
#include <QString>

/**
 * @brief Battery status via the UPower D-Bus API.
 *
 * Exposes the most useful battery properties for display in a
 * small 64×64 applet (percentage, charging state, time remaining).
 */
class BatteryMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool    available     READ available     NOTIFY statusChanged)
    Q_PROPERTY(double  percentage    READ percentage    NOTIFY statusChanged)
    Q_PROPERTY(bool    charging      READ charging      NOTIFY statusChanged)
    Q_PROPERTY(bool    pluggedIn     READ pluggedIn     NOTIFY statusChanged)
    Q_PROPERTY(bool    full          READ full          NOTIFY statusChanged)
    Q_PROPERTY(qint64  timeToFull    READ timeToFull    NOTIFY statusChanged)
    Q_PROPERTY(qint64  timeToEmpty   READ timeToEmpty   NOTIFY statusChanged)
    Q_PROPERTY(QString stateString   READ stateString   NOTIFY statusChanged)

public:
    explicit BatteryMonitor(QObject *parent = nullptr);

    bool    available()   const { return m_available; }
    double  percentage()  const { return m_percentage; }
    bool    charging()    const { return m_charging; }
    bool    pluggedIn()   const { return m_pluggedIn; }
    bool    full()        const { return m_full; }
    qint64  timeToFull()  const { return m_timeToFull; }
    qint64  timeToEmpty() const { return m_timeToEmpty; }
    QString stateString() const;

Q_SIGNALS:
    void statusChanged();

private Q_SLOTS:
    void onPropertiesChanged(const QString &interface,
                             const QVariantMap &changed,
                             const QStringList &invalidated);

private:
    void findBattery();
    void refresh();

    QString  m_batteryPath;
    bool     m_available   = false;
    double   m_percentage  = 0.0;
    bool     m_charging    = false;
    bool     m_pluggedIn   = false;
    bool     m_full        = false;
    qint64   m_timeToFull  = 0;
    qint64   m_timeToEmpty = 0;
    uint     m_state       = 0;   // UPower BatteryState enum value
};

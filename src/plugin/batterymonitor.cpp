// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "batterymonitor.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusObjectPath>
#include <QVariant>

static const QString UPOWER_SERVICE   = QStringLiteral("org.freedesktop.UPower");
static const QString UPOWER_PATH      = QStringLiteral("/org/freedesktop/UPower");
static const QString UPOWER_IFACE     = QStringLiteral("org.freedesktop.UPower");
static const QString UPOWER_DEV_IFACE = QStringLiteral("org.freedesktop.UPower.Device");
static const QString DBUS_PROPS_IFACE = QStringLiteral("org.freedesktop.DBus.Properties");

BatteryMonitor::BatteryMonitor(QObject *parent)
    : QObject(parent)
{
    findBattery();
}

void BatteryMonitor::findBattery()
{
    auto bus = QDBusConnection::systemBus();
    QDBusMessage msg = QDBusMessage::createMethodCall(
        UPOWER_SERVICE, UPOWER_PATH, UPOWER_IFACE,
        QStringLiteral("EnumerateDevices"));

    QDBusReply<QList<QDBusObjectPath>> reply = bus.call(msg);
    if (!reply.isValid()) return;

    for (const QDBusObjectPath &path : reply.value()) {
        QDBusInterface dev(UPOWER_SERVICE, path.path(), UPOWER_DEV_IFACE, bus);
        const uint type = dev.property("Type").toUInt();
        // Type 2 = Battery
        if (type == 2) {
            m_batteryPath = path.path();
            break;
        }
    }

    if (m_batteryPath.isEmpty()) return;

    // Subscribe to property changes
    bus.connect(UPOWER_SERVICE, m_batteryPath,
                QStringLiteral("org.freedesktop.DBus.Properties"),
                QStringLiteral("PropertiesChanged"),
                this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));

    refresh();
}

void BatteryMonitor::refresh()
{
    if (m_batteryPath.isEmpty()) return;

    QDBusInterface dev(UPOWER_SERVICE, m_batteryPath, UPOWER_DEV_IFACE,
                       QDBusConnection::systemBus());

    m_percentage  = dev.property("Percentage").toDouble();
    m_state       = dev.property("State").toUInt();
    m_timeToFull  = dev.property("TimeToFull").toLongLong();
    m_timeToEmpty = dev.property("TimeToEmpty").toLongLong();

    // State: 1=charging, 2=discharging, 3=empty, 4=fully-charged, 5=pending-charge, 6=pending-discharge
    m_charging  = (m_state == 1 || m_state == 5);
    m_full      = (m_state == 4);
    m_pluggedIn = m_charging || m_full;
    m_available = true;

    Q_EMIT statusChanged();
}

void BatteryMonitor::onPropertiesChanged(const QString & /*interface*/,
                                         const QVariantMap & /*changed*/,
                                         const QStringList & /*invalidated*/)
{
    refresh();
}

QString BatteryMonitor::stateString() const
{
    switch (m_state) {
    case 1: return QStringLiteral("Charging");
    case 2: return QStringLiteral("Discharging");
    case 3: return QStringLiteral("Empty");
    case 4: return QStringLiteral("Full");
    case 5: return QStringLiteral("Pending charge");
    case 6: return QStringLiteral("Pending discharge");
    default: return QStringLiteral("Unknown");
    }
}

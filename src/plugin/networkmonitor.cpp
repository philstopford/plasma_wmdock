// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "networkmonitor.h"

#include <QFile>
#include <QTextStream>
#include <QDateTime>
#include <QStringList>

NetworkMonitor::NetworkMonitor(QObject *parent)
    : QObject(parent)
{
    scanInterfaces();

    // Pick first non-loopback interface as default
    for (const QString &iface : std::as_const(m_interfaces)) {
        if (!iface.startsWith(QLatin1String("lo"))) {
            m_iface = iface;
            break;
        }
    }

    connect(&m_timer, &QTimer::timeout, this, &NetworkMonitor::update);
    m_timer.setInterval(1000);
    m_timer.start();

    // Seed previous values so first tick gives 0 rate
    readStats(m_rxPrev, m_txPrev);
    m_lastMs = QDateTime::currentMSecsSinceEpoch();
}

int NetworkMonitor::updateInterval() const
{
    return m_timer.interval();
}

void NetworkMonitor::setIface(const QString &iface)
{
    if (iface == m_iface) return;
    m_iface  = iface;
    m_rxPrev = m_txPrev = 0;
    m_rxMax  = m_txMax  = 1.0;
    readStats(m_rxPrev, m_txPrev);
    m_lastMs = QDateTime::currentMSecsSinceEpoch();
    Q_EMIT ifaceChanged();
}

void NetworkMonitor::setUpdateInterval(int ms)
{
    if (ms != m_timer.interval()) {
        m_timer.setInterval(ms);
        Q_EMIT updateIntervalChanged();
    }
}

void NetworkMonitor::scanInterfaces()
{
    QFile f(QStringLiteral("/proc/net/dev"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QStringList list;
    QTextStream in(&f);
    // Skip two header lines
    in.readLine(); in.readLine();
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        const int colon = line.indexOf(QLatin1Char(':'));
        if (colon > 0)
            list.append(line.left(colon).trimmed());
    }

    if (list != m_interfaces) {
        m_interfaces = list;
        Q_EMIT interfacesChanged();
    }
}

void NetworkMonitor::readStats(qint64 &rx, qint64 &tx) const
{
    if (m_iface.isEmpty()) { rx = tx = 0; return; }

    QFile f(QStringLiteral("/proc/net/dev"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) { rx = tx = 0; return; }

    QTextStream in(&f);
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        const int colon = line.indexOf(QLatin1Char(':'));
        if (colon < 0) continue;
        if (line.left(colon).trimmed() != m_iface) continue;

        const QStringList parts = line.mid(colon + 1).split(QLatin1Char(' '), Qt::SkipEmptyParts);
        if (parts.size() < 9) break;
        rx = parts[0].toLongLong();   // receive bytes
        tx = parts[8].toLongLong();   // transmit bytes
        return;
    }
    rx = tx = 0;
}

void NetworkMonitor::update()
{
    // Refresh interface list
    scanInterfaces();

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const double dtSec = double(nowMs - m_lastMs) / 1000.0;
    m_lastMs = nowMs;

    qint64 rxNow = 0, txNow = 0;
    readStats(rxNow, txNow);

    m_rxTotal = rxNow;
    m_txTotal = txNow;

    if (dtSec > 0) {
        m_rxRate = double(rxNow - m_rxPrev) / dtSec;
        m_txRate = double(txNow - m_txPrev) / dtSec;
    } else {
        m_rxRate = 0;
        m_txRate = 0;
    }

    // Track historic max for auto-scaling graph
    if (m_rxRate > m_rxMax) m_rxMax = m_rxRate;
    if (m_txRate > m_txMax) m_txMax = m_txRate;

    m_rxPrev = rxNow;
    m_txPrev = txNow;

    Q_EMIT statsChanged();
}

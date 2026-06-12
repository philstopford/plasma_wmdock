// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "networkmonitor.h"

#include <QDateTime>
#include <QFile>

NetworkMonitor::NetworkMonitor(QObject *parent)
    : QObject(parent)
{
    scanInterfaces();
    setIface(QString());

    connect(&m_timer, &QTimer::timeout, this, &NetworkMonitor::update);
    m_timer.setInterval(1000);
    m_timer.start();

    // Seed all per-interface counters so the first tick gives 0 rate
    QHash<QString, QPair<qint64,qint64>> rawBytes;
    readAllRawStats(rawBytes);
    m_lastMs = QDateTime::currentMSecsSinceEpoch();
    for (auto it = rawBytes.cbegin(); it != rawBytes.cend(); ++it) {
        if (it.key().startsWith(QLatin1String("lo"))) continue;
        IfaceStat &stat = m_allStats[it.key()];
        stat.rxPrev = it.value().first;
        stat.txPrev = it.value().second;
        stat.seeded = true;
    }
}

int NetworkMonitor::updateInterval() const
{
    return m_timer.interval();
}

void NetworkMonitor::setIface(const QString &iface)
{
    m_requestedIface = iface.trimmed();
    QString resolved = m_requestedIface;

    if (!resolved.isEmpty() && !m_interfaces.contains(resolved))
        scanInterfaces();
    if (resolved.isEmpty() || !m_interfaces.contains(resolved))
        resolved = pickAutoIface();

    if (resolved == m_iface)
        return;

    m_iface = resolved;

    // Immediately populate single-iface properties from existing per-iface stats
    auto it = m_allStats.constFind(m_iface);
    if (it != m_allStats.cend()) {
        m_rxRate = it->rxRate;
        m_txRate = it->txRate;
        m_rxMax  = it->rxMax;
        m_txMax  = it->txMax;
    } else {
        m_rxRate = m_txRate = 0.0;
        m_rxMax  = m_txMax  = 1.0;
    }
    m_rxTotal = m_txTotal = 0;

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
    if (!f.open(QIODevice::ReadOnly)) return;

    const QByteArray data = f.readAll();
    QStringList list;
    int lineNum = 0;
    for (const QByteArray &rawLine : data.split('\n')) {
        if (lineNum++ < 2) continue;
        const QByteArray line = rawLine.trimmed();
        const int colon = line.indexOf(':');
        if (colon > 0)
            list.append(QString::fromLatin1(line.left(colon).trimmed()));
    }

    if (list != m_interfaces) {
        m_interfaces = list;
        Q_EMIT interfacesChanged();
    }
}

void NetworkMonitor::readAllRawStats(QHash<QString, QPair<qint64,qint64>> &out) const
{
    out.clear();
    QFile f(QStringLiteral("/proc/net/dev"));
    if (!f.open(QIODevice::ReadOnly)) return;

    const QByteArray data = f.readAll();
    int lineNum = 0;
    for (const QByteArray &rawLine : data.split('\n')) {
        if (lineNum++ < 2) continue;
        const QByteArray line = rawLine.trimmed();
        const int colon = line.indexOf(':');
        if (colon < 0) continue;

        const QString name = QString::fromLatin1(line.left(colon).trimmed());
        const QByteArray after = line.mid(colon + 1);
        QList<QByteArray> parts;
        for (const QByteArray &p : after.split(' '))
            if (!p.isEmpty()) parts.append(p);
        if (parts.size() < 9) continue;

        out.insert(name, { parts[0].toLongLong(), parts[8].toLongLong() });
    }
}

QVariantList NetworkMonitor::allIfaceStats() const
{
    // Return per-interface stats in the same order as m_interfaces
    QVariantList result;
    for (const QString &name : std::as_const(m_interfaces)) {
        if (name.startsWith(QLatin1String("lo"))) continue;
        auto it = m_allStats.constFind(name);
        if (it == m_allStats.cend()) continue;
        QVariantMap entry;
        entry[QStringLiteral("name")]   = name;
        entry[QStringLiteral("rxRate")] = it->rxRate;
        entry[QStringLiteral("txRate")] = it->txRate;
        entry[QStringLiteral("rxMax")]  = it->rxMax;
        entry[QStringLiteral("txMax")]  = it->txMax;
        result.append(entry);
    }
    return result;
}

void NetworkMonitor::update()
{
    scanInterfaces();

    // Determine the interface to use for the single-iface tracking path,
    // honouring m_requestedIface every tick.
    QString target;
    if (!m_requestedIface.isEmpty()) {
        if (m_interfaces.contains(m_requestedIface)) {
            target = m_requestedIface;
        } else if (!m_iface.isEmpty()) {
            target = m_iface;       // keep showing requested name with 0 stats
        } else {
            target = pickAutoIface();
        }
    } else {
        target = (!m_iface.isEmpty() && m_interfaces.contains(m_iface))
                     ? m_iface : pickAutoIface();
    }

    const bool changedIface = (target != m_iface);
    if (changedIface) {
        m_iface = target;
        Q_EMIT ifaceChanged();
    }

    // Read raw byte counters for ALL interfaces in a single /proc/net/dev pass
    QHash<QString, QPair<qint64,qint64>> rawBytes;
    readAllRawStats(rawBytes);

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const double dtSec = double(nowMs - m_lastMs) / 1000.0;
    m_lastMs = nowMs;

    // Update per-interface stats for all non-loopback interfaces
    for (const QString &name : std::as_const(m_interfaces)) {
        if (name.startsWith(QLatin1String("lo"))) continue;
        auto rawIt = rawBytes.find(name);
        if (rawIt == rawBytes.end()) continue;

        const qint64 rxNow = rawIt->first;
        const qint64 txNow = rawIt->second;
        IfaceStat &stat = m_allStats[name];

        if (dtSec > 0 && stat.seeded) {
            stat.rxRate = double(rxNow - stat.rxPrev) / dtSec;
            stat.txRate = double(txNow - stat.txPrev) / dtSec;
            if (stat.rxRate < 0) stat.rxRate = 0;
            if (stat.txRate < 0) stat.txRate = 0;
            if (stat.rxRate > stat.rxMax) stat.rxMax = stat.rxRate;
            if (stat.txRate > stat.txMax) stat.txMax = stat.txRate;
        }
        stat.rxPrev = rxNow;
        stat.txPrev = txNow;
        stat.seeded = true;
    }

    // Derive single-iface properties for backward compat with QML
    if (!m_iface.isEmpty()) {
        auto it = m_allStats.constFind(m_iface);
        if (it != m_allStats.cend()) {
            m_rxRate = it->rxRate;
            m_txRate = it->txRate;
            m_rxMax  = it->rxMax;
            m_txMax  = it->txMax;
        }
        auto rawIt = rawBytes.constFind(m_iface);
        if (rawIt != rawBytes.cend()) {
            m_rxTotal = rawIt->first;
            m_txTotal = rawIt->second;
        }
    } else {
        m_rxRate = m_txRate = 0.0;
        m_rxTotal = m_txTotal = 0;
    }

    Q_EMIT statsChanged();
}

QString NetworkMonitor::pickAutoIface() const
{
    for (const QString &candidate : std::as_const(m_interfaces)) {
        if (!candidate.startsWith(QLatin1String("lo")))
            return candidate;
    }
    return QString();
}

// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "systemmonitor.h"

#include <QFile>
#include <QTextStream>
#include <QDateTime>

SystemMonitor::SystemMonitor(QObject *parent)
    : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &SystemMonitor::update);
    m_timer.setInterval(1000);
    m_timer.start();
    update(); // initial read to populate m_prevStats
}

int SystemMonitor::updateInterval() const
{
    return m_timer.interval();
}

void SystemMonitor::setUpdateInterval(int ms)
{
    if (ms != m_timer.interval()) {
        m_timer.setInterval(ms);
        Q_EMIT updateIntervalChanged();
    }
}

void SystemMonitor::update()
{
    readCpu();
    readMemory();
    readLoad();
}

// ---------------------------------------------------------------------------
// CPU
// ---------------------------------------------------------------------------

void SystemMonitor::readCpu()
{
    const auto parseCpuLine = [](const QString &line) {
        CpuStat s;
        // Skip the "cpuN" token
        const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        if (parts.size() < 5) return s;
        s.user    = parts[1].toLongLong();
        s.nice    = parts[2].toLongLong();
        s.system  = parts[3].toLongLong();
        s.idle    = parts[4].toLongLong();
        if (parts.size() > 5) s.iowait  = parts[5].toLongLong();
        if (parts.size() > 6) s.irq     = parts[6].toLongLong();
        if (parts.size() > 7) s.softirq = parts[7].toLongLong();
        if (parts.size() > 8) s.steal   = parts[8].toLongLong();
        return s;
    };

    QFile f(QStringLiteral("/proc/stat"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QVector<CpuStat> current;
    QTextStream in(&f);
    while (!in.atEnd()) {
        const QString line = in.readLine();
        if (!line.startsWith(QLatin1String("cpu"))) continue;
        current.append(parseCpuLine(line));
    }

    if (m_prevStats.isEmpty()) {
        // First call — just store for next tick
        m_prevStats = current;
        return;
    }

    // Resize histories to match (handles hot-plug CPUs)
    const int n = std::min(current.size(), m_prevStats.size());
    QVariantList coreList;

    for (int i = 0; i < n; ++i) {
        const qint64 dtotal  = current[i].total()  - m_prevStats[i].total();
        const qint64 dactive = current[i].active() - m_prevStats[i].active();
        const double usage   = (dtotal > 0) ? (double(dactive) / double(dtotal)) * 100.0 : 0.0;

        if (i == 0) {
            m_cpuUsage = usage;
        } else {
            coreList.append(usage);
        }
    }

    m_cpuCoreUsage = coreList;
    m_prevStats    = current;
    Q_EMIT cpuUsageChanged();
}

// ---------------------------------------------------------------------------
// Memory
// ---------------------------------------------------------------------------

void SystemMonitor::readMemory()
{
    QFile f(QStringLiteral("/proc/meminfo"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    qint64 available = 0;
    qint64 swapFree  = 0;
    m_memCached      = 0;
    m_memBuffers     = 0;

    QTextStream in(&f);
    while (!in.atEnd()) {
        const QString line = in.readLine();
        const int colon = line.indexOf(QLatin1Char(':'));
        if (colon < 0) continue;

        const QString key   = line.left(colon).trimmed();
        const qint64  value = line.mid(colon + 1).trimmed().split(QLatin1Char(' '), Qt::SkipEmptyParts).value(0).toLongLong();
        // /proc/meminfo values are in kB

        if      (key == QLatin1String("MemTotal"))     m_memTotal  = value * 1024;
        else if (key == QLatin1String("MemFree"))      m_memFree   = value * 1024;
        else if (key == QLatin1String("MemAvailable")) available    = value * 1024;
        else if (key == QLatin1String("Buffers"))      m_memBuffers = value * 1024;
        else if (key == QLatin1String("Cached"))       m_memCached  = value * 1024;
        else if (key == QLatin1String("SwapTotal"))    m_swapTotal  = value * 1024;
        else if (key == QLatin1String("SwapFree"))     swapFree     = value * 1024;
    }

    m_memUsed  = m_memTotal - available;
    m_memUsage = (m_memTotal > 0) ? (double(m_memUsed) / double(m_memTotal)) * 100.0 : 0.0;
    m_swapUsed = m_swapTotal - swapFree;
    m_swapUsage = (m_swapTotal > 0) ? (double(m_swapUsed) / double(m_swapTotal)) * 100.0 : 0.0;

    Q_EMIT memoryChanged();
}

// ---------------------------------------------------------------------------
// Load average
// ---------------------------------------------------------------------------

void SystemMonitor::readLoad()
{
    QFile f(QStringLiteral("/proc/loadavg"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const QString line = QString::fromLatin1(f.readAll());
    const QStringList parts = line.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    if (parts.size() < 3) return;

    m_load1  = parts[0].toDouble();
    m_load5  = parts[1].toDouble();
    m_load15 = parts[2].toDouble();
    Q_EMIT loadChanged();
}

// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "systemmonitor.h"

#include <QFile>

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
    const auto parseCpuLine = [](const QByteArray &line) {
        CpuStat s;
        // Skip the "cpuN" token; fields are space-separated
        const QList<QByteArray> parts = line.split(' ');
        // Filter empty parts (multiple spaces between fields)
        QList<QByteArray> fields;
        for (const QByteArray &p : parts)
            if (!p.isEmpty()) fields.append(p);
        if (fields.size() < 5) return s;
        s.user    = fields[1].toLongLong();
        s.nice    = fields[2].toLongLong();
        s.system  = fields[3].toLongLong();
        s.idle    = fields[4].toLongLong();
        if (fields.size() > 5) s.iowait  = fields[5].toLongLong();
        if (fields.size() > 6) s.irq     = fields[6].toLongLong();
        if (fields.size() > 7) s.softirq = fields[7].toLongLong();
        if (fields.size() > 8) s.steal   = fields[8].toLongLong();
        return s;
    };

    QFile f(QStringLiteral("/proc/stat"));
    if (!f.open(QIODevice::ReadOnly))
        return;

    QVector<CpuStat> current;
    const QByteArray data = f.readAll();
    for (const QByteArray &rawLine : data.split('\n')) {
        const QByteArray line = rawLine.trimmed();
        if (!line.startsWith("cpu")) continue;
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
    if (!f.open(QIODevice::ReadOnly))
        return;

    const QByteArray data = f.readAll();
    qint64 available = 0;
    qint64 swapFree  = 0;
    m_memCached      = 0;
    m_memBuffers     = 0;

    for (const QByteArray &rawLine : data.split('\n')) {
        const QByteArray line = rawLine.trimmed();
        const int colon = line.indexOf(':');
        if (colon < 0) continue;

        const QByteArray key    = line.left(colon);
        // value is in kB; first token after the colon
        const QByteArray valStr = line.mid(colon + 1).trimmed().split(' ').value(0);
        const qint64     kbVal  = valStr.toLongLong();

        if      (key == "MemTotal")     m_memTotal  = kbVal * 1024;
        else if (key == "MemFree")      m_memFree   = kbVal * 1024;
        else if (key == "MemAvailable") available    = kbVal * 1024;
        else if (key == "Buffers")      m_memBuffers = kbVal * 1024;
        else if (key == "Cached")       m_memCached  = kbVal * 1024;
        else if (key == "SwapTotal")    m_swapTotal  = kbVal * 1024;
        else if (key == "SwapFree")     swapFree     = kbVal * 1024;
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

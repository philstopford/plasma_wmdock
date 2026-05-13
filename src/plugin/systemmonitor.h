// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVector>

/**
 * @brief Monitors CPU usage, memory, and system load average.
 *
 * Reads from Linux /proc/stat, /proc/meminfo and /proc/loadavg.
 * Exposed to QML as a singleton via the wmdockplugin QML extension.
 */
class SystemMonitor : public QObject
{
    Q_OBJECT

    // ---- CPU ----------------------------------------------------------------
    Q_PROPERTY(double   cpuUsage     READ cpuUsage     NOTIFY cpuUsageChanged)
    Q_PROPERTY(QVariantList cpuCoreUsage READ cpuCoreUsage NOTIFY cpuUsageChanged)
    Q_PROPERTY(int      cpuCoreCount READ cpuCoreCount CONSTANT)

    // ---- Memory -------------------------------------------------------------
    Q_PROPERTY(double   memUsage     READ memUsage     NOTIFY memoryChanged)
    Q_PROPERTY(qint64   memTotal     READ memTotal     NOTIFY memoryChanged)
    Q_PROPERTY(qint64   memUsed      READ memUsed      NOTIFY memoryChanged)
    Q_PROPERTY(qint64   memFree      READ memFree      NOTIFY memoryChanged)
    Q_PROPERTY(qint64   memCached    READ memCached    NOTIFY memoryChanged)
    Q_PROPERTY(qint64   memBuffers   READ memBuffers   NOTIFY memoryChanged)
    Q_PROPERTY(double   swapUsage    READ swapUsage    NOTIFY memoryChanged)
    Q_PROPERTY(qint64   swapTotal    READ swapTotal    NOTIFY memoryChanged)
    Q_PROPERTY(qint64   swapUsed     READ swapUsed     NOTIFY memoryChanged)

    // ---- Load average -------------------------------------------------------
    Q_PROPERTY(double   load1        READ load1        NOTIFY loadChanged)
    Q_PROPERTY(double   load5        READ load5        NOTIFY loadChanged)
    Q_PROPERTY(double   load15       READ load15       NOTIFY loadChanged)

    // ---- Update interval ----------------------------------------------------
    Q_PROPERTY(int updateInterval
               READ  updateInterval
               WRITE setUpdateInterval
               NOTIFY updateIntervalChanged)

public:
    explicit SystemMonitor(QObject *parent = nullptr);

    // CPU
    double      cpuUsage()     const { return m_cpuUsage; }
    QVariantList cpuCoreUsage() const { return m_cpuCoreUsage; }
    int         cpuCoreCount() const { return m_prevStats.size() - 1; }

    // Memory
    double  memUsage()   const { return m_memUsage; }
    qint64  memTotal()   const { return m_memTotal; }
    qint64  memUsed()    const { return m_memUsed; }
    qint64  memFree()    const { return m_memFree; }
    qint64  memCached()  const { return m_memCached; }
    qint64  memBuffers() const { return m_memBuffers; }
    double  swapUsage()  const { return m_swapUsage; }
    qint64  swapTotal()  const { return m_swapTotal; }
    qint64  swapUsed()   const { return m_swapUsed; }

    // Load
    double load1()  const { return m_load1; }
    double load5()  const { return m_load5; }
    double load15() const { return m_load15; }

    // Interval
    int  updateInterval()         const;
    void setUpdateInterval(int ms);

Q_SIGNALS:
    void cpuUsageChanged();
    void memoryChanged();
    void loadChanged();
    void updateIntervalChanged();

private Q_SLOTS:
    void update();

private:
    struct CpuStat {
        qint64 user = 0, nice = 0, system = 0, idle = 0,
               iowait = 0, irq = 0, softirq = 0, steal = 0;
        qint64 total()  const { return user + nice + system + idle + iowait + irq + softirq + steal; }
        qint64 active() const { return total() - idle - iowait; }
    };

    void readCpu();
    void readMemory();
    void readLoad();

    QTimer m_timer;

    // CPU
    double       m_cpuUsage = 0.0;
    QVariantList m_cpuCoreUsage;
    QVector<CpuStat> m_prevStats;   // index 0 = aggregate "cpu", 1..N = per-core

    // Memory
    double m_memUsage   = 0.0;
    qint64 m_memTotal   = 0;
    qint64 m_memUsed    = 0;
    qint64 m_memFree    = 0;
    qint64 m_memCached  = 0;
    qint64 m_memBuffers = 0;
    double m_swapUsage  = 0.0;
    qint64 m_swapTotal  = 0;
    qint64 m_swapUsed   = 0;

    // Load
    double m_load1  = 0.0;
    double m_load5  = 0.0;
    double m_load15 = 0.0;
};

// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>

/**
 * @brief Reports per-GPU utilization and VRAM usage from sysfs.
 *
 * Enumerates /sys/class/drm/card<N>/device entries and reads:
 *   - gpu_busy_percent (or similar) for GPU load, when available
 *   - mem_info_vram_used / mem_info_vram_total for VRAM usage, when available
 *
 * Exposed to QML as a singleton via the wmdockplugin QML extension.
 */
class GpuMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList gpus
               READ gpus
               NOTIFY gpusChanged)

    Q_PROPERTY(int updateInterval
               READ  updateInterval
               WRITE setUpdateInterval
               NOTIFY updateIntervalChanged)

public:
    explicit GpuMonitor(QObject *parent = nullptr);

    QVariantList gpus()       const { return m_gpus; }
    int  updateInterval()     const;
    void setUpdateInterval(int ms);

Q_SIGNALS:
    void gpusChanged();
    void updateIntervalChanged();

private Q_SLOTS:
    void update();

private:
    struct GpuInfo {
        QString key;
        QString name;
        QString driver;
        QString busyPath;
        QString vramUsedPath;
        QString vramTotalPath;
    };

    static QString readTextFile(const QString &path);
    static quint64 readUInt64File(const QString &path, bool *ok);
    static QString driverNameFromPath(const QString &devicePath);
    static QString buildGpuName(const QString &card, const QString &devicePath, const QString &driver);
    void scanGpus();

    QTimer m_timer;
    QVariantList m_gpus;
    QList<GpuInfo> m_gpuInfos;
    int m_ticksUntilRescan = 0;
};

// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>

/**
 * @brief Reports per-GPU utilisation and VRAM usage for mixed-vendor environments.
 *
 * Enumerates /sys/class/drm/card<N>/device entries. For each GPU the kernel
 * driver name selects the appropriate metric backend:
 *
 *  - AMD (amdgpu/radeon) and Intel (i915/xe) GPUs are read from sysfs.
 *    Intel GPUs use shared system RAM so dedicated VRAM is not reported.
 *  - NVIDIA proprietary driver: NVML (libnvidia-ml) is loaded at run time via
 *    dlopen — no build-time NVIDIA headers are required. If the library is
 *    absent, nvidia-smi is used as a subprocess fallback.
 *  - nouveau and unknown drivers: sysfs is probed; only attributes that are
 *    actually present are reported.
 *
 * The QML data contract (hasBusy, busyPercent, hasVram, vramUsedBytes,
 * vramTotalBytes, vramPercent) is identical regardless of backend.
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
    ~GpuMonitor() override;

    QVariantList gpus()       const { return m_gpus; }
    int  updateInterval()     const;
    void setUpdateInterval(int ms);

Q_SIGNALS:
    void gpusChanged();
    void updateIntervalChanged();

private Q_SLOTS:
    void update();

private:
    // Selects how metrics are read for a particular GPU card.
    enum class Backend {
        Sysfs,       // AMD, Intel, nouveau: read from /sys/class/drm/card*/device/
        NvidiaNvml,  // NVIDIA proprietary: NVML via dlopen(libnvidia-ml)
        NvidiaSmi,   // NVIDIA proprietary fallback: subprocess nvidia-smi
    };

    struct GpuInfo {
        QString key;
        QString name;
        QString driver;
        Backend backend = Backend::Sysfs;

        // Sysfs paths (Sysfs backend)
        QString busyPath;
        QString vramUsedPath;
        QString vramTotalPath;

        // NVIDIA: PCI bus ID (e.g. "0000:01:00.0") — used by both NVML and SMI backends
        QString pciBusId;
        // NVIDIA NVML: opaque device handle (nvmlDevice_t stored as void *)
        void *nvmlDevice = nullptr;
    };

    // Sysfs helpers
    static QString readTextFile(const QString &path);
    static quint64 readUInt64File(const QString &path, bool *ok);
    static QString driverNameFromPath(const QString &devicePath);
    static QString buildGpuName(const QString &card, const QString &devicePath, const QString &driver);
    static QString readPciBusId(const QString &cardPath);

    // NVML lifecycle
    bool tryInitNvml();
    void shutdownNvml();
    bool openNvmlDevice(GpuInfo &info);

    void scanGpus();

    QTimer m_timer;
    QVariantList m_gpus;
    QList<GpuInfo> m_gpuInfos;
    int m_ticksUntilRescan = 0;

    // NVML shared library state — one handle shared across all NVIDIA cards
    void *m_nvmlLib         = nullptr;
    bool  m_nvmlInitialized = false;
    void *m_fnNvmlInit      = nullptr;
    void *m_fnNvmlShutdown  = nullptr;
    void *m_fnNvmlGetHandle = nullptr;
    void *m_fnNvmlGetUtil   = nullptr;
    void *m_fnNvmlGetMem    = nullptr;
};

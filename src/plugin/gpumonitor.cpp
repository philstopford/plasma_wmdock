// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "gpumonitor.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QVariantMap>
#include <QtGlobal>
#include <cstring>
#include <dlfcn.h>
#include <utility>

// ---------------------------------------------------------------------------
// Minimal NVML type declarations — no NVIDIA headers required at build time.
//
// Field layouts match the NVML C API (nvidia-ml.h). These types are ABI-stable
// and have not changed since NVML was first released.
// ---------------------------------------------------------------------------
using NvmlReturn = unsigned int;
static constexpr NvmlReturn NVML_SUCCESS = 0u;

struct NvmlUtilization {
    unsigned int gpu;       // GPU kernel activity, 0–100 %
    unsigned int memory;    // Memory I/O activity, 0–100 %
};

struct NvmlMemory {
    unsigned long long total;   // Total installed frame-buffer memory, bytes
    unsigned long long free;    // Unallocated memory, bytes
    unsigned long long used;    // Allocated memory, bytes
};

using FnNvmlInit      = NvmlReturn (*)();
using FnNvmlShutdown  = NvmlReturn (*)();
using FnNvmlGetHandle = NvmlReturn (*)(const char *, void **);
using FnNvmlGetUtil   = NvmlReturn (*)(void *, NvmlUtilization *);
using FnNvmlGetMem    = NvmlReturn (*)(void *, NvmlMemory *);

// Type-safe cast from dlsym() void* to a function pointer via memcpy.
// Avoids strict-aliasing undefined behaviour while still working on every
// POSIX platform where data-pointer and function-pointer representations
// are the same size.
template<typename Fn>
static Fn fnCast(void *sym)
{
    static_assert(sizeof(Fn) == sizeof(void *), "function/data pointer size mismatch");
    Fn fn = nullptr;
    std::memcpy(&fn, &sym, sizeof(fn));
    return fn;
}

// Timeout for a single nvidia-smi invocation, in milliseconds.
static constexpr int NVIDIA_SMI_TIMEOUT_MS = 1500;

// Bytes per mebibyte — nvidia-smi reports memory in MiB.
static constexpr quint64 MIB_TO_BYTES = 1024ULL * 1024ULL;

// ---------------------------------------------------------------------------

GpuMonitor::GpuMonitor(QObject *parent)
    : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &GpuMonitor::update);
    m_timer.setInterval(2000);   // refresh every 2 s
    m_timer.start();

    update();
}

GpuMonitor::~GpuMonitor()
{
    shutdownNvml();
}

int GpuMonitor::updateInterval() const
{
    return m_timer.interval();
}

void GpuMonitor::setUpdateInterval(int ms)
{
    if (ms == m_timer.interval()) {
        return;
    }
    m_timer.setInterval(ms);
    Q_EMIT updateIntervalChanged();
}

// ---------------------------------------------------------------------------
// Sysfs helpers
// ---------------------------------------------------------------------------

QString GpuMonitor::readTextFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromLatin1(f.readAll()).trimmed();
}

quint64 GpuMonitor::readUInt64File(const QString &path, bool *ok)
{
    const QString raw = readTextFile(path);
    bool localOk = false;
    const quint64 value = raw.toULongLong(&localOk);
    if (ok) {
        *ok = localOk;
    }
    return value;
}

QString GpuMonitor::driverNameFromPath(const QString &devicePath)
{
    QFileInfo driverLink(devicePath + QStringLiteral("/driver"));
    if (!driverLink.exists()) {
        return QString();
    }
    const QString target = driverLink.symLinkTarget();
    if (target.isEmpty()) {
        return QString();
    }
    return QFileInfo(target).fileName();
}

QString GpuMonitor::buildGpuName(const QString &card, const QString &devicePath, const QString &driver)
{
    QString vendor = readTextFile(devicePath + QStringLiteral("/vendor"));
    QString device = readTextFile(devicePath + QStringLiteral("/device"));

    if (vendor.startsWith(QLatin1String("0x"))) {
        vendor = vendor.mid(2);
    }
    if (device.startsWith(QLatin1String("0x"))) {
        device = device.mid(2);
    }

    QString name = card;
    if (!driver.isEmpty()) {
        name += QStringLiteral(" (") + driver + QLatin1Char(')');
    }
    if (!vendor.isEmpty() || !device.isEmpty()) {
        name += QStringLiteral(" [") + vendor + QLatin1Char(':') + device + QLatin1Char(']');
    }
    return name;
}

QString GpuMonitor::readPciBusId(const QString &cardPath)
{
    // /sys/class/drm/card<N>/device/uevent contains a line of the form:
    //   PCI_SLOT_NAME=0000:01:00.0
    const QString uevent = readTextFile(cardPath + QStringLiteral("/device/uevent"));
    static const QRegularExpression re(QStringLiteral("^PCI_SLOT_NAME=(.+)$"),
                                       QRegularExpression::MultilineOption);
    const QRegularExpressionMatch m = re.match(uevent);
    if (m.hasMatch()) {
        return m.captured(1).trimmed();
    }
    return QString();
}

// ---------------------------------------------------------------------------
// NVML lifecycle
// ---------------------------------------------------------------------------

bool GpuMonitor::tryInitNvml()
{
    if (m_nvmlInitialized) {
        return true;
    }

    m_nvmlLib = dlopen("libnvidia-ml.so.1", RTLD_LAZY | RTLD_LOCAL);
    if (!m_nvmlLib) {
        qWarning("GpuMonitor: could not load libnvidia-ml.so.1: %s", dlerror());
        return false;
    }

    m_fnNvmlInit      = dlsym(m_nvmlLib, "nvmlInit_v2");
    m_fnNvmlShutdown  = dlsym(m_nvmlLib, "nvmlShutdown");
    m_fnNvmlGetHandle = dlsym(m_nvmlLib, "nvmlDeviceGetHandleByPciBusId_v2");
    m_fnNvmlGetUtil   = dlsym(m_nvmlLib, "nvmlDeviceGetUtilizationRates");
    m_fnNvmlGetMem    = dlsym(m_nvmlLib, "nvmlDeviceGetMemoryInfo");

    if (!m_fnNvmlInit || !m_fnNvmlShutdown || !m_fnNvmlGetHandle
        || !m_fnNvmlGetUtil || !m_fnNvmlGetMem) {
        shutdownNvml();
        return false;
    }

    const NvmlReturn ret = fnCast<FnNvmlInit>(m_fnNvmlInit)();
    if (ret != NVML_SUCCESS) {
        shutdownNvml();
        return false;
    }

    m_nvmlInitialized = true;
    return true;
}

void GpuMonitor::shutdownNvml()
{
    if (m_nvmlInitialized && m_fnNvmlShutdown) {
        fnCast<FnNvmlShutdown>(m_fnNvmlShutdown)();
        m_nvmlInitialized = false;
    }
    if (m_nvmlLib) {
        dlclose(m_nvmlLib);
        m_nvmlLib         = nullptr;
        m_fnNvmlInit      = nullptr;
        m_fnNvmlShutdown  = nullptr;
        m_fnNvmlGetHandle = nullptr;
        m_fnNvmlGetUtil   = nullptr;
        m_fnNvmlGetMem    = nullptr;
    }
}

bool GpuMonitor::openNvmlDevice(GpuInfo &info)
{
    if (!m_nvmlInitialized || info.pciBusId.isEmpty()) {
        return false;
    }
    void *handle = nullptr;
    const NvmlReturn ret = fnCast<FnNvmlGetHandle>(m_fnNvmlGetHandle)(
        info.pciBusId.toLatin1().constData(), &handle);
    if (ret != NVML_SUCCESS || !handle) {
        return false;
    }
    info.nvmlDevice = handle;
    return true;
}

// ---------------------------------------------------------------------------
// GPU topology scan
// ---------------------------------------------------------------------------

void GpuMonitor::scanGpus()
{
    m_gpuInfos.clear();

    QDir drmDir(QStringLiteral("/sys/class/drm"));
    const QStringList entries = drmDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    static const QRegularExpression cardRe(QStringLiteral("^card\\d+$"));

    for (const QString &entry : entries) {
        if (!cardRe.match(entry).hasMatch()) {
            continue;
        }

        const QString cardPath   = drmDir.absoluteFilePath(entry);
        const QString devicePath = cardPath + QStringLiteral("/device");
        if (!QFileInfo::exists(devicePath)) {
            continue;
        }

        GpuInfo info;
        info.key    = entry;
        info.driver = driverNameFromPath(devicePath);
        info.name   = buildGpuName(entry, devicePath, info.driver);

        const bool isNvidia = (info.driver == QLatin1String("nvidia"));
        const bool isIntel  = (info.driver == QLatin1String("i915")
                                || info.driver == QLatin1String("xe"));

        if (isNvidia) {
            // NVIDIA proprietary driver: prefer NVML, fall back to nvidia-smi.
            info.pciBusId = readPciBusId(cardPath);

            if (tryInitNvml() && openNvmlDevice(info)) {
                info.backend = Backend::NvidiaNvml;
            } else {
                info.backend = Backend::NvidiaSmi;
            }
        } else {
            // AMD (amdgpu/radeon), Intel (i915/xe), nouveau, and unknown drivers:
            // probe whichever sysfs attributes are actually present.
            info.backend = Backend::Sysfs;

            const QStringList busyCandidates = {
                QStringLiteral("/gpu_busy_percent"),
                QStringLiteral("/gpu_busy"),
                QStringLiteral("/busy_percent"),
            };
            for (const QString &candidate : busyCandidates) {
                const QString path = devicePath + candidate;
                if (QFileInfo::exists(path)) {
                    info.busyPath = path;
                    break;
                }
            }

            // Intel GPUs use shared system RAM; dedicated VRAM sysfs files are
            // absent. Skip the probe to avoid surfacing N/A for VRAM.
            if (!isIntel) {
                const QString vramUsedPath  = devicePath + QStringLiteral("/mem_info_vram_used");
                const QString vramTotalPath = devicePath + QStringLiteral("/mem_info_vram_total");
                if (QFileInfo::exists(vramUsedPath) && QFileInfo::exists(vramTotalPath)) {
                    info.vramUsedPath  = vramUsedPath;
                    info.vramTotalPath = vramTotalPath;
                }
            }
        }

        m_gpuInfos.append(info);
    }
}

// ---------------------------------------------------------------------------
// Per-tick update
// ---------------------------------------------------------------------------

void GpuMonitor::update()
{
    if (m_ticksUntilRescan <= 0) {
        scanGpus();
        const int intervalMs = qMax(1, m_timer.interval());
        m_ticksUntilRescan = qMax(1, 30000 / intervalMs);   // rescan topology about every 30 s
    } else {
        --m_ticksUntilRescan;
    }

    QVariantList newGpus;
    newGpus.reserve(m_gpuInfos.size());

    for (const GpuInfo &info : std::as_const(m_gpuInfos)) {
        QVariantMap map;
        map[QStringLiteral("key")]    = info.key;
        map[QStringLiteral("name")]   = info.name;
        map[QStringLiteral("driver")] = info.driver;

        double  busyPct   = -1.0;
        bool    hasBusy   = false;
        quint64 vramUsed  = 0;
        quint64 vramTotal = 0;
        bool    hasVram   = false;

        switch (info.backend) {

        case Backend::Sysfs: {
            bool busyOk = false;
            const quint64 busyRaw = info.busyPath.isEmpty()
                                    ? 0 : readUInt64File(info.busyPath, &busyOk);
            if (busyOk) {
                busyPct = qBound(0.0, double(busyRaw), 100.0);
                hasBusy = true;
            }

            bool usedOk = false, totalOk = false;
            vramUsed  = info.vramUsedPath.isEmpty()
                        ? 0 : readUInt64File(info.vramUsedPath,  &usedOk);
            vramTotal = info.vramTotalPath.isEmpty()
                        ? 0 : readUInt64File(info.vramTotalPath, &totalOk);
            hasVram   = usedOk && totalOk && vramTotal > 0;
            break;
        }

        case Backend::NvidiaNvml: {
            if (info.nvmlDevice && m_nvmlInitialized) {
                NvmlUtilization util{};
                if (fnCast<FnNvmlGetUtil>(m_fnNvmlGetUtil)(info.nvmlDevice, &util) == NVML_SUCCESS) {
                    busyPct = qBound(0.0, double(util.gpu), 100.0);
                    hasBusy = true;
                }

                NvmlMemory mem{};
                if (fnCast<FnNvmlGetMem>(m_fnNvmlGetMem)(info.nvmlDevice, &mem) == NVML_SUCCESS
                    && mem.total > 0) {
                    vramUsed  = mem.used;
                    vramTotal = mem.total;
                    hasVram   = true;
                }
            }
            break;
        }

        case Backend::NvidiaSmi: {
            if (!info.pciBusId.isEmpty()) {
                // nvidia-smi -i <busId> --query-gpu=utilization.gpu,memory.used,memory.total
                //            --format=csv,noheader,nounits
                // Output example: "15, 1024, 8192"
                // Memory is reported in MiB; convert to bytes.
                QProcess proc;
                proc.start(QStringLiteral("nvidia-smi"),
                           {QStringLiteral("-i"),        info.pciBusId,
                            QStringLiteral("--query-gpu=utilization.gpu,memory.used,memory.total"),
                            QStringLiteral("--format=csv,noheader,nounits")});
                if (proc.waitForFinished(NVIDIA_SMI_TIMEOUT_MS)) {
                    const QString out = QString::fromLatin1(proc.readAllStandardOutput()).trimmed();
                    const QStringList parts = out.split(QLatin1Char(','));
                    if (parts.size() >= 3) {
                        bool gpuOk = false, usedOk = false, totalOk = false;
                        const double    gpu   = parts.at(0).trimmed().toDouble(&gpuOk);
                        const quint64   used  = parts.at(1).trimmed().toULongLong(&usedOk);
                        const quint64   total = parts.at(2).trimmed().toULongLong(&totalOk);
                        if (gpuOk) {
                            busyPct = qBound(0.0, gpu, 100.0);
                            hasBusy = true;
                        }
                        if (usedOk && totalOk && total > 0) {
                            vramUsed  = used  * MIB_TO_BYTES;
                            vramTotal = total * MIB_TO_BYTES;
                            hasVram   = true;
                        }
                    }
                }
            }
            break;
        }

        } // switch (info.backend)

        map[QStringLiteral("busyPercent")]    = busyPct;
        map[QStringLiteral("hasBusy")]        = hasBusy;
        map[QStringLiteral("vramUsedBytes")]  = qint64(vramUsed);
        map[QStringLiteral("vramTotalBytes")] = qint64(vramTotal);
        map[QStringLiteral("vramPercent")]    = hasVram
                                                ? (100.0 * double(vramUsed) / double(vramTotal))
                                                : -1.0;
        map[QStringLiteral("hasVram")]        = hasVram;

        newGpus.append(map);
    }

    m_gpus = newGpus;
    Q_EMIT gpusChanged();
}

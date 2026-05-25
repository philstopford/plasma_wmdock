// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "gpumonitor.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QVariantMap>
#include <QtGlobal>
#include <utility>

GpuMonitor::GpuMonitor(QObject *parent)
    : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &GpuMonitor::update);
    m_timer.setInterval(2000);   // refresh every 2 s
    m_timer.start();

    update();
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

        const QString cardPath = drmDir.absoluteFilePath(entry);
        const QString devicePath = cardPath + QStringLiteral("/device");
        if (!QFileInfo::exists(devicePath)) {
            continue;
        }

        GpuInfo info;
        info.key = entry;
        info.driver = driverNameFromPath(devicePath);
        info.name = buildGpuName(entry, devicePath, info.driver);

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

        const QString vramUsedPath = devicePath + QStringLiteral("/mem_info_vram_used");
        const QString vramTotalPath = devicePath + QStringLiteral("/mem_info_vram_total");
        if (QFileInfo::exists(vramUsedPath) && QFileInfo::exists(vramTotalPath)) {
            info.vramUsedPath = vramUsedPath;
            info.vramTotalPath = vramTotalPath;
        }

        m_gpuInfos.append(info);
    }
}

void GpuMonitor::update()
{
    scanGpus();

    QVariantList newGpus;
    newGpus.reserve(m_gpuInfos.size());

    for (const GpuInfo &info : std::as_const(m_gpuInfos)) {
        QVariantMap map;
        map[QStringLiteral("key")] = info.key;
        map[QStringLiteral("name")] = info.name;
        map[QStringLiteral("driver")] = info.driver;

        bool busyOk = false;
        const quint64 busyRaw = info.busyPath.isEmpty() ? 0 : readUInt64File(info.busyPath, &busyOk);
        const double busyPct = busyOk ? qBound(0.0, double(busyRaw), 100.0) : -1.0;
        map[QStringLiteral("busyPercent")] = busyPct;
        map[QStringLiteral("hasBusy")] = busyOk;

        bool usedOk = false;
        bool totalOk = false;
        const quint64 vramUsed = info.vramUsedPath.isEmpty() ? 0 : readUInt64File(info.vramUsedPath, &usedOk);
        const quint64 vramTotal = info.vramTotalPath.isEmpty() ? 0 : readUInt64File(info.vramTotalPath, &totalOk);
        const bool hasVram = usedOk && totalOk && vramTotal > 0;

        map[QStringLiteral("vramUsedBytes")] = qint64(vramUsed);
        map[QStringLiteral("vramTotalBytes")] = qint64(vramTotal);
        map[QStringLiteral("vramPercent")] = hasVram ? (100.0 * double(vramUsed) / double(vramTotal)) : -1.0;
        map[QStringLiteral("hasVram")] = hasVram;

        newGpus.append(map);
    }

    m_gpus = newGpus;
    Q_EMIT gpusChanged();
}

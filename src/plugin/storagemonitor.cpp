// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "storagemonitor.h"

#include <QStorageInfo>
#include <QVariantMap>

StorageMonitor::StorageMonitor(QObject *parent)
    : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &StorageMonitor::update);
    m_timer.setInterval(30000);  // refresh every 30 s
    m_timer.start();

    update();
}

int StorageMonitor::updateInterval() const
{
    return m_timer.interval();
}

void StorageMonitor::setUpdateInterval(int ms)
{
    if (ms == m_timer.interval())
        return;
    m_timer.setInterval(ms);
    Q_EMIT updateIntervalChanged();
}

// ---------------------------------------------------------------------------
// File-system types that should be hidden (no real storage meaning).
// ---------------------------------------------------------------------------
bool StorageMonitor::isVirtual(const QString &fsType)
{
    static const QStringList virtualTypes = {
        QStringLiteral("tmpfs"),
        QStringLiteral("devtmpfs"),
        QStringLiteral("proc"),
        QStringLiteral("sysfs"),
        QStringLiteral("cgroup"),
        QStringLiteral("cgroup2"),
        QStringLiteral("pstore"),
        QStringLiteral("efivarfs"),
        QStringLiteral("securityfs"),
        QStringLiteral("debugfs"),
        QStringLiteral("tracefs"),
        QStringLiteral("configfs"),
        QStringLiteral("fusectl"),
        QStringLiteral("hugetlbfs"),
        QStringLiteral("mqueue"),
        QStringLiteral("devpts"),
        QStringLiteral("overlay"),
        QStringLiteral("autofs"),
        QStringLiteral("ramfs"),
        QStringLiteral("squashfs"),  // snap mount points
        QStringLiteral("iso9660"),   // CD-ROM (no write, skip)
        QStringLiteral("udf"),
    };
    return virtualTypes.contains(fsType);
}

void StorageMonitor::update()
{
    QVariantList newVolumes;

    const QList<QStorageInfo> volumes = QStorageInfo::mountedVolumes();
    for (const QStorageInfo &si : volumes) {
        if (!si.isValid() || !si.isReady())
            continue;

        const QString fsType = QString::fromLatin1(si.fileSystemType());
        if (isVirtual(fsType))
            continue;

        const qint64 total = si.bytesTotal();
        if (total <= 0)
            continue;

        const qint64 avail = si.bytesAvailable();
        const qint64 used  = total - avail;

        // Short display name: last path component, or "/" for root
        QString displayName = si.rootPath();
        const int slash = displayName.lastIndexOf(QLatin1Char('/'));
        if (slash > 0)
            displayName = displayName.mid(slash + 1);
        if (displayName.isEmpty())
            displayName = QStringLiteral("/");

        QVariantMap m;
        m[QStringLiteral("device")]      = si.device();
        m[QStringLiteral("mountPath")]   = si.rootPath();
        m[QStringLiteral("displayName")] = displayName;
        m[QStringLiteral("fsType")]      = fsType;
        m[QStringLiteral("totalBytes")]  = total;
        m[QStringLiteral("availBytes")]  = avail;
        m[QStringLiteral("usedBytes")]   = used;
        m[QStringLiteral("usedPct")]     = total > 0 ? qRound(100.0 * used / total) : 0;
        newVolumes.append(m);
    }

    // Some environments only expose a usable root volume through QStorageInfo::root().
    if (newVolumes.isEmpty()) {
        const QStorageInfo root = QStorageInfo::root();
        if (root.isValid() && root.isReady() && root.bytesTotal() > 0) {
            const qint64 total = root.bytesTotal();
            const qint64 avail = root.bytesAvailable();
            const qint64 used  = total - avail;
            const QString fsType = QString::fromLatin1(root.fileSystemType());

            if (!isVirtual(fsType)) {
                QVariantMap m;
                m[QStringLiteral("device")]      = root.device();
                m[QStringLiteral("mountPath")]   = root.rootPath();
                m[QStringLiteral("displayName")] = QStringLiteral("/");
                m[QStringLiteral("fsType")]      = fsType;
                m[QStringLiteral("totalBytes")]  = total;
                m[QStringLiteral("availBytes")]  = avail;
                m[QStringLiteral("usedBytes")]   = used;
                m[QStringLiteral("usedPct")]     = qRound(100.0 * used / total);
                newVolumes.append(m);
            }
        }
    }

    m_volumes = newVolumes;
    Q_EMIT volumesChanged();
}

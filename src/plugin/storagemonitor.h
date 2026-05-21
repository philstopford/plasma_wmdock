// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>

/**
 * @brief Reports storage usage of mounted volumes.
 *
 * Uses QStorageInfo to enumerate mounted file systems, filtering out
 * virtual/pseudo file systems (tmpfs, procfs, sysfs, cgroup, devtmpfs, …).
 *
 * Each volume is described by a QVariantMap with keys:
 *   device      - device or remote host string (e.g. "/dev/sda1", "192.168.1.1:/export")
 *   mountPath   - mount point (e.g. "/", "/home", "/mnt/data")
 *   displayName - short human label (last component of mountPath, or "/" for root)
 *   fsType      - file-system type string (e.g. "ext4", "btrfs")
 *   totalBytes  - total capacity in bytes (qint64)
 *   availBytes  - bytes available to the current user (qint64)
 *   usedBytes   - bytes in use (totalBytes - availBytes) (qint64)
 *   usedPct     - percentage used (double, 0–100)
 *
 * Exposed to QML as a singleton via the wmdockplugin QML extension.
 */
class StorageMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList volumes
               READ volumes
               NOTIFY volumesChanged)

    Q_PROPERTY(int updateInterval
               READ  updateInterval
               WRITE setUpdateInterval
               NOTIFY updateIntervalChanged)

public:
    explicit StorageMonitor(QObject *parent = nullptr);

    QVariantList volumes()      const { return m_volumes; }
    int  updateInterval()       const;
    void setUpdateInterval(int ms);

Q_SIGNALS:
    void volumesChanged();
    void updateIntervalChanged();

private Q_SLOTS:
    void update();

private:
    static bool isVirtual(const QString &fsType);

    QTimer       m_timer;
    QVariantList m_volumes;
};

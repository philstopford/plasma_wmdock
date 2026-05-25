// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QHash>
#include <QObject>
#include <QPair>
#include <QString>
#include <QTimer>
#include <QVariantList>

/**
 * @brief Tracks network interface traffic using /proc/net/dev.
 *
 * Reports bytes-per-second received and transmitted for a
 * selected interface.  The interface list is auto-populated.
 *
 * allIfaceStats exposes per-interface rates for all non-loopback
 * interfaces simultaneously, enabling multi-interface display modes.
 */
class NetworkMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString      iface        READ iface        WRITE setIface   NOTIFY ifaceChanged)
    Q_PROPERTY(QStringList  interfaces   READ interfaces   NOTIFY interfacesChanged)
    Q_PROPERTY(double       rxBytesPerSec READ rxBytesPerSec NOTIFY statsChanged)
    Q_PROPERTY(double       txBytesPerSec READ txBytesPerSec NOTIFY statsChanged)
    Q_PROPERTY(qint64       rxBytesTotal READ rxBytesTotal NOTIFY statsChanged)
    Q_PROPERTY(qint64       txBytesTotal READ txBytesTotal NOTIFY statsChanged)
    Q_PROPERTY(double       rxMaxRate    READ rxMaxRate    NOTIFY statsChanged)
    Q_PROPERTY(double       txMaxRate    READ txMaxRate    NOTIFY statsChanged)
    // Per-interface stats for all non-loopback interfaces.
    // Each element is a map: { name, rxRate, txRate, rxMax, txMax }
    Q_PROPERTY(QVariantList allIfaceStats READ allIfaceStats NOTIFY statsChanged)
    Q_PROPERTY(int updateInterval
               READ  updateInterval
               WRITE setUpdateInterval
               NOTIFY updateIntervalChanged)

public:
    explicit NetworkMonitor(QObject *parent = nullptr);

    QString      iface()          const { return m_iface; }
    QStringList  interfaces()     const { return m_interfaces; }
    double       rxBytesPerSec()  const { return m_rxRate; }
    double       txBytesPerSec()  const { return m_txRate; }
    qint64       rxBytesTotal()   const { return m_rxTotal; }
    qint64       txBytesTotal()   const { return m_txTotal; }
    double       rxMaxRate()      const { return m_rxMax; }
    double       txMaxRate()      const { return m_txMax; }
    QVariantList allIfaceStats()  const;
    int          updateInterval() const;
    void         setIface(const QString &iface);
    void         setUpdateInterval(int ms);

Q_SIGNALS:
    void ifaceChanged();
    void interfacesChanged();
    void statsChanged();
    void updateIntervalChanged();

private Q_SLOTS:
    void update();

private:
    struct IfaceStat {
        qint64 rxPrev  = 0,   txPrev  = 0;
        double rxRate  = 0.0, txRate  = 0.0;
        double rxMax   = 1.0, txMax   = 1.0;
        bool   seeded  = false;   // true once we have a valid prev sample
    };

    void    scanInterfaces();
    void    readAllRawStats(QHash<QString, QPair<qint64,qint64>> &out) const;
    QString pickAutoIface() const;

    QTimer      m_timer;
    QString     m_requestedIface;   // "" = auto; set by callers of setIface()
    QString     m_iface;            // currently active (resolved) interface
    QStringList m_interfaces;
    QHash<QString, IfaceStat> m_allStats;   // per-interface tracking

    // Single-iface properties derived from m_allStats[m_iface] on each tick
    double m_rxRate  = 0.0, m_txRate  = 0.0;
    qint64 m_rxTotal = 0,   m_txTotal = 0;
    double m_rxMax   = 1.0, m_txMax   = 1.0;
    qint64 m_lastMs  = 0;
};

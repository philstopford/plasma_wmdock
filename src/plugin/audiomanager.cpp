// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "audiomanager.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMetaType>
#include <QVariant>
#include <cmath>

// PulseAudio volume constant: PA_VOLUME_NORM = 65536
static const quint32 PA_VOLUME_NORM = 65536;

AudioManager::AudioManager(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<QList<quint32>>();
    connectToPulse();
}

bool AudioManager::connectToPulse()
{
    // PulseAudio / PipeWire-pulse server address is found via
    // the PULSE_DBUS_SERVER env var or the session D-Bus lookup
    auto sessionBus = QDBusConnection::sessionBus();

    QDBusInterface lookup(QStringLiteral("org.PulseAudio1"),
                          QStringLiteral("/org/pulseaudio/server_lookup1"),
                          QStringLiteral("org.PulseAudio.ServerLookup1"),
                          sessionBus);
    if (!lookup.isValid()) return false;

    const QString address = lookup.property("Address").toString();
    if (address.isEmpty()) return false;

    auto paBus = QDBusConnection::connectToBus(address, QStringLiteral("pulse"));

    m_core = new QDBusInterface(QStringLiteral("org.PulseAudio.Core1"),
                                QStringLiteral("/org/pulseaudio/core1"),
                                QStringLiteral("org.PulseAudio.Core1"),
                                paBus, this);
    if (!m_core->isValid()) return false;

    // Get the first sink
    QDBusReply<QList<QDBusObjectPath>> sinks = m_core->call(QStringLiteral("GetSinks"));
    if (!sinks.isValid() || sinks.value().isEmpty()) return false;

    const QString sinkPath = sinks.value().first().path();
    m_sink = new QDBusInterface(QStringLiteral("org.PulseAudio.Core1"),
                                sinkPath,
                                QStringLiteral("org.PulseAudio.Core1.Device"),
                                paBus, this);

    // Connect property change signals
    paBus.connect(QString(), sinkPath,
                  QStringLiteral("org.PulseAudio.Core1.Device"),
                  QStringLiteral("VolumeUpdated"),
                  this, SLOT(onVolumeChanged(QDBusVariant)));
    paBus.connect(QString(), sinkPath,
                  QStringLiteral("org.PulseAudio.Core1.Device"),
                  QStringLiteral("MuteUpdated"),
                  this, SLOT(onMuteChanged(QDBusVariant)));

    m_available = true;
    Q_EMIT availableChanged();
    refreshSinkInfo();
    return true;
}

void AudioManager::refreshSinkInfo()
{
    if (!m_sink) return;

    // Volume is a list of per-channel quint32 values
    const QVariant volVar = m_sink->property("Volume");
    QList<quint32> channels = volVar.value<QList<quint32>>();
    if (!channels.isEmpty()) {
        const quint32 avg = *std::max_element(channels.begin(), channels.end());
        const int pct = qBound(0, int(std::round(double(avg) / PA_VOLUME_NORM * 100.0)), 150);
        if (pct != m_volume) {
            m_volume = pct;
            Q_EMIT volumeChanged();
        }
    }

    const bool muted = m_sink->property("Mute").toBool();
    if (muted != m_muted) {
        m_muted = muted;
        Q_EMIT mutedChanged();
    }
}

void AudioManager::setVolume(int percent)
{
    if (!m_sink) return;
    percent = qBound(0, percent, 150);
    const quint32 vol = quint32(double(percent) / 100.0 * PA_VOLUME_NORM);
    m_sink->setProperty("Volume", QVariant::fromValue(QList<quint32>{vol, vol}));
}

void AudioManager::setMuted(bool muted)
{
    if (!m_sink) return;
    m_sink->setProperty("Mute", muted);
}

void AudioManager::toggleMute()
{
    setMuted(!m_muted);
}

void AudioManager::onVolumeChanged(const QDBusVariant & /*v*/)
{
    refreshSinkInfo();
}

void AudioManager::onMuteChanged(const QDBusVariant & /*v*/)
{
    refreshSinkInfo();
}

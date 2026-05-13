// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QDBusInterface>

/**
 * @brief Audio volume management via PulseAudio / PipeWire D-Bus.
 *
 * Wraps the org.PulseAudio.Core1 D-Bus API (which is also exported
 * by PipeWire-pulse).  Falls back to a no-op stub when neither
 * daemon is available.
 */
class AudioManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int     volume       READ volume       WRITE setVolume   NOTIFY volumeChanged)
    Q_PROPERTY(bool    muted        READ muted        WRITE setMuted    NOTIFY mutedChanged)
    Q_PROPERTY(bool    available    READ available    NOTIFY availableChanged)

public:
    explicit AudioManager(QObject *parent = nullptr);

    int  volume()    const { return m_volume; }
    bool muted()     const { return m_muted; }
    bool available() const { return m_available; }

    Q_INVOKABLE void setVolume(int percent);
    Q_INVOKABLE void setMuted(bool muted);
    Q_INVOKABLE void toggleMute();

Q_SIGNALS:
    void volumeChanged();
    void mutedChanged();
    void availableChanged();

private Q_SLOTS:
    void onVolumeChanged(const QDBusVariant &v);
    void onMuteChanged(const QDBusVariant &v);

private:
    bool connectToPulse();
    void refreshSinkInfo();

    QDBusInterface *m_core  = nullptr;
    QDBusInterface *m_sink  = nullptr;
    bool   m_available      = false;
    int    m_volume         = 0;
    bool   m_muted          = false;
};

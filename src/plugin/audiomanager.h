// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QTimer>

/**
 * @brief Audio volume management via pactl (PulseAudio / PipeWire-pulse).
 *
 * Polls the default sink's volume and mute state using pactl every two
 * seconds.  Falls back to an unavailable state when pactl is not present
 * or no default sink exists.
 */
class AudioManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int     volume       READ volume       NOTIFY volumeChanged)
    Q_PROPERTY(bool    muted        READ muted        NOTIFY mutedChanged)
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
    void poll();

private:
    QTimer m_timer;
    QRegularExpression m_volRe;
    bool   m_available = false;
    int    m_volume    = 0;
    bool   m_muted     = false;
};

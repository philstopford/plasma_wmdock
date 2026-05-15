// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "audiomanager.h"

#include <QProcess>
#include <QRegularExpression>

AudioManager::AudioManager(QObject *parent)
    : QObject(parent)
    , m_volRe(QStringLiteral(R"(/ {0,2}(\d+)%)"))
{
    connect(&m_timer, &QTimer::timeout, this, &AudioManager::poll);
    m_timer.setInterval(2000);
    m_timer.start();
    poll(); // initial read
}

void AudioManager::poll()
{
    // Query volume for the default sink
    QProcess vp;
    vp.start(QStringLiteral("pactl"),
             QStringList{QStringLiteral("get-sink-volume"),
                         QStringLiteral("@DEFAULT_SINK@")});
    if (!vp.waitForFinished(500) || vp.exitCode() != 0) {
        if (m_available) {
            m_available = false;
            Q_EMIT availableChanged();
        }
        return;
    }

    if (!m_available) {
        m_available = true;
        Q_EMIT availableChanged();
    }

    // Parse the first percentage from output:
    // "Volume: front-left: 52428 /  80% / -5.94 dB,  front-right: …"
    const QString volOut = QString::fromLocal8Bit(vp.readAllStandardOutput());
    const QRegularExpressionMatch m = m_volRe.match(volOut);
    if (m.hasMatch()) {
        const int vol = qBound(0, m.captured(1).toInt(), 150);
        if (vol != m_volume) {
            m_volume = vol;
            Q_EMIT volumeChanged();
        }
    }

    // Query mute state
    QProcess mp;
    mp.start(QStringLiteral("pactl"),
             QStringList{QStringLiteral("get-sink-mute"),
                         QStringLiteral("@DEFAULT_SINK@")});
    if (mp.waitForFinished(500) && mp.exitCode() == 0) {
        const QString muteOut = QString::fromLocal8Bit(mp.readAllStandardOutput());
        const bool muted = muteOut.contains(QStringLiteral("Mute: yes"));
        if (muted != m_muted) {
            m_muted = muted;
            Q_EMIT mutedChanged();
        }
    }
}

void AudioManager::setVolume(int percent)
{
    percent = qBound(0, percent, 150);
    QProcess::startDetached(QStringLiteral("pactl"),
        QStringList{QStringLiteral("set-sink-volume"),
                    QStringLiteral("@DEFAULT_SINK@"),
                    QString::number(percent) + QLatin1Char('%')});
    if (percent != m_volume) {
        m_volume = percent;
        Q_EMIT volumeChanged();
    }
}

void AudioManager::setMuted(bool muted)
{
    QProcess::startDetached(QStringLiteral("pactl"),
        QStringList{QStringLiteral("set-sink-mute"),
                    QStringLiteral("@DEFAULT_SINK@"),
                    muted ? QStringLiteral("1") : QStringLiteral("0")});
    if (muted != m_muted) {
        m_muted = muted;
        Q_EMIT mutedChanged();
    }
}

void AudioManager::toggleMute()
{
    setMuted(!m_muted);
}

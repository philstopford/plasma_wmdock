// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QByteArray>
#include <QObject>
#include <QProcess>
#include <QVariantList>

/**
 * @brief Real-time audio spectrum monitor backed by CAVA.
 *
 * Spawns `cava` with a config that outputs ASCII bar values to stdout.
 * Parses each line (semicolon-separated integers 0-100) into 16 normalised
 * frequency-band values (0.0–1.0), and derives per-frame RMS, bass, treble,
 * and beat-transient signals.
 *
 * Exposed to QML as the singleton `AudioSpectrum`.
 */
class AudioSpectrumMonitor : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QVariantList bands    READ bands     NOTIFY bandsChanged)
    Q_PROPERTY(qreal        rms      READ rms       NOTIFY bandsChanged)
    Q_PROPERTY(qreal        bass     READ bass      NOTIFY bandsChanged)
    Q_PROPERTY(qreal        treble   READ treble    NOTIFY bandsChanged)
    Q_PROPERTY(bool         beat     READ beat      NOTIFY beatChanged)
    Q_PROPERTY(bool         available READ available NOTIFY availableChanged)

public:
    static constexpr int BANDS     = 16;
    static constexpr int ASCII_MAX = 100;

    explicit AudioSpectrumMonitor(QObject *parent = nullptr);
    ~AudioSpectrumMonitor() override;

    QVariantList bands()     const { return m_bands;     }
    qreal        rms()       const { return m_rms;       }
    qreal        bass()      const { return m_bass;      }
    qreal        treble()    const { return m_treble;    }
    bool         beat()      const { return m_beat;      }
    bool         available() const { return m_available; }

Q_SIGNALS:
    void bandsChanged();
    void beatChanged();
    void availableChanged();

private Q_SLOTS:
    void onReadyRead();
    void startCava();

private:
    QString      writeCavaConfig() const;
    void         parseLine(const QByteArray &line);

    QProcess     m_proc;
    QByteArray   m_buffer;

    QVariantList m_bands;
    qreal        m_rms       = 0.0;
    qreal        m_bass      = 0.0;
    qreal        m_treble    = 0.0;
    bool         m_beat      = false;
    bool         m_available = false;

    // Beat detection state
    float        m_bassHistory    = 0.0f;
    int          m_beatCooldown   = 0;

    static constexpr float BEAT_THRESHOLD_MULTIPLIER = 1.4f;   // 40% above baseline
    static constexpr float BEAT_MIN_BASS             = 0.25f;
    static constexpr int   BEAT_COOLDOWN_FRAMES      = 7;       // ~280 ms at 25 fps
    static constexpr float BASS_HISTORY_DECAY        = 0.88f;
    static constexpr float BASS_HISTORY_WEIGHT       = 0.12f;
};

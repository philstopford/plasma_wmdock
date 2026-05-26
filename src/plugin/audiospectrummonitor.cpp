// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "audiospectrummonitor.h"

#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QTimer>

AudioSpectrumMonitor::AudioSpectrumMonitor(QObject *parent)
    : QObject(parent)
{
    m_bands = QVariantList(BANDS, 0.0);

    connect(&m_proc, &QProcess::readyReadStandardOutput,
            this, &AudioSpectrumMonitor::onReadyRead);

    connect(&m_proc, &QProcess::started, this, [this]() {
        if (!m_available) {
            m_available = true;
            Q_EMIT availableChanged();
        }
    });

    connect(&m_proc,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int, QProcess::ExitStatus) {
        if (m_available) {
            m_available = false;
            Q_EMIT availableChanged();
        }
        // Restart after a short delay (e.g. default sink changed)
        QTimer::singleShot(3000, this, &AudioSpectrumMonitor::startCava);
    });

    connect(&m_proc, &QProcess::errorOccurred,
            this, [this](QProcess::ProcessError) {
        if (m_available) {
            m_available = false;
            Q_EMIT availableChanged();
        }
        QTimer::singleShot(5000, this, &AudioSpectrumMonitor::startCava);
    });

    startCava();
}

AudioSpectrumMonitor::~AudioSpectrumMonitor()
{
    m_proc.disconnect();
    if (m_proc.state() != QProcess::NotRunning) {
        m_proc.kill();
        m_proc.waitForFinished(500);
    }
}

// ---------------------------------------------------------------------------
// Config file
// ---------------------------------------------------------------------------

QString AudioSpectrumMonitor::writeCavaConfig() const
{
    const QString path = QDir::tempPath() + QStringLiteral("/wmviz-cava.ini");
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return {};

    QTextStream s(&f);
    s << "[general]\n"
      << "framerate = 25\n"
      << "bars = " << BANDS << "\n"
      << "autosens = 1\n"
      << "lower_cutoff_freq = 50\n"
      << "higher_cutoff_freq = 10000\n"
      << "sleep_timer = 0\n"
      << "[input]\n"
      << "method = pulse\n"
      << "autoconnect = 2\n"
      << "[output]\n"
      << "channels = mono\n"
      << "mono_option = average\n"
      << "method = raw\n"
      << "raw_target = /dev/stdout\n"
      << "data_format = ascii\n"
      << "ascii_max_range = " << ASCII_MAX << "\n"
      << "[smoothing]\n"
      << "noise_reduction = 77\n"
      << "monstercat = 1\n"
      << "waves = 0\n";
    f.close();
    return path;
}

// ---------------------------------------------------------------------------
// CAVA process lifecycle
// ---------------------------------------------------------------------------

void AudioSpectrumMonitor::startCava()
{
    if (m_proc.state() != QProcess::NotRunning)
        return;

    const QString cfgPath = writeCavaConfig();
    if (cfgPath.isEmpty())
        return;

    m_buffer.clear();
    m_proc.start(QStringLiteral("cava"),
                 QStringList{QStringLiteral("-p"), cfgPath});
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

void AudioSpectrumMonitor::onReadyRead()
{
    m_buffer += m_proc.readAllStandardOutput();

    int pos;
    while ((pos = m_buffer.indexOf('\n')) != -1) {
        const QByteArray line = m_buffer.left(pos).trimmed();
        m_buffer = m_buffer.mid(pos + 1);
        if (!line.isEmpty())
            parseLine(line);
    }

    // Guard against unbounded growth if CAVA output has no newlines
    if (m_buffer.size() > 4096)
        m_buffer.clear();
}

void AudioSpectrumMonitor::parseLine(const QByteArray &line)
{
    // CAVA ASCII output: "v0;v1;...;vN-1" or "v0;v1;...;vN-1;"
    QByteArray data = line;
    if (data.endsWith(';'))
        data.chop(1);

    const QList<QByteArray> parts = data.split(';');
    if (parts.size() < BANDS)
        return;

    QVariantList newBands;
    newBands.reserve(BANDS);

    float sum = 0.0f, bassSum = 0.0f, trebleSum = 0.0f;

    for (int i = 0; i < BANDS; i++) {
        bool ok = false;
        const float v = qBound(0.0f,
                               parts[i].trimmed().toFloat(&ok) / ASCII_MAX,
                               1.0f);
        if (!ok)
            return;  // malformed line – discard

        newBands.append(static_cast<double>(v));
        sum += v;
        if (i < 3)
            bassSum += v;
        if (i >= BANDS - 4)
            trebleSum += v;
    }

    m_rms    = static_cast<qreal>(sum / BANDS);
    m_bass   = static_cast<qreal>(bassSum / 3.0f);
    m_treble = static_cast<qreal>(trebleSum / 4.0f);

    // Beat detection: fast upward transient in bass vs. smoothed baseline
    const float bassNow = static_cast<float>(m_bass);
    bool newBeat = false;
    if (m_beatCooldown <= 0
            && bassNow > BEAT_MIN_BASS
            && bassNow > m_bassHistory * BEAT_THRESHOLD_MULTIPLIER) {
        newBeat = true;
        m_beatCooldown = BEAT_COOLDOWN_FRAMES;
    }
    if (m_beatCooldown > 0)
        --m_beatCooldown;
    m_bassHistory = m_bassHistory * BASS_HISTORY_DECAY + bassNow * BASS_HISTORY_WEIGHT;

    m_bands = newBands;

    if (newBeat != m_beat) {
        m_beat = newBeat;
        Q_EMIT beatChanged();
    }
    Q_EMIT bandsChanged();
}

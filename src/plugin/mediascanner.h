// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QStringList>

/**
 * @brief Scans directories for playable audio files.
 *
 * Provides a single invokable method that recursively (one level deep)
 * lists audio files inside a given directory.  Used by the WMPlay applet
 * when the user drops a folder onto it.
 *
 * Recognised extensions (case-insensitive):
 *   mp3  m4a  flac  ogg  opus  wav  aac  wma  ape  aiff  mp4
 *
 * Exposed to QML as a singleton via the wmdockplugin QML extension.
 */
class MediaScanner : public QObject
{
    Q_OBJECT

public:
    explicit MediaScanner(QObject *parent = nullptr);

    /**
     * @brief Scan @p path (file or directory) for audio files.
     *
     * If @p path is a single audio file it is returned as a one-element list.
     * If @p path is a directory its immediate contents are scanned.
     * Sub-directories are not recursed into (keeps response time short).
     *
     * @return Absolute file paths sorted by name.
     */
    Q_INVOKABLE QStringList scan(const QString &path) const;

private:
    static const QStringList s_extensions;
};

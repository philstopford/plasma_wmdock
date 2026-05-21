// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "mediascanner.h"

#include <QDir>
#include <QFileInfo>

const QStringList MediaScanner::s_extensions = {
    QStringLiteral("mp3"),
    QStringLiteral("m4a"),
    QStringLiteral("flac"),
    QStringLiteral("ogg"),
    QStringLiteral("opus"),
    QStringLiteral("wav"),
    QStringLiteral("aac"),
    QStringLiteral("wma"),
    QStringLiteral("ape"),
    QStringLiteral("aiff"),
    QStringLiteral("mp4"),
};

MediaScanner::MediaScanner(QObject *parent)
    : QObject(parent)
{
}

QStringList MediaScanner::scan(const QString &path) const
{
    const QFileInfo fi(path);
    if (!fi.exists())
        return {};

    if (fi.isFile()) {
        const QString ext = fi.suffix().toLower();
        if (s_extensions.contains(ext))
            return { fi.absoluteFilePath() };
        return {};
    }

    if (!fi.isDir())
        return {};

    // Build glob filters for QDir::entryInfoList
    QStringList filters;
    for (const QString &ext : s_extensions) {
        filters << QStringLiteral("*.") + ext;
        filters << QStringLiteral("*.") + ext.toUpper();
    }

    QDir dir(fi.absoluteFilePath());
    const QFileInfoList entries = dir.entryInfoList(
        filters, QDir::Files, QDir::Name | QDir::IgnoreCase);

    QStringList result;
    result.reserve(entries.size());
    for (const QFileInfo &entry : entries)
        result << entry.absoluteFilePath();

    return result;
}

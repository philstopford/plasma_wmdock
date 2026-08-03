// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QVariantMap>

/**
 * @brief Reads a .desktop file and returns key launcher fields.
 *
 * Exposed to QML as the DesktopFileReader singleton (org.kde.plasma.private.wmdock).
 * Using C++ QFile avoids the file:// sandbox restrictions that apply to
 * XMLHttpRequest in QML applet contexts under Plasma 6.
 */
class DesktopFileReader : public QObject
{
    Q_OBJECT

public:
    explicit DesktopFileReader(QObject *parent = nullptr) : QObject(parent) {}

    /**
     * @brief Read a .desktop file and return a QVariantMap with launcher fields.
     *
     * @param fileUrl  Either a @c file:// URL or a bare filesystem path.
     * @return A map with keys @c command, @c icon, @c label, or an empty map
     *         if the file cannot be read or contains no @c Exec= entry.
     */
    Q_INVOKABLE QVariantMap read(const QString &fileUrl) const;

    /**
     * Build a launcher entry for a dropped URL. Desktop files are parsed,
     * local executable files are launched directly, and other URLs use
     * xdg-open.
     */
    Q_INVOKABLE QVariantMap launcherForUrl(const QString &fileUrl) const;
};

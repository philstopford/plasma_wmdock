// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "desktopfilereader.h"

#include <QFile>
#include <QRegularExpression>
#include <QTextStream>
#include <QUrl>

QVariantMap DesktopFileReader::read(const QString &fileUrl) const
{
    // Accept either a file:// URL or a bare filesystem path.
    const QString path = QUrl(fileUrl).isLocalFile()
                         ? QUrl(fileUrl).toLocalFile()
                         : fileUrl;

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    QTextStream in(&file);
    bool   inEntry = false;
    QString name, exec, icon;

    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();

        if (line == QLatin1String("[Desktop Entry]")) {
            inEntry = true;
            continue;
        }
        // Stop at the start of any subsequent section header.
        if (inEntry && !line.isEmpty() && line.startsWith(QLatin1Char('[')))
            break;
        if (!inEntry)
            continue;

        const int eq = line.indexOf(QLatin1Char('='));
        if (eq <= 0)
            continue;

        const QString key = line.left(eq);
        const QString val = line.mid(eq + 1).trimmed();

        // Only read unlocalized key names (Name=, Exec=, Icon=).
        // Localized variants such as Name[fr]= are intentionally skipped.
        if (key == QLatin1String("Name") && name.isEmpty())
            name = val;
        else if (key == QLatin1String("Exec") && exec.isEmpty())
            exec = val;
        else if (key == QLatin1String("Icon") && icon.isEmpty())
            icon = val;
    }

    // Strip .desktop field codes from the Exec value.
    // The freedesktop.org Desktop Entry Specification defines these codes:
    //   %f/%F (file/files), %u/%U (URL/URLs), %d/%D (directory/directories),
    //   %n/%N (filename/filenames without path), %i (icon), %c (translated
    //   name), %k (desktop file path), %v (device entry), %m (deprecated).
    // We remove them all so the stored command can be run directly.
    static const QRegularExpression fieldCodes(
        QStringLiteral(" ?%[fFuUdDnNickvm]"));
    exec.remove(fieldCodes);
    exec = exec.trimmed();

    if (exec.isEmpty())
        return {};

    return {
        {QStringLiteral("command"), exec},
        {QStringLiteral("icon"),
         icon.isEmpty() ? QStringLiteral("application-x-executable") : icon},
        {QStringLiteral("label"), name.isEmpty() ? exec : name}
    };
}

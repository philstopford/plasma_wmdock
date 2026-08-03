// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QFileInfo>
#include <QString>
#include <QProcess>
#include <QUrl>

/**
 * @brief Simple QML-accessible process launcher.
 *
 * Provides a launch(command) invokable that starts the given command
 * string as a detached child process.  Used by the WMLauncher applet.
 * Uses QProcess::splitCommand() for correct handling of quoted arguments
 * and escaped spaces.
 */
class ProcessLauncher : public QObject
{
    Q_OBJECT

public:
    explicit ProcessLauncher(QObject *parent = nullptr) : QObject(parent) {}

    /**
     * @brief Launch a command string as a detached process.
     * @param command  Shell-style command with optional quoted arguments.
     * @return true if the process started successfully.
     */
    Q_INVOKABLE bool launch(const QString &command)
    {
        if (command.trimmed().isEmpty()) return false;
        const QStringList parts = QProcess::splitCommand(command);
        if (parts.isEmpty()) return false;

        // Migrate launchers created by older drawer versions, which stored a
        // dropped executable as `xdg-open file:///...`. KIO intentionally
        // refuses that operation; execute a local executable directly instead.
        if (parts.size() == 2 && parts.constFirst() == QLatin1String("xdg-open")) {
            const QUrl url(parts.at(1));
            if (url.isLocalFile()) {
                const QString path = url.toLocalFile();
                const QFileInfo info(path);
                if (info.isFile() && info.isExecutable())
                    return QProcess::startDetached(path, {});
            }
        }
        return QProcess::startDetached(parts.value(0), parts.mid(1));
    }
};

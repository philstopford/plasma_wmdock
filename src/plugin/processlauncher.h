// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QString>
#include <QProcess>

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
        return QProcess::startDetached(parts.value(0), parts.mid(1));
    }
};

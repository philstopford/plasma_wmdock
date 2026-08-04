// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors
#pragma once

#include <QObject>
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QString>
#include <QProcess>
#include <QProcessEnvironment>
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
        return launch(command, QString());
    }

    /**
     * @brief Launch with an optional hybrid-graphics preference.
     * @param gpuPreference "discrete", "integrated", or empty/"default".
     */
    Q_INVOKABLE bool launch(const QString &command, const QString &gpuPreference)
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
                    return startDetached(path, {}, gpuPreference);
            }
        }
        const QString program = parts.value(0);
        const QStringList arguments = parts.mid(1);
        if (startDetached(program, arguments, gpuPreference))
            return true;

        // Some third-party application bundles install executable shell text
        // without a #! line (Blender's /opt wrapper is one example). Interactive
        // shells retry these through /bin/sh after ENOEXEC; QProcess correctly
        // does not. Match the convenient shell behavior for a local executable
        // while keeping ordinary commands free of shell interpretation.
        const QFileInfo programInfo(program);
        if (programInfo.isFile() && programInfo.isExecutable()) {
            QFile file(program);
            if (file.open(QIODevice::ReadOnly)) {
                const QByteArray prefix = file.read(4);
                const bool hasShebang = prefix.startsWith("#!");
                const bool isElf = prefix == QByteArrayLiteral("\x7f" "ELF");
                if (!hasShebang && !isElf) {
                    QStringList shellArguments{program};
                    shellArguments.append(arguments);
                    if (startDetached(QStringLiteral("/bin/sh"), shellArguments,
                                      gpuPreference))
                        return true;
                }
            }
        }

        qWarning() << "WMDock: failed to launch" << program;
        return false;
    }

private:
    static bool startDetached(const QString &program, const QStringList &arguments,
                              const QString &gpuPreference)
    {
        QProcess process;
        QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
        if (gpuPreference == QLatin1String("discrete")) {
            // NVIDIA PRIME Render Offload variables cover OpenGL/GLX and
            // Vulkan. DRI_PRIME also supports Mesa-based hybrid systems.
            environment.insert(QStringLiteral("__NV_PRIME_RENDER_OFFLOAD"),
                               QStringLiteral("1"));
            environment.insert(QStringLiteral("__GLX_VENDOR_LIBRARY_NAME"),
                               QStringLiteral("nvidia"));
            environment.insert(QStringLiteral("__VK_LAYER_NV_optimus"),
                               QStringLiteral("NVIDIA_only"));
            environment.insert(QStringLiteral("DRI_PRIME"), QStringLiteral("1"));
        } else if (gpuPreference == QLatin1String("integrated")) {
            environment.insert(QStringLiteral("DRI_PRIME"), QStringLiteral("0"));
            environment.remove(QStringLiteral("__NV_PRIME_RENDER_OFFLOAD"));
            environment.remove(QStringLiteral("__GLX_VENDOR_LIBRARY_NAME"));
            environment.remove(QStringLiteral("__VK_LAYER_NV_optimus"));
        }
        process.setProcessEnvironment(environment);
        process.setProgram(program);
        process.setArguments(arguments);
        return process.startDetached();
    }
};

// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "wmdockplugin.h"
#include "systemmonitor.h"
#include "networkmonitor.h"
#include "batterymonitor.h"
#include "audiomanager.h"
#include "weatherprovider.h"
#include "processlauncher.h"
#ifdef WITH_XEMBED
#include "xembedhost.h"
#endif

#include <QQmlEngine>
#include <qqml.h>

void WMDockPlugin::registerTypes(const char *uri)
{
    Q_ASSERT(QLatin1String(uri) == QLatin1String("org.kde.plasma.private.wmdock"));

    qmlRegisterSingletonType<SystemMonitor>(uri, 1, 0, "SystemMonitor",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new SystemMonitor();
        });

    qmlRegisterSingletonType<NetworkMonitor>(uri, 1, 0, "NetworkMonitor",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new NetworkMonitor();
        });

    qmlRegisterSingletonType<BatteryMonitor>(uri, 1, 0, "BatteryMonitor",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new BatteryMonitor();
        });

    qmlRegisterSingletonType<AudioManager>(uri, 1, 0, "AudioManager",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new AudioManager();
        });

    qmlRegisterType<WeatherProvider>(uri, 1, 0, "WeatherProvider");

    qmlRegisterSingletonType<ProcessLauncher>(uri, 1, 0, "ProcessLauncher",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new ProcessLauncher();
        });

#ifdef WITH_XEMBED
    qmlRegisterType<XEmbedHost>(uri, 1, 0, "XEmbedHost");
#endif

    qmlRegisterModule(uri, 1, 0);
}

void WMDockPlugin::initializeEngine(QQmlEngine * /*engine*/, const char * /*uri*/)
{
}

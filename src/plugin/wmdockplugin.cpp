// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2024 Plasma WM Dock Contributors

#include "wmdockplugin.h"
#include "systemmonitor.h"
#include "networkmonitor.h"
#include "batterymonitor.h"
#include "audiomanager.h"
#include "audiospectrummonitor.h"
#include "weatherprovider.h"
#include "desktopfilereader.h"
#include "drawerfileio.h"
#include "processlauncher.h"
#include "thermalmonitor.h"
#include "storagemonitor.h"
#include "gpumonitor.h"
#include "cursortracker.h"
#include "mediascanner.h"
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

    qmlRegisterSingletonType<AudioSpectrumMonitor>(uri, 1, 0, "AudioSpectrum",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new AudioSpectrumMonitor();
        });

    qmlRegisterType<WeatherProvider>(uri, 1, 0, "WeatherProvider");

    qmlRegisterSingletonType<ProcessLauncher>(uri, 1, 0, "ProcessLauncher",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new ProcessLauncher();
        });

    qmlRegisterSingletonType<DesktopFileReader>(uri, 1, 0, "DesktopFileReader",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new DesktopFileReader();
        });

    qmlRegisterSingletonType<DrawerFileIO>(uri, 1, 0, "DrawerFileIO",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new DrawerFileIO();
        });

    qmlRegisterSingletonType<ThermalMonitor>(uri, 1, 0, "ThermalMonitor",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new ThermalMonitor();
        });

    qmlRegisterSingletonType<StorageMonitor>(uri, 1, 0, "StorageMonitor",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new StorageMonitor();
        });

    qmlRegisterSingletonType<GpuMonitor>(uri, 1, 0, "GpuMonitor",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new GpuMonitor();
        });

    qmlRegisterSingletonType<CursorTracker>(uri, 1, 0, "CursorTracker",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new CursorTracker();
        });

    qmlRegisterSingletonType<MediaScanner>(uri, 1, 0, "MediaScanner",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new MediaScanner();
        });

#ifdef WITH_XEMBED
    qmlRegisterType<XEmbedHost>(uri, 1, 0, "XEmbedHost");
#endif

    qmlRegisterModule(uri, 1, 0);
}

void WMDockPlugin::initializeEngine(QQmlEngine * /*engine*/, const char * /*uri*/)
{
}

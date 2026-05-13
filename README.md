# Plasma WM Dock

A complete WindowMaker-style dock for **KDE Plasma 6.5+**, faithfully replicating
the classic WindowMaker dock experience with full integration into the modern KDE
Plasma desktop.

## Features

- Classic WindowMaker 64 × 64 dock slot appearance and behaviour
- **Ten built-in applets**, each styled to match the original dockapp aesthetic:

  | Applet | ID | Description |
  |--------|----|-------------|
  | WMClock | `org.kde.plasma.wmclock` | Analog + digital clock |
  | WMCPUMon | `org.kde.plasma.wmcpu` | Per-core CPU usage scrolling graph |
  | WMMemMon | `org.kde.plasma.wmmem` | RAM / Swap usage bars |
  | WMBattery | `org.kde.plasma.wmbattery` | Battery level + charging status |
  | WMNet | `org.kde.plasma.wmnet` | Network in/out traffic graph |
  | WMMixer | `org.kde.plasma.wmmixer` | Audio volume control |
  | WMLoad | `org.kde.plasma.wmload` | 1 / 5 / 15-min load-average bars |
  | WMCalendar | `org.kde.plasma.wmcal` | Date / calendar display |
  | WMLauncher | `org.kde.plasma.wmlauncher` | Configurable application launcher |
  | WMWeather | `org.kde.plasma.wmweather` | Current weather conditions |

- **Legacy dockapp XEmbed** support (X11 sessions only) – host any unmodified
  WindowMaker dockapp binary inside a dock slot
- Horizontal **and** vertical panel orientation
- Drag-and-drop slot reordering
- Per-slot right-click context menus
- Per-applet configuration pages

## Requirements

| Component | Version |
|-----------|---------|
| CMake | ≥ 3.22 |
| Qt | ≥ 6.5 |
| KDE Frameworks | ≥ 6.0 |
| KDE Plasma | ≥ 6.0 (6.5 recommended) |
| ECM | ≥ 6.0 |
| X11 / XCB | Optional – legacy dockapp support |

## Building

```bash
mkdir build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
sudo make install
kbuildsycoca6 --noincremental
```

To disable legacy dockapp XEmbed support:

```bash
cmake .. -DWITH_XEMBED=OFF
```

## Installation and Usage

After installation, add the dock to any Plasma panel:

1. Right-click the panel → **Add Widgets…**
2. Search for **"WM Dock"**
3. Drag the widget onto the panel

Or drag it to the desktop as a free-floating widget.

### Adding / Removing Applets

Right-click the dock → **Configure WM Dock…** → **Applets** tab.
Select which applets fill each slot and their order.

### Legacy Dockapp Support (X11 only)

On an X11 Plasma session, additional slots of type *External Dockapp* can be
configured with the command used to launch the dockapp binary.  The dockapp
window is then XEMBED-ed into the slot automatically.

## Architecture

```
plasma-wmdock/
├── CMakeLists.txt
├── src/
│   ├── CMakeLists.txt
│   ├── plugin/               # C++ QML extension plugin
│   │   ├── systemmonitor     # /proc-based CPU, memory, load
│   │   ├── networkmonitor    # /proc/net/dev traffic counters
│   │   ├── batterymonitor    # UPower D-Bus battery info
│   │   ├── audiomanager      # PulseAudio/PipeWire D-Bus volume
│   │   ├── weatherprovider   # Open-Meteo HTTP weather data
│   │   └── xembedhost        # XCB XEMBED host (optional)
│   └── applets/
│       ├── wmdock/           # Main dock container plasmoid
│       ├── wmclock/
│       ├── wmcpu/
│       ├── wmmem/
│       ├── wmbattery/
│       ├── wmnet/
│       ├── wmmixer/
│       ├── wmload/
│       ├── wmcal/
│       ├── wmlauncher/
│       └── wmweather/
```

## License

GPL-2.0-or-later – see [LICENSES/GPL-2.0-or-later.txt](LICENSES/GPL-2.0-or-later.txt)

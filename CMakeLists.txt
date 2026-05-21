cmake_minimum_required(VERSION 3.22)

project(plasma-wmdock
    VERSION 1.0.0
    DESCRIPTION "WindowMaker-style dock applet for KDE Plasma 6"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(QT_MIN_VERSION "6.5.0")
set(KF_MIN_VERSION "6.0.0")
set(PLASMA_MIN_VERSION "6.0.0")

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_MODULE_PATH})

include(KDEInstallDirs6)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMInstallIcons)
include(ECMSetupVersion)
include(FeatureSummary)
include(KDEClangFormat)

ecm_setup_version(${PROJECT_VERSION}
    VARIABLE_PREFIX PLASMA_WMDOCK
    VERSION_HEADER "${CMAKE_CURRENT_BINARY_DIR}/plasma_wmdock_version.h"
)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Quick
    DBus
    Network
)

# Optional: Qt Multimedia is used by the WMPlay applet at QML runtime.
# If not present the applet will display an import error but all other
# applets continue to work normally.
find_package(Qt6 OPTIONAL_COMPONENTS Multimedia)

find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS
    I18n
    Config
    CoreAddons
    DBusAddons
    Notifications
    WindowSystem
)

find_package(Plasma ${PLASMA_MIN_VERSION} REQUIRED)

# Optional X11 support for legacy dockapp XEmbed embedding
find_package(X11)
find_package(Qt6 COMPONENTS GuiPrivate)

if(X11_FOUND AND Qt6GuiPrivate_FOUND)
    set(HAVE_X11 TRUE)
else()
    set(HAVE_X11 FALSE)
endif()

option(WITH_XEMBED
    "Enable XEmbed support for legacy WindowMaker dockapps (requires X11)"
    ${HAVE_X11}
)

if(WITH_XEMBED)
    if(NOT HAVE_X11)
        message(FATAL_ERROR "WITH_XEMBED=ON but X11 or Qt6GuiPrivate not found")
    endif()
    find_package(XCB REQUIRED COMPONENTS XCB)
    message(STATUS "XEmbed (legacy dockapp) support: ENABLED")
else()
    message(STATUS "XEmbed (legacy dockapp) support: DISABLED")
endif()

add_subdirectory(src)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)

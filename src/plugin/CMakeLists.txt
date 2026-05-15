set(PLUGIN_SOURCES
    wmdockplugin.cpp
    processlauncher.cpp
    systemmonitor.cpp
    networkmonitor.cpp
    batterymonitor.cpp
    audiomanager.cpp
    weatherprovider.cpp
)

if(WITH_XEMBED)
    list(APPEND PLUGIN_SOURCES xembedhost.cpp)
endif()

add_library(wmdockplugin SHARED ${PLUGIN_SOURCES})

target_link_libraries(wmdockplugin
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::DBus
    Qt6::Network
    KF6::CoreAddons
    KF6::I18n
)

if(WITH_XEMBED)
    target_link_libraries(wmdockplugin
        Qt6::GuiPrivate
        XCB::XCB
    )
    target_compile_definitions(wmdockplugin PRIVATE WITH_XEMBED=1)
endif()

target_compile_definitions(wmdockplugin PRIVATE
    TRANSLATION_DOMAIN="plasma_wmdock"
)

install(TARGETS wmdockplugin
    DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/private/wmdock
)

install(FILES qmldir
    DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/private/wmdock
)

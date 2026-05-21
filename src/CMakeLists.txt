add_subdirectory(plugin)

set(WMDOCK_APPLETS
    wmdock
    wmclock
    wmcpu
    wmmem
    wmbattery
    wmnet
    wmmixer
    wmload
    wmcal
    wmlauncher
    wmweather
    wmdrawer
    wmviz
    wmplay
    wmeyes
    wmlava
    wmsensors
    wmstorage
)

foreach(APPLET ${WMDOCK_APPLETS})
    add_subdirectory(applets/${APPLET})
endforeach()

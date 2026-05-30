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
    wmmatrix
    wmplasmaball
    wmplay
    wmeyes
    wmlava
    wmsensors
    wmstorage
    wmgpu
)

foreach(APPLET ${WMDOCK_APPLETS})
    add_subdirectory(applets/${APPLET})
endforeach()

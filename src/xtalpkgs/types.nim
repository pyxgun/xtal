import bitops

# for flags
proc `|`*(x, y: cint): cint = x.bitor(y)

type
    SysProcIDMap* = object
        containerID*: int
        hostID*     : int
        size*       : int

    SysProcAttr* = object
        cloneflags* : cint
        uidMappings*: SysProcIDMap
        gidMappings*: SysProcIDMap
    
    ContainerDirs* = object
        basedir*        : string
        containerdir*   : string
        layerdir*       : string
        imagedir*       : string
        iddir*          : string
        blobsdir*       : string
        upperdir*       : string
        lowerdir*       : string
        workdir*        : string
        overlay*        : string
        
    ContainerEnv* = object
        hostname*   : string
        command*    : cstringArray
        ipaddr*     : string
            
    ContainerConf* = object
        dirs*       : ContainerDirs
        sysProcAttr*: SysProcAttr
        env*        : ContainerEnv

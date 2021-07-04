import 
    os, strutils, json

import
    types, libc

from linuxutil import execCommand

type XtalSettings* = object
    baseDir*        : string
    containerDir*   : string
    layerDir*       : string
    imageDir*       : string
    blobsDir*       : string

proc initDir(): XtalSettings =
    let 
        basedir = getHomeDir() / ".local/share/xtal"
        containerDir = basedir & "/containers"
        layerDir = basedir & "/layers"
        imageDir = basedir & "/images"
        blobsDir = basedir & "/blobs"
    result = XtalSettings(
        baseDir     : basedir,
        containerDir: containerDir,
        layerDir    : layerDir,
        imageDir    : imageDir,
        blobsDir    : blobsDir
    )

proc checkDir(setting: XtalSettings) =
    # xtal base directory
    if not dirExists(setting.baseDir):
        createDir(setting.baseDir)
    # xtal containers directory
    if not dirExists(setting.containerDir):
        createDir(setting.containerDir)
    # xtal layers directory
    if not dirExists(setting.layerDir):
        createDir(setting.layerDir)
    # xtal images directory
    if not dirExists(setting.imageDir):
        createDir(setting.imageDir)
    # xtal blobs directory
    if not dirExists(setting.blobsDir):
        createDir(setting.blobsDir)
    # xtal images list
    let imageList = setting.imageDir & "/images.json"
    if not fileExists(imageList):
        block:
            let fd: File = open(imageList, FileMode.fmWrite)
            fd.write("""{"images":[]}""")
            fd.close
    # xtal ip lease list
    let ipLease = setting.containerDir & "/lease.json"
    if not fileExists(ipLease):
        block:
            let fd: File = open(ipLease, FileMode.fmWrite)
            fd.write("""{"ip_lease":[]}""")
            fd.close
    # TODO: get host network interface name
    # xtal config file
    let configFile = setting.baseDir & "/xtalconf.json"
    if not fileExists(configFile):
        block:
            let 
                fd: File = open(configFile, FileMode.fmWrite)
                confJson = %* {
                    "network": {
                        "ip_nwaddr": "10.157.0.0/24",
                        "ip_hostaddr": "10.157.0.1/24",
                        "ip_vethaddr": "10.157.0.10/24",
                        "host_nwif": "enp7s0"
                    }
                }
            fd.write(confJson)
            fd.close

# bridge
proc initXtalBridge(setting: XtalSettings) =
    let
        config = parseFile(setting.baseDir & "/xtalconf.json")
        braddr = config["network"]["ip_hostaddr"].getStr
    execCommand("ip link add xtalbr type bridge")
    execCommand("ip address add " & braddr & " dev xtalbr")
    execCommand("ip link set up xtalbr")

# ip nat masquerade
proc initNat(setting: XtalSettings) =
    let
        config = parseFile(setting.baseDir & "/xtalconf.json")
        ip_nwaddr = config["network"]["ip_nwaddr"].getStr
        host_nwif = config["network"]["host_nwif"].getStr
    execCommand("iptables -t nat -A POSTROUTING -s " & ip_nwaddr & " -j MASQUERADE", true)
    execCommand("iptables -A FORWARD -i " & host_nwif & " -o xtalbr -j ACCEPT", true)
    execCommand("iptables -A FORWARD -o " & host_nwif & " -i xtalbr -j ACCEPT", true)
    block:
        let fd: File = open("/proc/sys/net/ipv4/ip_forward", FileMode.fmWrite)
        fd.writeLine("1")
        fd.close

proc checkInitComplete(): bool =
    # create tmp file
    let tmpDir = "/tmp/xtal"
    if not dirExists(tmpDir):
        createDir(tmpDir)
    let initCheck = tmpDir & "/initflag"
    if not fileExists(initCheck):
        block:
            let fd: File = open(initCheck, FileMode.fmWrite)
            fd.writeLine("0")
            fd.close
    var flag: int
    # read nat flag
    block:
        let
            fd: File = open(initcheck, FileMode.fmRead)
        flag = parseInt(fd.readLine)
        fd.close
    if flag == 1: result = true
    else: result = false

proc completeInit() =
    let initFlag = "/tmp/xtal/initflag"
    block:
        let fd: File = open(initFlag, FileMode.fmWrite)
        fd.writeLine("1")
        fd.close


proc initXtal*(): XtalSettings =
    result = initDir()
    if not checkInitComplete():
        # init directory and return base direcotry
        checkDir(result)
        # init nat
        initNat(result)
        # bridge
        initXtalBridge(result)
        # set completed init flag
        completeInit()

proc initContainerConf*(xtalSettings: XtalSettings): ContainerConf =
    result.sysProcAttr = SysProcAttr(
        cloneflags: CLONE_NEWUSER |
                    CLONE_NEWUTS  |
                    CLONE_NEWIPC  |
                    CLONE_NEWPID  |
                    CLONE_NEWNET  |
                    CLONE_NEWNS,
        uidMappings:
            SysProcIDMap(
                    containerID : 0,
                    hostID      : getuid(),
                    size        : 65536
            ),
        gidMappings:
            SysProcIDMap(
                    containerID : 0,
                    hostID      : getgid(),
                    size        : 65536
            )
    )
    result.dirs = ContainerDirs(
        basedir     : xtalSettings.baseDir,
        containerdir: xtalSettings.containerDir,
        layerdir    : xtalSettings.layerDir,
        imagedir    : xtalSettings.imageDir,
        blobsdir    : xtalSettings.blobsDir
    )
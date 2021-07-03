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

proc initDir(): XtalSettings =
    # xtal base directory
    let basedir = getHomeDir() / ".local/share/xtal"
    if not dirExists(basedir):
        createDir(basedir)
    # xtal containers directory
    let containerDir = basedir & "/containers"
    if not dirExists(containerDir):
        createDir(containerDir)
    # xtal layers directory
    let layerDir = basedir & "/layers"
    if not dirExists(layerDir):
        createDir(layerDir)
    # xtal images directory
    let imageDir = basedir & "/images"
    if not dirExists(imageDir):
        createDir(imageDir)
    # xtal images list
    let imageList = imageDir & "/images.json"
    if not fileExists(imageList):
        let fd: File = open(imageList, FileMode.fmWrite)
        fd.write("""{"images":[]}""")
        fd.close()
    # xtal config file
    let configFile = baseDir & "/xtalconf.json"
    if not fileExists(configFile):
        let 
            fd: File = open(configFile, FileMode.fmWrite)
            confJson = %* {
                "network": {
                    "ip_nwaddr": "10.0.0.0/24",
                    "ip_hostaddr": "10.0.0.1/24",
                    "ip_vethaddr": "10.0.0.10/24",
                    "host_nwif": "enp7s0"
                }
            }
        fd.write(confJson)
        fd.close

    result = XtalSettings(
        baseDir     : basedir,
        containerDir: containerDir,
        layerDir    : layerDir,
        imageDir    : imageDir
    )

# bridge
proc initXtalBridge(baseDir: string) =
    let
        config = parseFile(baseDir & "/xtalconf.json")
        braddr = config["network"]["ip_hostaddr"].getStr
    execCommand("ip link add xtalbr0 type bridge")
    execCommand("ip address add " & braddr & " dev xtalbr0")
    execCommand("ip link set up xtalbr0")

# ip nat masquerade
proc initNat(baseDir: string) =
    # create tmp file
    let tmpDir = "/tmp/xtal"
    if not dirExists(tmpDir):
        createDir(tmpDir)
    let natCheck = tmpDir & "/nat_check"
    if not fileExists(natCheck):
        block:
            let fd: File = open(natCheck, FileMode.fmWrite)
            fd.writeLine("0")
            fd.close
    var flag: int
    # read nat flag
    block:
        let
            fd: File = open(natcheck, FileMode.fmRead)
        flag = parseInt(fd.readLine)
        fd.close
    if flag != 1:
        let
            config = parseFile(baseDir & "/xtalconf.json")
            ip_nwaddr = config["network"]["ip_nwaddr"].getStr
            host_nwif = config["network"]["host_nwif"].getStr
        execCommand("iptables -t nat -A POSTROUTING -s " & ip_nwaddr & " -j MASQUERADE", true)
        execCommand("iptables -A FORWARD -i " & host_nwif & " -o xtalbr0 -j ACCEPT", true)
        execCommand("iptables -A FORWARD -o " & host_nwif & " -i xtalbr0 -j ACCEPT", true)
        block:
            let fd: File = open("/proc/sys/net/ipv4/ip_forward", FileMode.fmWrite)
            fd.writeLine("1")
            fd.close
        # set nat flag
        block:
            let fd: File = open(natcheck, FileMode.fmWrite)
            fd.writeLine("1")
            fd.close
        initXtalBridge(baseDir)


proc initXtal*(): XtalSettings =
    # init directory and return base direcotry
    result = initDir()
    # init nat
    initNat(result.baseDir)

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
    )
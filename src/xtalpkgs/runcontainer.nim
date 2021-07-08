# run container

import
    oids, md5, os, json, strformat, strutils

import
    types, libc, linuxutil, image, nwmanage, error

# execContainer will be executed on new process
proc procOnContainer(container: ContainerConf) =
    # set hostname
    if sethostname(container.env.hostname, cast[cint](container.env.hostname.len)) != 0:
        execError("set hostname failed.")
    # mount filesystems
    mountFs(container.dirs)
    # pivot_root
    pivotRoot(container.dirs)
    # execute command in container
    if execv(container.env.command[0], container.env.command) != 0:
        execError("execute command failed.")

proc newProcess(container: ContainerConf): int =
    let stack = cast[pointer](cast[clong](malloc(65536)) + 65536)
    result = clone(procOnContainer, stack,
                    cast[cint](container.sysProcAttr.cloneflags) | SIGCHLD, container)

proc waitProc(pid: int) =
    var status: cint
    if pid.waitpid(status, 0) < 0:
        execError("wait process failed.")

proc writeFile(path, content: string) =
    block:
        let fd: File = open(path, FileMode.fmWrite)
        fd.writeLine(content)
        fd.close

proc initConfig(containerDir, containerId, containerIp, image, tag: string, cmd: seq[string], name: string) =
    let config = %* {
        "ContainerId": containerId,
        "Repository": image,
        "Tag": tag,
        "Status": "created",
        "Pid": 0,
        "Hostname": containerId,
        "Containername": name,
        "Ip": containerIp,
        "Cmd": cmd
    }
    writeFile(containerDir & "/config.json", $config)

proc stateUpdate(configPath: string, pid: int, status: string) =
    let conf = parseFile(configPath)
    let config = %* {
        "ContainerId": conf["ContainerId"].getStr,
        "Repository": conf["Repository"].getStr,
        "Tag": conf["Tag"].getStr,
        "Status": status,
        "Pid": pid,
        "Hostname": conf["Hostname"].getStr,
        "Containername": "",
        "Ip": conf["Ip"].getStr,
        "Cmd": conf["Cmd"]
    }
    writeFile(configPath, $config)

proc cmdSyntaxCheck*(cmdArray: var cstringArray) =
    let cmd: string = $cmdArray[0]
    if cmd.find("/usr/bin/") == -1 and cmd.find("/usr/sbin/") == -1 and cmd.find("/bin/") == -1:
        cmdArray[0] = fmt"/bin/{cmdArray[0]}"

proc containerExists(containerDir: string): bool =
    if dirExists(containerDir):
        return true
    else:
        return false

# execute container
proc execContainer(container: var ContainerConf) =
    let
        config   = parseFile(container.dirs.basedir & "/xtalconf.json")
        nwconf   = parseFile(container.dirs.iddir & "/config.json")
        hostaddr = config["network"]["ip_hostaddr"].getStr
        vethaddr = nwconf["Ip"].getStr
    # create child process
    let pid = container.newProcess
    if pid == -1:
        execError("start new process failed.")
    pid.writeUidGidMappings(container.sysProcAttr)
    pid.setupContainerNW(hostaddr, vethaddr, container.env.hostname)
    pid.setMemLimit
    pid.setCpuLimit
    # update status to running
    stateUpdate(fmt"{container.dirs.iddir}/config.json", pid, "running")
    # wait child process
    pid.waitProc
    # remove cgroups
    pid.claenCgroups

proc setLowerDir(container: var ContainerConf, image, tag: string) =
    let imageList = parseFile(container.dirs.imagedir & "/images.json")
    var layerDir: string = ""
    for item in imageList["images"].items:
        if item["repository"].getStr == image and item["tag"].getStr == tag:
            for layer in item["layers"].items:
                let tmp = fmt"{container.dirs.basedir}/layers/{layer.getStr}"
                addSep(layerDir, sep=":")
                add(layerDir, tmp)
    container.dirs.lowerdir = layerDir

# TODO: oci runtime specification, state operation
proc stateContainer*(container: ContainerConf, containerId: string) =
    let 
        containerDir = fmt"{container.dirs.containerdir}/{containerId}"
        config       = parseFile(fmt"{containerDir}/config.json")
    echo config.pretty

proc listContainer*(container: ContainerConf) =
    echo fmt"""{"CONTAINER ID":<15}{"IMAGE":<25}{"STATUS":<15}NAME"""
    for containerDir in walkDir(container.dirs.containerdir):
        for c in walkDir(containerDir.path):
            if c.kind == pcFile and c.path == containerDir.path & "/config.json":
                let 
                    conf = parseFile(c.path)
                    image = conf["Repository"].getStr & ":" & conf["Tag"].getStr
                echo fmt"""{conf["ContainerId"].getStr:<15}{image:<25}{conf["Status"].getStr:<15}{conf["Containername"].getStr}"""

# TODO: oci runtime specification, create operation
proc createContainer*(container: var ContainerConf, reporeq: string, name: string = ""): string =
    let
        containerId  = ($toMD5($genOid()))[0..11]
        containerDir = container.dirs.containerdir & "/" & containerId
    var 
        image, tag: string
        cmd: seq[string]
    reporeq.parseRepo(image, tag)

    container.setContainerNwIf(containerId)
    let containerIp  = container.env.ipaddr

    createDir(containerDir)
    if not imageExists(container, image, tag):
        container.getContainerImage(reporeq)
    cmd = container.getConfigCmd(image, tag)
    initConfig(containerDir, containerId, containerIp, image, tag, cmd, name)
    result = containerId

# TODO: oci runtime specification, start operation
proc startContainer*(container: var ContainerConf, containerId: string, mnt: string = "") =
    let containerDir = container.dirs.containerdir & "/" & containerId
    if not containerExists(containerDir):
        echo fmt"container {containerId} does not exist."
        quit(1)

    let
        config  = parseFile(containerDir & "/config.json")
        image   = config["Repository"].getStr
        tag     = config["Tag"].getStr
        overlay = containerDir & "/merged"
        upper   = containerDir & "/diff"
        work    = containerDir & "/work"
    if not dirExists(overlay): createDir(overlay)
    if not dirExists(upper)  : createDir(upper)
    if not dirExists(work)   : createDir(work)

    container.setLowerDir(image, tag)
    container.dirs.iddir    = containerDir
    container.dirs.overlay  = overlay
    container.dirs.upperdir = upper
    container.dirs.workdir  = work
    container.dirs.exmount = mnt

    container.env.hostname  = config["Hostname"].getStr
    var cmdarray: seq[string]
    for str in config["Cmd"]:
        cmdarray.add(str.getStr)
    container.env.command   = allocCStringArray(cmdarray)
    cmdSyntaxCheck(container.env.command)

    # execute container
    container.execContainer
    # update status to stop
    stateUpdate(containerDir & "/config.json", 0, "stop")

# TODO: oci runtime specification, kill operation
proc killContainer*() =
    discard

# TODO: check container state
proc checkContainerState(containerDir: string): string =
    let config = parseFile(containerDir & "/config.json")
    result = config["Status"].getStr

# TODO: oci runtime specification, delete operation
proc deleteContainer*(container: ContainerConf, containerId: string) =
    let containerDir = container.dirs.containerdir & "/" & containerId
    if not dirExists(containerDir):
        echo fmt"""container "{containerId}" does not exist"""
        quit(1)
    else:
        let state = checkContainerState(containerDir)
        if state == "running":
            echo fmt"""Cannot remove container "{containerId}". State: {state}"""
            quit(1)
        else:
            removeDir(containerDir)
            freeLeaseIp(container, containerId)

# wrapper
proc run*(container: var ContainerConf, reporeq: string) =
    let containerId = container.createContainer(reporeq)
    container.startContainer(containerId)
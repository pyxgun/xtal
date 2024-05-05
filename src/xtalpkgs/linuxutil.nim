import
    strformat, strutils, os

import
    types, libc, error


proc execCommand*(cmd: string, sbinflags: bool = false) =
    var status: cint
    let cmdarr = split(cmd, " ")
    let pid = fork()
    if pid < 0: execError("fork failed.")
    elif pid == 0:
        if sbinflags:
            if execv(cstring(fmt"/sbin/{cmdarr[0]}"), allocCStringArray(cmdarr)) != 0:
                execError(fmt"command: {cmdarr[0]} failed.")
        else:
            if execv(cstring(fmt"/bin/{cmdarr[0]}"), allocCStringArray(cmdarr)) != 0:
                execError(fmt"command: {cmdarr[0]} failed.")
    discard waitpid(pid, status, 0)

proc writeIDMapping(path: string, map: SysProcIDMap) =
    block:
        let fd: File = open(path, FileMode.fmWrite)
        fd.writeLine(fmt"{map.containerID} {map.hostID} {map.size}")
        fd.close

#[
proc writeSetgrups(pid: int) =
    block:
        let
            sgf = fmt"/proc/{pid}/setgroups"
            fd: File = open(sgf, FileMode.fmWrite)
        fd.writeLine("deny")
        fd.close
]#

proc writeUidGidMappings*(pid: int, sysProcAttr: SysProcAttr) =
    # set uid mapping
    let uidf = fmt"/proc/{pid}/uid_map"
    uidf.writeIDMapping(sysProcAttr.uidMappings)

    # set gid mapping
    #pid.writeSetgrups
    let gidf = fmt"/proc/{pid}/gid_map"
    gidf.writeIDMapping(sysProcAttr.gidMappings)

proc setMemLimit*(pid: int) =
    let memDir = cstring(fmt"/sys/fs/cgroup/memory/{pid}")
    if mkdir(memDir, 0o700) != 0:
        execError(fmt"create /sys/fs/cgroup/memory/{pid} failed.")
    # set memory limit
    block:
        let fd: File = open(fmt"{memDir}/memory.limit_in_bytes", FileMode.fmWrite)
        fd.writeLine("1024m")
        fd.close
    # add container to cgroup
    block:
        let fd: File = open(fmt"{memDir}/tasks", FileMode.fmWrite)
        fd.writeLine($pid)
        fd.close

proc setCpuLimit*(pid: int) =
    let cpuDir = cstring(fmt"/sys/fs/cgroup/cpu/{pid}")
    if mkdir(cpuDir, 0o700) != 0:
        execError(fmt"create /sys/fs/cgroup/cpu/{pid} failed.")
    # set cpu limit
    block:
        let fd: File = open(fmt"{cpuDir}/cpu.cfs_quota_us", FileMode.fmWrite)
        fd.writeLine(70000)
        fd.close
    # add container to cgroup
    block:
        let fd: File = open(fmt"{cpuDir}/tasks", FileMode.fmWrite)
        fd.writeLine($pid)
        fd.close

proc claenCgroups*(pid: int) =
    # remove memory cgroup
    if rmdir(cstring(fmt"/sys/fs/cgroup/memory/{pid}")) != 0:
        execError("remove memory failed.")
    # remove cpu cgroup
    if rmdir(cstring(fmt"/sys/fs/cgroup/cpu/{pid}")) != 0:
        execError("remove cpu failed.")

# setup veth
proc setupContainerNW*(pid: int, hostaddr, vethaddr: string, containerId: string) =
    let 
        hostIpOnly = split(hostaddr, "/")[0]
        ethId      = containerId[6 .. ^1]
    execCommand(fmt"ip link add name xtal{ethId} type veth peer name eth0 netns {pid}")
    execCommand(fmt"nsenter -t {pid} -n ip address add {vethaddr} dev eth0")
    execCommand(fmt"nsenter -t {pid} -n ip address add 127.0.0.1 dev lo")
    execCommand(fmt"ip link set dev xtal{ethId} master xtalbr")
    execCommand(fmt"nsenter -t {pid} -n ip link set up eth0")
    execCommand(fmt"ip link set up xtal{ethId}")
    execCommand(fmt"nsenter -t {pid} -n ip route add default via {hostIpOnly}")


#
proc parsePorrForwarding(portsopt: string): (string, string) =
    let
        port_info = portsopt.split(":")
        host_port = port_info[0]
        dstc_port = port_info[1]
    result = (host_port, dstc_port)

# port forwarding config
proc setPortForwarding*(container_ip: string, ports: string) =
    let
        port_info = parsePorrForwarding(ports)
        host_port = port_info[0]
        dstc_port = port_info[1]
    # port forwarding from host to container
    discard execShellCmd(fmt"iptables -t nat -A PREROUTING -p tcp --dport {host_port} -j DNAT --to-destination {container_ip}:{dstc_port}")
    discard execShellCmd(fmt"iptables -t nat -A OUTPUT -p tcp --dport {host_port} -j DNAT --to-destination {container_ip}:{dstc_port}")
    discard execShellCmd(fmt"iptables -t nat -A POSTROUTING -p tcp -d {container_ip} --dport {dstc_port} -j MASQUERADE")
    discard execShellCmd(fmt"iptables -A FORWARD -p tcp -d {container_ip} --dport {dstc_port} -j ACCEPT")
    discard execShellCmd(fmt"iptables -A FORWARD -p tcp -s {container_ip} --sport {dstc_port} -j ACCEPT")

# remove port forwarding config
proc deletePortForwarding*(container_ip: string, ports: string) =
    let
        port_info = parsePorrForwarding(ports)
        host_port = port_info[0]
        dstc_port = port_info[1]
    discard execShellCmd(fmt"iptables -t nat -D PREROUTING -p tcp --dport {host_port} -j DNAT --to-destination {container_ip}:{dstc_port}")
    discard execShellCmd(fmt"iptables -t nat -D OUTPUT -p tcp --dport {host_port} -j DNAT --to-destination {container_ip}:{dstc_port}")
    discard execShellCmd(fmt"iptables -t nat -D POSTROUTING -p tcp -d {container_ip} --dport {dstc_port} -j MASQUERADE")
    discard execShellCmd(fmt"iptables -D FORWARD -p tcp -d {container_ip} --dport {dstc_port} -j ACCEPT")
    discard execShellCmd(fmt"iptables -D FORWARD -p tcp -s {container_ip} --sport {dstc_port} -j ACCEPT")

# mount options parser
proc parseExMount(mntopt: string): (string, string) =
    let
        mntinfo  = mntopt.split(",")
        srcinfo  = mntinfo[0].split(":")
        dstinfo  = mntinfo[1].split(":")
    if srcinfo[0] == "src" and dstinfo[0] == "dst":
        var
            mntsrc  = srcinfo[1]
            mntdst  = dstinfo[1]
        result = (mntsrc, mntdst)
    else:
        execError("Invalid mount options")

proc mountFs*(dirs: ContainerDirs) =
    block:
        # overlay
        if mount("overlay", cstring(dirs.overlay), "overlay", 0,
                    cstring(fmt"lowerdir={dirs.lowerdir},upperdir={dirs.upperdir},workdir={dirs.workdir}")) != 0:
            execError("mount overlay failed.")
        # /proc, /sys, /dev/pts, /dev/shm should be made available in each container's filesystem
        # /proc
        if not dirExists(fmt"{dirs.overlay}/proc"):
            if mkdir(cstring(fmt"{dirs.overlay}/proc"), 0o755) != 0:
                execError("create /proc failed.")
        if mount("proc", cstring(fmt"{dirs.overlay}/proc"), "proc", MS_NOEXEC | MS_NODEV | MS_NOSUID, "") != 0:
            execError("mount proc failed.")
        # /sys
        if not dirExists(fmt"{dirs.overlay}/sys"):
            if mkdir(cstring(fmt"{dirs.overlay}/sys"), 0o755) != 0:
                execError("create /sys failed.")
        if mount("sysfs", cstring(fmt"{dirs.overlay}/sys"), "sysfs", MS_NOEXEC | MS_NODEV | MS_NOSUID | MS_RDONLY, "") != 0:
            execError("mount sysfs failed.")
        # /dev
        if not dirExists(fmt"{dirs.overlay}/dev"):
            if mkdir(cstring(fmt"{dirs.overlay}/dev"), 0o755) != 0:
                execError("create /dev failed.")
        if mount("tmpfs", cstring(fmt"{dirs.overlay}/dev"), "tmpfs", MS_NOSUID, "size=65536k,mode=755") != 0:
            execError("mount /dev failed.")
        # /dev/pts
        if not dirExists(fmt"{dirs.overlay}/dev/pts"):
            if mkdir(cstring(fmt"{dirs.overlay}/dev/pts"), 0o755) != 0:
                execError("create /dev/pts failed.")
        if mount("devpts", cstring(fmt"{dirs.overlay}/dev/pts"), "devpts", MS_NOEXEC | MS_NOSUID, "gid=5,mode=620,ptmxmode=666") != 0:
            execError("mount devpts failed.")
        # /dev/shm
        if not dirExists(fmt"{dirs.overlay}/dev/shm"):
            if mkdir(cstring(fmt"{dirs.overlay}/dev/shm"), 0o755) != 0:
                execError("create /dev/shm failed.")
        if mount("shm", cstring(fmt"{dirs.overlay}/dev/shm"), "tmpfs", MS_NOEXEC | MS_NODEV | MS_NOSUID, "size=65536k") != 0:
            execError("mount shm failed.")
        # resolv.conf
        if not fileExists(fmt"{dirs.overlay}/etc/resolv.conf"):
            let fd: File = open(fmt"{dirs.overlay}/etc/resolv.conf", FileMode.fmWrite)
            fd.close
        writeFile(fmt"{dirs.overlay}/etc/resolv.conf", "nameserver 8.8.8.8")
        # mount host directory
        if dirs.exmount != "":
            let
                mntinfo = parseExMount(dirs.exmount)
                mntsrc  = mntinfo[0]
                mntdst  = mntinfo[1]
            if mount(cstring(fmt"{mntsrc}"), cstring(fmt"{dirs.overlay}{mntdst}"), "", MS_BIND, "") != 0:
                execError("mount option failed.")

# wrapper for pivot_root
proc pivotRoot*(dirs: ContainerDirs) =
    if chdir(cstring(fmt"{dirs.iddir}")) != 0:
        execError("change directory failed.")
    if mount("merged", cstring(fmt"{dirs.overlay}"), "", MS_BIND | MS_REC, "") != 0:
        execError("mount merged failed.")
    if mkdir(cstring(fmt"{dirs.overlay}/put_old"), 0o700) != 0:
        execError("create put_old faield.")
    if syscall(SYS_pivot_root, "merged", cstring(fmt"{dirs.overlay}/put_old")) != 0:
        execError("pivot_root failed.")
    if chdir("/") != 0:
        execError("change / failed.")
    if umount2("/put_old", MNT_DETACH) != 0:
        execError("unmount put_old failed.")
    if rmdir("/put_old") != 0:
        execError("remove put_old failed.")
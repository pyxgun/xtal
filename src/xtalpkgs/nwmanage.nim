import
    json, strformat, strutils, sequtils

import types


proc addLeaseIp(container: ContainerConf, ip: int, containerId: string, leaseList: var JsonNode) =
    let leaseInfo = %* {
            "ip": ip,
            "containerId": containerId
        }
    leaseList["ip_lease"].add(leaseInfo)
    let fd: File = open(fmt"{container.dirs.containerdir}/lease.json", FileMode.fmWrite)
    fd.write(leaseList)
    fd.close

proc freeLeaseIp*(container: ContainerConf, containerId: string) =
    let config = parseFile(fmt"{container.dirs.containerdir}/lease.json")
    var leaseList: seq[JsonNode]
    for item in config["ip_lease"].items:
        if item["containerId"].getStr != containerId:
            leaseList.add(item)
    let 
        fd: File = open(fmt"{container.dirs.containerdir}/lease.json", FileMode.fmWrite)
        newLeaseList = %* {
            "ip_lease": leaseList
        }
    fd.write(newLeaseList)
    fd.close

proc setContainerNwIf*(container: var ContainerConf, containerId: string) =
    let 
        ipaddr = 10
        config = parseFile(fmt"{container.dirs.basedir}/xtalconf.json")
        nwaddr = split(config["network"]["ip_nwaddr"].getStr, ".")
    var leaseList = parseFile(fmt"{container.dirs.containerdir}/lease.json")
    if leaseList["ip_lease"].len == 0:
        container.env.ipaddr = fmt"{nwaddr[0]}.{nwaddr[1]}.{nwaddr[2]}.{ipaddr}/24"
        container.addLeaseIp(ipaddr, containerId, leaseList)
    else:
        var ips: seq[int]
        for info in leaseList["ip_lease"].items:
            ips.add(info["ip"].getInt)
        let newip = ips[maxIndex(ips)] + 1
        container.env.ipaddr = fmt"{nwaddr[0]}.{nwaddr[1]}.{nwaddr[2]}.{newip}/24"
        container.addLeaseIp(newip, containerId, leaseList)
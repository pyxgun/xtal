# xtal container runtime

import
    xtalpkgs/[initxtal, runcontainer, image, help], os

let xtalSettings = initXtal()
var container    = xtalSettings.initContainerConf

if paramCount() == 0:
    help()
    quit(1)
else:
    case commandLineParams()[0]:
    of "run":
        if paramCount() == 1: callHelp(runHelp)
        container.run(commandLineParams()[1])
    of "create":
        if paramCount() == 1: callHelp(createHelp)
        discard container.createContainer(commandLineParams()[1])
    of "start":
        if paramCount() == 1: callHelp(startHelp)
        container.startContainer(commandLineParams()[1])
    of "rm":
        if paramCount() == 1: callHelp(rmHelp)
        container.deleteContainer(commandLineParams()[1])
    of "ls":
        container.listContainer
    of "pull":
        if paramCount() == 1: callHelp(pullHelp)
        container.getContainerImage(commandLineParams()[1])
    of "images":
        container.listImages
    of "rmi":
        if paramCount() == 1: callHelp(rmiHelp)
        container.removeImage(commandLineParams()[1])
    of "state":
        container.stateContainer(commandLineParams()[1])
    else:
        echo "command not found."
        help()
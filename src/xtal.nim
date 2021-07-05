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
        if paramCount() == 1:
            runHelp()
            quit(1)
        container.run(commandLineParams()[1])
    of "create":
        if paramCount() == 1:
            createHelp()
            quit(1)
        discard container.createContainer(commandLineParams()[1])
    of "start":
        if paramCount() == 1:
            startHelp()
            quit(1)
        container.startContainer(commandLineParams()[1])
    of "rm":
        container.deleteContainer(commandLineParams()[1])
    of "ls":
        container.listContainer
    of "pull":
        container.getContainerImage(commandLineParams()[1])
    of "images":
        container.listImages
    of "rmi":
        container.removeImage(commandLineParams()[1])
    else:
        echo "command not found."
        help()
import parseopt

import
    runcontainer, image, types, help

const
    RUN     = 0
    CREATE  = 1
    START   = 2
    PULL    = 3
    RM      = 4
    RMI     = 5
    LS      = 6
    IMAGES  = 7
    STATUS  = 8

proc checkSunbcommand(subcmd: string): int =
    case subcmd
    of "run"    : result = RUN
    of "create" : result = CREATE
    of "start"  : result = START
    of "pull"   : result = PULL
    of "rm"     : result = RM
    of "rmi"    : result = RMI
    of "ls"     : result = LS
    of "images" : result = IMAGES
    of "status" : result = STATUS
    else        : result = -1

proc checkRequiredParam(cmd: seq[string]): bool =
    case checkSunbcommand(cmd[0])
    of RUN:
        if cmd.len == 2 : return true
        else            : return false
    of CREATE:
        if cmd.len == 2 : return true
        else            : return false
    of START:
        if cmd.len == 2 : return true
        else            : return false
    of PULL:
        if cmd.len == 2 : return true
        else            : return false
    of RM:
        if cmd.len == 2 : return true
        else            : return false
    of RMI:
        if cmd.len == 2 : return true
        else            : return false
    of STATUS:
        if cmd.len == 2 : return true
        else            : return false
    else:
        return true

proc checkCommandOpt(subcmd: int, key, value: string): bool =
    case subcmd
    of RUN:
        case key
        of "n", "name":
            if value != ""  : return true
            else            : return false
        of "mount":
            if value != ""  : return true
            else            : return false
        of "r", "rm":
            return true
        of "p", "portforward":
            if value != ""  : return true
            else            : return false
        else: return false
    of CREATE:
        case key
        of "n", "name":
            if value != ""  : return true
            else            : return false
    of START:
        case key
        of "mount":
            if value != ""  : return true
            else            : return false
        of "p", "portforward":
            if value != ""  : return true
            else            : return false
    else:
        return false

proc commandParse*(): (seq[string], seq[tuple[key: string, value: string]]) =
    var
        cmd: seq[string]
        opt: seq[tuple[key: string, value: string]]
        subcmd: int
        count = 0
    for kind, key, val in getopt():
        case kind
        of cmdArgument:
            if count == 0:
                subcmd =checkSunbcommand(key)
                if subcmd == -1:
                    echo "Invalid command."
                    quit(1)
                count = 1
            cmd.add(key)
        of cmdShortOption, cmdLongOption:
            if not subcmd.checkCommandOpt(key, val):
                echo "Invalid command option."
                quit(1)
            opt.add((key: key, value: val))
        of cmdEnd:
            discard
    result = (cmd, opt)

proc execXtal*(container: var ContainerConf, cmd: seq[string], opt: seq[tuple[key: string, value: string]]) =
    if cmd.len == 0:
        help()
        quit(1)
    if not checkRequiredParam(cmd):
        echo "Too few args."
        quit(1)
    case checkSunbcommand(cmd[0])
    of RUN:
        container.run(cmd[1], opt)
    of CREATE:
        if opt.len == 1:
            discard container.createContainer(cmd[1], opt[0][1])
        else:
            discard container.createContainer(cmd[1])
    of START:
        container.start(cmd[1], opt)
    of PULL:
        container.getContainerImage(cmd[1])
    of RM:
        container.deleteContainer(cmd[1])
    of RMI:
        container.removeImage(cmd[1])
    of LS:
        container.listContainer
    of IMAGES:
        container.listImages
    of STATUS:
        container.stateContainer(cmd[1])
    else:
        discard
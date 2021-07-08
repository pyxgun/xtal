# xtal container runtime

import
    xtalpkgs/[initxtal, cmdparse]

let xtalSettings = initXtal()
var container    = xtalSettings.initContainerConf

let args = commandParse()
container.execXtal(args[0], args[1])
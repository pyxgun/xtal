proc execError*(msg: string) =
    stdout.writeLine(msg)
    quit(1)
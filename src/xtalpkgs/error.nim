type Error = object of ref Exception

proc execError*(msg: string) =
    raise newException(Error, msg)
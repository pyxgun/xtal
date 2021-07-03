# import from glibc

type
    Mode {.importc: "mode_t", header: "sys/types.h".} = uint32
    Pid  {.importc: "pid_t", header: "sys/types.h".}  = int

# system calls
proc clone*(fn: pointer, childStack: pointer, flags: cint, container: auto,): cint {.importc, header: "sched.h".}
proc system*(command: cstring): cint {.importc, header: "stdlib.h".}
proc syscall*(number: cint, new_fs, old_fs: cstring): cint {.importc, header: "unistd.h".}
proc sethostname*(name: cstring, namelen: cint): cint {.importc, header: "unistd.h".}
proc chdir*(path: cstring): cint {.importc, header: "unistd.h".}
proc rmdir*(path: cstring): cint {.importc, header: "unistd.h".}
proc execv*(pathname: cstring, argv: cstringArray): cint {.importc, header: "unistd.h".}
proc fork*(): cint {.importc, header: "unistd.h".}
proc getpid*(): cint {.importc, header: "unistd.h".}
proc getgid*(): cint {.importc, header: "unistd.h".}
proc getuid*(): cint {.importc, header: "unistd.h".}
proc mkdir*(path: cstring, mode: Mode): cint {.importc, header: "sys/stat.h".}
proc waitpid*(pid: Pid, wstaus: cint, options: cint): cint {.importc, header: "wait.h".}
proc mount*(source, target, filesystem: cstring, mountflags: cint, data: cstring): cint {.importc, header: "sys/mount.h".}
proc umount2*(target: cstring, flags: cint): cint {.importc, header: "sys/mount.h".}
proc malloc*(size: cint): pointer {.importc, header: "stdlib.h".}
proc open*(pathname: cstring, flags: cint, mode: Mode): cint {.importc, header: "fcntl.h".}

# defines
let
    SYS_pivot_root* {.importc, header: "sys/syscall.h".}: cint
    CLONE_NEWIPC* {.importc, header: "sys/syscall.h".}: cint
    CLONE_NEWNET* {.importc, header: "sched.h".}: cint
    CLONE_NEWUSER* {.importc, header: "sched.h".}: cint
    CLONE_NEWUTS* {.importc, header: "sched.h".}: cint
    CLONE_NEWNS* {.importc, header: "sched.h".}: cint
    CLONE_NEWPID* {.importc, header: "sched.h".}: cint
    SIGCHLD* {.importc, header: "wait.h".}: cint
    MS_NOEXEC* {.importc, header: "sys/mount.h".}: cint
    MS_NOSUID* {.importc, header: "sys/mount.h".}: cint
    MS_NODEV* {.importc, header: "sys/mount.h".}: cint
    MS_RDONLY* {.importc, header: "sys/mount.h".}: cint
    MS_BIND* {.importc, header: "sys/mount.h".}: cint
    MS_REC* {.importc, header: "sys/mount.h".}: cint
    MNT_DETACH* {.importc, header: "sys/mount.h".}: cint
    O_CREAT* {.importc, header: "fcntl.h".}: cint

var
    errno* {.importc, header: "errno.h".}: cint
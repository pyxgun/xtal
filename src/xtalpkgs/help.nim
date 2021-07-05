# help page

import strformat

let footer = """
For more information and bug reporting:
<https://github.com/pyxgun/xtal>"""

proc help*() =
    echo fmt"""
Usage: xtal [command] ...

Commands:
    run [repository<:tag>]
        : quick start. pull image, create and start container.

    create [repository<:tag>]
        : create container with specified repository.

    start [containerID]
        : start container that has already been creater.

    pull [repository<:tag>]
        : pull image from docker hub.
    
    rm [containerID]
        : remove container.

    rmi [imageID]
        : remove image.

    ls
        : show created containers.

    images
        : show local images.

{footer}"""

proc runHelp*() =
    echo fmt"""
Usage: xtal run [repository<:tag>]

Description:
    `run` command is wrapper command that contains whole process to start a container.
    If [repository<:tag>] image is not in local, it'll be downloaded.
    And then a container will be created and started using [repository<:tag>] image.
    <:tag> can be omitted. If you omit <:tag>, the latest version will be downloaded.

Example:
    $ xtal run archlinux:base-devel

{footer}"""

proc createHelp*() =
    echo fmt"""
Usage: xtal create [repository<:tag>]

Description:
    `create` command create a new container.
    A container to be created will have all the necessary information for running and 
    management, such as container ID, image information to be used, IP address, etc.
    This command must be executed befor starting a container.

Example:
    $ xtal create ubuntu

{footer}"""

proc startHelp*() =
    echo fmt"""
Usage: xtal start [containerID]

Description:
    `start` command launches specified container.
    The container to be launched is specified by [containerID].
    You can check container ID with `xtal ls` command.

Example:
    $ xtal start 60e2f6d07212

{footer}"""
# help page

proc help*() =
    echo """
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

For more information and bug reporting:
<https://github.com/pyxgun/xtal>
"""
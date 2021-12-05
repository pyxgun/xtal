# Xtal
## What Xtal is
Xtal /krístəl/ is a small container runtime written in Nim.

## Quick start
Xtal is server-less container runtime.  
All you need to do to create your container is to execute `xtal run` command.  

![xtal demo](https://raw.githubusercontent.com/wiki/pyxgun/xtal/xtal_introduce.gif)

## Features
- pivot root
- namespaces(IPC, Network, Mount, PID, User, UTS)
- bridge network
- memory & cpu limits
- pull image from Docker Hub
- management container & docker images

## Image that has been confirmed to work
- [x] Alpine
- [x] Ubuntu
- [x] CentOS
- [x] Arch Linux
- [x] Debian
- [x] Amazon Linux
- [x] Oracle Linux

...and more Linux image!

## Installation
```sh
$ git clone https://github.com/pyxgun/xtal.git
$ cd xtal
$ nimble build
```

## Tutorial
Let's try to run a container with a few command.
In this example, we will run Arch Linux container.
```sh
# pull image from docker hub
$ sudo xtal pull archlinux:latest

# create container with archlinux image
$ sudo xtal create archlinux:latest

# check containerID
$ sudo xtal ls
  CONTAINER ID   IMAGE                    STATUS
  60e16be57bb5   archlinux:latest         created

# start the container
# specify container ID you want to run
$ sudo xtal start 60e16be57bb5
```

## Commands
```sh
$ sudo xtal [command] <[arg]>

# command
  run    : quick start. pull image, create container, and start container.
  create : create container with specified image.
  start  : start container that has already been created.
  ls     : show created container list.
  rm     : remove container.
  pull   : pull image from docker hub.
  images : show downloaded images.
  rmi    : remove image.
```

## Options
### create
```
  -n, --name=[name]
          assign a name to the container.
          $ sudo xtal start create --name=mycontainer 60e16be57bb5
```

### start
```
  --mount=src:[src],dst:[dst]
          bind mount a directory on the local host to container.
          $ sudo xtal start --mount=src:$(pwd)/mydir,dst:/home 60e16be57bb5
  
  -p, --portforward=[host_port]:[container_port]
          $ sudo xtal start --portforward=8080:80 60e16be57bb5
```

## Note
Xtal is currently in the development stage.

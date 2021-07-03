# Xtal
## What Xtal is
Xtal /krístəl/ is a small container runtime written in Nim.

## Features
- pivot root
- namespaces(IPC, Network, Mount, PID, User, UTS)
- memory & cpu limits
- pull image from Docker Hub

## Installation
```
  git clone https://github.com/pyxgun/xtal.git
  cd xtal
  nimble build
```

## Steps to start your container
### Pull image
```
  sudo xtal pull [repository]<:[tag]>
```
`:[tag]` can be omitted.  
If `:[tag]` is omitted, `:latest` will be specified.

### Create container
```
  sudo xtal create [repository]<:[tag]>
```

### Show container list and check container ID
```
  sudo xtal ls
```

### Start container
```
  sudo xtal start [containerID]
```

## Quick start
```
  sudo xtal run [repository]<:[tag]>
```

## Delete container
```
  sudo xtal rm [containerID]
```

## Image management
### Check the local images
```
  sudo xtal images
```

### Remove image
```
  sudo xtal rmi [imageID]
```
If a container using the image exists, it cannot be removed.  
Please delete the container first, and then remove the image.

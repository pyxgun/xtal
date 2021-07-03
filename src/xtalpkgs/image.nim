import
    httpclient, asyncdispatch, json, strformat, strutils, os, osproc

import
    types

proc parseRepo*(pullreq: string, image, tag: var string) =
    let repo = pullreq.split(":")
    if repo.len == 1:
        image = repo[0]
        tag   = "latest"
    else:
        image = repo[0]
        tag   = repo[1]

proc imageExists*(container: ContainerConf, image, tag: string): bool =
    let imageList = parseFile(container.dirs.imagedir & "/images.json")
    for item in imageList["images"].items:
        if item["repository"].getStr == image and item["tag"].getStr == tag:
            return true
    result = false

proc listImages*(container: ContainerConf) =
    let imageList = parseFile(container.dirs.imagedir & "/images.json")
    echo fmt"""{"REPOSITORY":<25}{"TAG":<20}{"IMAGE ID"}"""
    for item in imageList["images"].items:
        echo fmt"""{item["repository"].getStr:<25}{item["tag"].getStr:<20}{item["digest"].getStr[0 .. 11]}"""

proc reqToken(image: string): string =
    let
        client = newHttpClient()
        url    = fmt"https://auth.docker.io/token?scope=repository:library/{image}:pull&service=registry.docker.io"
    client.headers = newHttpHeaders({ "Content-Type": "application/json" })

    let res = client.get(url)
    if res.status != "200 OK":
        stderr.writeLine("Request token failed.")
        quit(1)
    else:
        let token = $(res.body.parseJson)["token"]
        result = token[1 .. token.high - 1]

proc getManifest(token, image, tag: string): JsonNode =
    let
        client = newHttpClient()
        url    = fmt"https://registry-1.docker.io/v2/library/{image}/manifests/{tag}"
    client.headers = newHttpHeaders({ "Accept": "application/vnd.docker.distribution.manifest.v2+json",
                                    "Authorization": fmt"Bearer {token}" })
    let res = client.get(url)
    if res.status != "200 OK":
        stderr.writeLine("Get manifest failed.")
        quit(1)
    else:
        result = res.body.parseJson

proc getLayers(container: ContainerConf, token, image: string, manifest: JsonNode) {.async.} =
    let client = newAsyncHttpClient()
    client.headers = newHttpHeaders({ "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
                                      "Authorization": fmt"Bearer {token}" })

    for item in manifest["layers"].items:
        let
            imageId   = item["digest"].getStr
            url       = fmt"https://registry-1.docker.io/v2/library/{image}/blobs/{imageId}"
            id        = imageId[7 .. ^1]
            fname     = fmt"{id}.tar.gz"
            imagePath = fmt"{container.dirs.layerdir}/{fname}"
        if not fileExists(imagePath):
            stdout.write(fmt"{id[0 .. 11]}: ")
            stdout.flushFile
            await client.downloadFile(url, imagePath)
            echo "Pull complete"

proc extractLayer(container: ContainerConf, manifest: JsonNode) =
    stdout.write("Extracting layers: ")
    stdout.flushFile
    for item in manifest["layers"].items:
        let
            id = (item["digest"].getStr)[7 .. ^1]
            layerdir = fmt"{container.dirs.layerdir}/{id}"
        createDir(layerdir)
        setCurrentDir(container.dirs.layerdir)
        discard execProcess(fmt"tar -xvzf {id}.tar.gz -C {id}")
        removeFile(fmt"{id}.tar.gz")
    echo "Extract complete"

proc addImageList(container: ContainerConf, image, tag: string, manifest: JsonNode) =
    var imageList = parseFile(container.dirs.imagedir & "/images.json")
    var layers: seq[string]
    var digest = (manifest["config"]["digest"].getStr)[7 .. ^1]

    for item in manifest["layers"].items:
        let id = (item["digest"].getStr)[7 .. ^1]
        layers.add(id)
    
    let layersJsonArr = %* layers
    let imageObj = %* {
            "repository": image,
            "tag": tag,
            "digest": digest,
            "layers": layersJsonArr
        }
    imageList["images"].add(imageObj)
    let fd: File = open(container.dirs.imagedir & "/images.json", FileMode.fmWrite)
    fd.write(imageList)
    fd.close
    echo fmt"""Digest: {manifest["config"]["digest"].getStr}"""

proc checkWorkingContainer(container: ContainerConf, image, tag: string) =
    for containerDir in walkDir(container.dirs.containerdir):
        for c in walkDir(containerDir.path):
            if c.kind == pcFile and c.path == containerDir.path & "/config.json":
                let conf = parseFile(c.path)
                if conf["Repository"].getStr == image and conf["Tag"].getStr == tag:
                    echo fmt"""Remove image "{image}:{tag}" failed: container {conf["ContainerId"].getStr} is using this image."""
                    quit(1)

proc removeImage*(container: ContainerConf, imageId: string) =
    let imageList = parseFile(container.dirs.imagedir & "/images.json")
    var newImages: seq[JsonNode]

    for item in imageList["images"].items:
        if item["digest"].getStr[0 .. 11] == imageId:
            let
                image = item["repository"].getStr
                tag   = item["tag"].getStr
            checkWorkingContainer(container, image, tag)

            for layer in item["layers"].items:
                removeDir(fmt"""{container.dirs.layerdir}/{layer.getStr}""")
            continue
        else:
            newImages.add(item)
    
    let newImageList = %* {
            "images": newImages
        }
    let fd: File = open(container.dirs.imagedir & "/images.json", FileMode.fmWrite)
    fd.write(newImageList)
    fd.close

proc getContainerImage*(container: ContainerConf, reporeq: string) =
    var image, tag: string
    reporeq.parseRepo(image, tag)
    if container.imageExists(image, tag):
        echo fmt"{image}:{tag} aleady exists in local."
        return
    else:
        echo fmt"Pulling from docker.io/library/{image}:{tag}"
        let
            token = reqToken(image)
            manifest = getManifest(token, image, tag)
        waitFor container.getLayers(token, image, manifest)
        extractLayer(container, manifest)
        addImageList(container, image, tag, manifest)
        echo fmt"Downloaded newer image for {image}:{tag}"
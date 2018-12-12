## SiBoLo - Simple Bootloader

The name SiBoLo is an acronym for simple bootloader.
SiBoLo is a simple single staged bootloader for fat12 formatted floppys, which
loads a single file from by its name.

More information about the project is [available on my blog](https://blog.kalehmann.de/blog/2016/07/20/simple-boot-loader.html).

## Usage

### Building

First the binaries of the bootloader and its installer must be build. To do so
**gcc** and **nasm** have to be installed.

The build process is started with the include _Makefile_ by simply running
`make`

### Creating a floppy image

Creating a floppy image can be done using the _mkfs.fat_ utility. The image can
be mounted afterwards and the second stage copied onto it:

``` bash
mkfs.msdos -C -v floppy.flp 1440
LOOP=$(losetup -f)
losetup ${LOOP} floppy.flp
mkdir -p loop_mount
mount  /dev/loop0 loop_mount/
cp MYCOOLOS.BIN loop_mount/
sync
umount loop_mount
rm -Rf loop_mount
losetup -D
```

After that, the bootloader can be written on the image with the included
installer and configured to load *MYCOOLOS.BIN*

``` bash
./sibolo-install bootloader.bin floppy.flp MYCOOLOS.BIN
```

**Note** that the name of the file that the bootloader loads needs to comply with the 8.3 format. The length of the base name must not exceed 8 bytes and the length of the file extension must not exceed 3 bytes. All letters must be upper case.

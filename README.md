# SiBoLo - Simple Bootloader
This is a simple single staged bootloader for fat12 formatted floppys, which could be configured to load a single file from the floppy.
## How to build?
Make shure you have nasm and gcc installed, the simply run `$ make`
## How to use?
Create a floppy image, then mount it and copy your second stage on it. For example
```shell
# mkfs.msdos -C -v floppy.flp 1440
# losetup loop0 floppy.flp
# mkdir -p loop_mount
# mount -t vfat -o loop /dev/loop0 loop_mount/
# cp MYCOOLOS.BIN loop_mount/
# sync
# umount loop_mount
# rm -R -f loop_mount
# losetup -D
```
After that, write the bootloader on it and configure it to load *MYCOOLOS.BIN*
`$ ./install_sibolo bootloader.bin floppy.flp MYCOOLOS.BIN`

**Attention: because of the limits of the fat12 filesystem, the name of your second stage sould not exceed 8 bytes and the file name extension should not exceed 3 bytes.**

## SiBoLo - Simple Bootloader

The name SiBoLo is an acronym for simple bootloader.
SiBoLo is a simple single staged bootloader for fat12 formatted floppys, which
loads a single file from by its name.

More information about the project is [available on my blog](https://blog.kalehmann.de/blog/2017/07/20/simple-boot-loader.html).

## Usage

### Build process

To build the bootloader [The Netwide Assembler (nasm)](https://nasm.us/) has to
be installed.

The bootloader binary (`bootloader.bin`) can be built with

```
make
```

### Configuring the bootloader

The bootloader needs to know the
[8.3 or short filename](https://en.wikipedia.org/wiki/8.3_filename)
of the file it should boot. The filename needs to be written to the offset 498
of the bootloader.

This can be done with the following command:

```
echo "TEST    BIN" | dd of=<bootloader binary> conv=notrunc  bs=1 count=11 seek=498
```

### Write the bootloader to an image

The bootloader can be written to an image with **dd**:

```
dd if=<bootloader binary> of=<image file> conv=notrunc  bs=512 count=1
```

## Development

### Debugging

The bootloader can be debugged with qemu and gdb.

In one terminal window execute

```
make debug
```

and in another terminal window connect with gdb using:

```
gdb \
    -ex "target remote :1234" \
    -ex "set tdesc filename target.xml" \
    -ex "break *0x7c00" \
    -ex "layout asm" \
    -ex "set disassembly-flavor intel" \
    -ex "continue"
```

### Testing

The project has build processes for three floppy images and testcode to verify
that the bootloader works.

The test process is documented in the [`tests` directory](tests/README.md).

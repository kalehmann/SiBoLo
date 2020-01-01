NASM = nasm
NASM_FLAGS = -f bin

QEMU = qemu-system-i386
QEMU_FLAGS = -cpu 486 -boot order=a
QEMU_DEBUG_FLAGS = -S -gdb tcp::1234
QEMU_DISK_DRIVE_FLAGS = -drive if=ide,media=disk,format=raw
QEMU_FLOPPY_DRIVE_FLAGS = -drive if=floppy,index=0,format=raw

BOOTLOADER_BINARY = bootloader.bin
BOOTLOADER_SOURCE = bootloader.asm

FILENAME_OFFSET = 498

TESTCODE_BINARY = TESTCODE.BIN
TESTCODE_SOURCE = tests/testcode.asm
TESTCODE_83_NAME = TESTCODEBIN

TEST_IMAGE_WORKING = test_working.flp
TEST_IMAGE_IO_ERROR = test_io_error.flp
TEST_IMAGE_NOT_FOUND_ERROR = test_not_found.flp

all: $(BOOTLOADER_BINARY)

$(BOOTLOADER_BINARY): $(BOOTLOADER_SOURCE)
	$(NASM) $(NASM_FLAGS) -o $(BOOTLOADER_BINARY) $(BOOTLOADER_SOURCE)

$(TESTCODE_BINARY): $(TESTCODE_SOURCE)
	$(NASM) $(NASM_FLAGS) -o $(TESTCODE_BINARY) $(TESTCODE_SOURCE)

$(TEST_IMAGE_WORKING): $(BOOTLOADER_BINARY) $(TESTCODE_BINARY)
	rm -f $(@)
	mkfs.msdos -C $(@) 1440
	dd if=$(BOOTLOADER_BINARY) of=$(@) conv=notrunc bs=512 count=1
	echo "$(TESTCODE_83_NAME)" | dd \
		of=$(@) \
		conv=notrunc \
		bs=1 \
		count=11 \
		seek=$(FILENAME_OFFSET)
	set -e; \
	LOOP_DEVICE=$$(losetup --find --show $(@)); \
	TEST_IMAGE_MOUNTPOINT=$$(mktemp --directory --quiet); \
	mount $${LOOP_DEVICE} $${TEST_IMAGE_MOUNTPOINT}; \
	cp $(TESTCODE_BINARY) $${TEST_IMAGE_MOUNTPOINT}/; \
	umount $${TEST_IMAGE_MOUNTPOINT}; \
	rm -rf $${TEST_IMAGE_MOUNTPOINT}; \
	losetup -d $${LOOP_DEVICE}

$(TEST_IMAGE_IO_ERROR): $(BOOTLOADER_BINARY)
	rm -f $(@)
	mkfs.msdos -C $(@) 1440
	dd if=$(BOOTLOADER_BINARY) of=$(@) conv=notrunc bs=512 count=1
	echo "TEST    BIN" | dd \
		of=$(@) \
		conv=notrunc \
		bs=1 \
		count=11 \
		seek=$(FILENAME_OFFSET)
	truncate --size=4096 $(@)

$(TEST_IMAGE_NOT_FOUND_ERROR): $(BOOTLOADER_BINARY)
	rm -f $(@)
	mkfs.msdos -C $(@) 1440
	dd if=$(BOOTLOADER_BINARY) of=$(@) conv=notrunc bs=512 count=1
	echo "TEST    BIN" | dd \
		of=$(@) \
		conv=notrunc \
		bs=1 \
		count=11 \
		seek=$(FILENAME_OFFSET)

check: $(TEST_IMAGE_WORKING) $(TEST_IMAGE_NOT_FOUND_ERROR) $(TEST_IMAGE_IO_ERROR)
	$(QEMU) \
		$(QEMU_FLAGS) \
		$(QEMU_FLOPPY_DRIVE_FLAGS),file=$(TEST_IMAGE_WORKING) \
		-name "Test working"
	$(QEMU) \
		$(QEMU_FLAGS) \
		$(QEMU_FLOPPY_DRIVE_FLAGS),file=$(TEST_IMAGE_NOT_FOUND_ERROR) \
		-name "Test file not found"
	$(QEMU) \
		$(QEMU_FLAGS) \
		$(QEMU_DISK_DRIVE_FLAGS),file=$(TEST_IMAGE_IO_ERROR) \
		-name "Test IO error"

debug: $(TEST_IMAGE_WORKING)
	$(QEMU) \
		$(QEMU_FLAGS) \
		$(QEMU_FLOPPY_DRIVE_FLAGS),file=$(TEST_IMAGE_WORKING) \
		-name "Debug bootloader, listen on port 1234" \
		$(QEMU_DEBUG_FLAGS)

clean:
	rm -f \
		$(BOOTLOADER_BINARY) \
		$(TESTCODE_BINARY) \
		$(TEST_IMAGE_WORKING) \
		$(TEST_IMAGE_IO_ERROR) \
		$(TEST_IMAGE_NOT_FOUND_ERROR)

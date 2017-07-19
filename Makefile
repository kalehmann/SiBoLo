all: simple_boot_loader installer

installer:
	gcc -o install_sibolo install.c

simple_boot_loader:
	nasm -f bin -o bootloader.bin bootloader.asm	
clean:
	bootloader.bin

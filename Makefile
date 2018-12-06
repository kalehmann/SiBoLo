all: simple_boot_loader installer

installer:
	gcc -o sibolo-install -g -Wall sibolo-install.c

simple_boot_loader:
	nasm -f bin -o bootloader.bin bootloader.asm	
clean:
	rm -rf bootloader.bin

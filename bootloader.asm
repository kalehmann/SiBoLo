;    Copyright (c) 2017 by Karsten Lehmann <ka.lehmann@yahoo.com>

;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.

; This bootloader loads a file with the name stored in the string file_name to
; 07c0:0 and executes it. The boot sector will be passed in the dl register.
; If there is an error while reading the file or there is no file with this
; name, no error will be printed, since I was not able to also place a print 
; function in the 512 bytes of this bootloader.

; MEMORY MAP
; address		| descrdiption			| size

; 0x500			| bootloader			| 512 bytes
; 0x700			| boot drive			| 1 byte
; 0x701			| root dir start sector		| 1 byte
; 0x702			| root dir size			| 2 bytes
; 0x1500		| stack				| 4096 bytes
; 0x2500		| root directory		| 7168 bytes (estimated)
; 0x4500 (estimated)	| first FAT 			| 4608 bytes (estimated)
; 0x7c00		| second stage			| Who knows?

%define	BOOT_DRIVE 0x200
%define	ROOT_START_SECTOR BOOT_DRIVE + 1	; 0x201
%define ROOT_SIZE ROOT_START_SECTOR + 1		; 0x202
%define FAT_POINTER ROOT_SIZE + 2

%define ROOT_DIR_POINTER 0x2000	; Location of the root directory table right
				; after the stack
				
%define	FILE_SEGMENT 0x07c0	; We load the second stage at 07c0h:0
				; So we have almost a half MiB
				
%define MAX_READ_ATTEMPTS 5	; This number will be found at many bootloaders.
				; It is a relict from the good old times™
				; Back then the people of the stone age stored
				; their data on drives called floppys or
				; diskettes. These devices had a spinable
				; magnet storage medium. There are 5 attempts to
				; make shure the motor reaches the correct
				; speed.

BITS 16			; Tells the assembler to produce 16bit code, because
			; the processor starts in 16bit real mode.

;    This bootloader will load a file from a fat12 filesystem on a floppy.
;    Therefore I will follow the fat implementation. The first three bytes
;    should jump to the beginning of the code. Since jmp short start assembles
;    into 2 bytes we add a nop instruction.
jmp short start
nop

; Next comes the so called Bios Parameter Block, short BPB.
OEMLabel:		db "mkfs.fat"		; 8 Bytes
SectorSize:		dw 512
SectorsPerCluster:	db 1
ReservedForBoot:	dw 1
NumberOfFats:		db 2
NumberOfRootDirEntrys:	dw 224
LogicalSectors:		dw 2880		; 1.440 MB Floopy with 512 bytes
					; sectors = 2880 Sectors
; The next byte describes the type of the used devices. More than one devices
; per type are possible.
; 0xF0	3.5 inch, 2.88 MB, 2 heads, 36 sectors / 
;	3.5 inch, 1.44 MB, 2 heads, 18 sectors
; 0xF9	3.5 inch, 720 KB, 2 heads, 9 sectors /
;	5.25 inch, 1.2 MB, 2 heads, 15 sectors
; 0xFD	5.25 inch, 360 KB, 2 heads, 9 sectors
; 0xFF	5.25 inch, 320 KB, 2 heads, 8 sectors
; 0xFC	5.25 inch, 180 KB, 1 head, 9 sectors
; 0xFE	5.25 inch, 160 KB, 1 head, 8 sectors
; 0xF8	fixed disk
MediumByte:		db 0F0h
SectorsPerFat:		dw 9
SectorsPerTrack:	dw 18
NumberOfHeads:		dw 2
HiddenSectors:		dd 0
LargeSectors:		dd 0
DriveNumber:		dw 0
Signature:		db 41		; Boot signature, the version of the bpb
VolumeID:		dd 0
VolumeLabel:		db "FatTest    "; 11 bytes
FileSystem:		db "FAT12   "	; 8 bytes, should not be changed

start:
	cli			; Disable interupts. They usually push data on
				; the stack, which is not setup yet, so we do
				; not know, where that data goes.

	; Now move the bootloader out of place, so we could load the second
	; stage at the current location.
	; The new location will be 0x50:0
	cld 			; Clear direction flag, move forward !!!
	
	mov ax, 07C0h		; 07C0h:0000h is the point we are loaded to
	mov ds, ax		; Setup source segment
	mov ax, 050h
	mov es, ax		; Setup destination segment
	
	xor di, di		; Destination address
	xor si, si		; Source address
	mov cx, 256		; Move 256 words
	rep movsw

	jmp 0x050:go_on
go_on:
	mov ax, es
	mov ds, ax
	add ax, 100h		; The size of the bootloader is 512 bytes.
				; The segment-registers go in 16-byte-steps.
				; We assume a size of 4096 bytes for our code.
				; So we add (4096/16) to it, to go after our
				; bootloader.
							
	mov ss, ax
	mov sp, 4096		; Set 4K of stack. 

	; SETUP STACK-FRAME
	mov bp, sp

	mov [BOOT_DRIVE], dl	; The bios leaves us the boot drive in dl
	
	sti			; Restore interupts
	
	; Get root directory starting sector
	; It's right after the FATs.
	; ROOT_START_SECTOR = NumberOfFats * SectorsPerFat + ReservedForBoot
	xor ax, ax
	mov al, [NumberOfFats]
	mul word [SectorsPerFat]
	add ax, word [ReservedForBoot]
	mov [ROOT_START_SECTOR], al
	
	; Get root directory size in sectors
	; ROOT_SIZE = (NumberOfRootDirEntrys * EntrySize) / SectorSize
	mov ax, 32			; 32 bytes per entry 
	mul word [NumberOfRootDirEntrys]
	div word [SectorSize]
	mov [ROOT_SIZE], ax
	
	; Get FAT pointer
	mul word [SectorSize]
	add ax, ROOT_DIR_POINTER
	mov word [FAT_POINTER], ax
	
	; Now load the root directory
	mov ax, [ROOT_SIZE]
	xor bx, bx
	mov bl, [ROOT_START_SECTOR]
	mov cx, ROOT_DIR_POINTER
	call readsectors
	
	; Load the first FAT into memory.
	mov ax, [SectorsPerFat]
	mov bx, 1			; FAT 1 starts at the second sector on
					; the disk
	mov cx, [FAT_POINTER]
	call readsectors
	
	; Loop over all entrys of the root directory, search for the next
	; stage and load it
	call loop_over_root
	
readsectors:
	; read n sectors starting from LBA with n in ax and LBA in bx to the
	; segment:address stored in es:cx
	push bp
	mov bp, sp
	sub sp, 8
	mov [bp-2], ax		; Number of sectors to read
	mov [bp-4], bx		; LBA of starting sector
	mov [bp-6], cx		; Where to load
	mov word [bp-8], MAX_READ_ATTEMPTS
	
.read_loop:
	; Now we want to read data from the drive. As said earlyer we make 5
	; attempts, so the motor has enough time to reach the correct speed.
	; Knowing how a floppy is made up really helps understanding the
	; following instructions.
	; Floppys had those thin magnet disks. Some disks were read- and
	; writeable and both sides and others only at one. Reading and writing
	; to such a disk happens by the head over the disk, so you can refer
	; to a side of a disk by the number of its head.
	; The disk is splitted in many circular magnet stripes called tracks for
	; one or two heads and cylinders for more heads.
	; Furthermore a cylinder is splitted in several sectors, which are
	; 1-indexed.
	; For our bootloader we simulate a 3.5" High Density floppy with 1.44Mb
	; and 80 tracks/cylinders, each with 18 sectors of 512 bytes.
	mov ax, [bp-4]
	call lbachs
	
	mov bx, [bp-6]		; read to es:[bp-6]

	; ch, cl and dh are already set from lbachs
	mov dl, [BOOT_DRIVE]
	mov ax, 0000001000000001b	; move 2 in ah and 1 in al
	int 13h
	jnc .read_next_sector
	
	dec word [bp-8]		; If reading wasn't successful after the 5ft try
.read_error:
	jz .read_error		; give up
	jmp .read_loop
	
	
.read_next_sector:
	dec word [bp-2]
	jz .read_done		; Zero sectors remaining
	inc word [bp-4]
	mov ax, [SectorSize]
	add [bp-6], ax
	mov word [bp-8], MAX_READ_ATTEMPTS
	jmp .read_loop
	
.read_done:	
	add sp, 8
	pop bp
	ret

load_file:
	; This function loads a file with the starting cluster in ax to the
	; address stored in bx.
	push bp
	mov bp, sp
	sub sp, 4

	mov [bp-2], ax			; save cluster
	mov [bp-4], bx			; save file_pointer
	
.load_file_loop:	
	mov ax, [bp-2]
	call cluster2LBA
	
	; Read cluster into memory
	mov bx, ax
	xor ax, ax
	mov al, [SectorsPerCluster]
	mov cx, [bp-4]
	call readsectors
	
	; Add the size of a cluster to the file_pointer
	xor ax, ax
	mov al, [SectorsPerCluster]
	mov cx, [SectorSize]
	mul cx
	add [bp-4], ax
		
	; Get next cluster
	mov ax, [bp-2]
	mov cx, ax
	mov dx, ax			; The current cluster is now in ax, cx
					; and dx
	shr     dx, 1			; divide by two
	add     cx, dx			; cluster size in fat12 is 12 bits, 
					; 3/2 bytes.
					; So the next cluster is FAT_POINTER +
					; 3/2 the current cluster.
	mov     bx, [FAT_POINTER]
	add     bx, cx
	mov     dx, [bx]		; read two bytes
	test    ax, 1			; Test if even or odd cluster number and
					; extract the 12 bits of the cluster
	jnz     .odd_cluster
          
.even_cluster:
	and dx, 0111111111111b	; get low 12 bits
	jmp .done
	
.odd_cluster:
	shr dx, 4		; move 4 bits right

.done:
	mov [bp-2], dx
	cmp dx, 0xFFF		; Test for end of file
	jne .load_file_loop
	
	; Else we are done	
	add sp, 4
	pop bp
	ret

cluster2LBA:
	; This function returns the LBA from the cluster in ax in ax

	; Cluster Numbering starts at 2 so we substract 2 from the clusternumber
	; to get zero-based clusternumbers
	; LBA = Cluster * SectorsPerCluster + ROOT_START_SECTOR + ROOT_SIZE
	sub ax, 2
	xor cx, cx
	mov cl, [SectorsPerCluster]
	mul cx
	add al, [ROOT_START_SECTOR]
	add ax, [ROOT_SIZE]
		
	ret
	
lbachs:
	; This function converts a LBA address stored in ax to a chs address
	; with the track/cylinder in ch, sector in cl and head in dh
	push bp
	mov bp, sp			; build stack frame
	
	xor dx, dx			; clean dx for division
	div word [SectorsPerTrack]	; ax -> lba / spt 
					; dx -> lba % spt 
	inc dx	
	mov cl, dl			; sectors = lba% spt + 1

	xor dx, dx			; clean dx for division
	div word [NumberOfHeads]	; ax -> lba / (spt * heads)
					; dx -> (lba / spt) % heads
	mov dh, dl			; store head in dh
					; dl will be replaced later with the
					; drive number
	mov ch, al			; store cylinder in ch
	
	pop bp
	ret

	
loop_over_root:
	; This function loops over all entrys of the root directory, loads the
	; entry with the name stored in file_name to 050h:0 and jumps to it.
	push bp
	mov bp, sp
	sub sp, 4
	mov ax, [NumberOfRootDirEntrys]
	mov [bp-2], ax
	mov word [bp-4], ROOT_DIR_POINTER
	
.loop_over_root_loop:
	mov ax, [bp-4]
	call cmp_f_names
	
	add word [bp-4], 32
	dec word [bp-2]
.loop_over_root_done:
	jz .loop_over_root_done	; At this point the file was not found. So we
				; enter an endless loop.
	jmp .loop_over_root_loop

cmp_f_names:
	; This function compares the String with its address in ax to the string
	; file_name, loads the file if the names are matching and jumps to it.
	push bp
	mov bp, sp
	sub sp, 6
	mov word [bp-2], file_name	; Save pointer to file name
	mov [bp-4], ax			; Save pointer to current file name
	mov [bp-6], ax			; twice.
	
.cmp_loop:
	mov si, [bp-4]
	mov al, [si]
	mov si, [bp-2]
	mov ah, [si]
	or ah, ah		; Check for the zero at the end of the file name 
	je .cmp_success		; if the loop reached it, we found our file.
	cmp al, ah		; Check if the current elements in the strings
				; match.
	jne .cmp_done
	inc word [bp-2]		; Increase string pointers
	inc word [bp-4]
	jmp .cmp_loop

.cmp_success:
	mov ax, FILE_SEGMENT
	mov es, ax		; load to FILE_SEGMENT:0
	mov si, [bp-6]		; start address of the root directory entry
	mov ax, [si+26]
	xor bx, bx
	call load_file
	mov dl, [BOOT_DRIVE]	; Pass the boot drive to the next stage.
	jmp FILE_SEGMENT:0	; far jump to the next stage, we are done now.
	
.cmp_done:
	add sp, 6
	pop bp
	ret
	
; DATA SEGMENT
	file_name db "SecondStage",0	; Name of the file to load, will be
					; replaced by the installer of the
					; bootloader.

; The bios loads exact 512 bytes. Here we fill this file to byte 510 with zeros
; and the add the boot signature.
	times 510-($-$$) db 0	; Pad remainder of boot sector with 0s
	dw 0xAA55		; The standard PC boot signature

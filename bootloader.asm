;;; Copyright 2018 - 2020 by Karsten Lehmann <mail@kalehmann.de>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;; 
;;; This bootloader loads a file with its 8.3 name stored at the offset 498 to
;;; the address 07c0:0 and executes it. The boot drive will be passed in the dl
;;; register.

;;; MEMORY MAP
;;; Description          | Start address      | Size
;;; -------------------------------------------------------------------
;;; This bootloader      |              0x600 |              512 bytes	
;;; Stack                |              0x800 |             4096 bytes
;;; Root directory table |             0x2200 | (estimated) 7168 bytes
;;; First FAT		 | (estimated) 0x3d00 | (estimated) 4608 bytes
;;; Loaded program	 |             0x7c00 |

BITS 16

;;; Total size of the boot code in bytes
%define BootcodeSize 			512
;;; Size of the default boot signature (0xAA55)
%define BootSignatureSize 		2
;;; Size of an 8.3 filename in the directory table
%define FilenameSize			11
;;; Message displayed when the file is not found 
%define FileNotFoundError 		'Not found: '
;;; Size of the message displayed when a file is not found in bytes 
%strlen FileNotFoundErrorSize	 	FileNotFoundError
;;; Load the file to 0x7c0:0. This is also the location the BIOS loads a
;;; bootloader to.
%define	FileSegment 0x7c0
;;; 0x7c0:0 is the current location of this bootloader.
%define InitialBootloaderSegment 0x7c0	
;;; This number will be found at many bootloaders. It is a relict from the good
;;; old times™. Back then the people of the stone age stored their data on drives
;;; called floppy disks or diskettes. These devices had a spin able magnet
;;; storage medium. There are 5 attempts to make sure the motor reaches the
;;; correct speed.
%define MaxReadAttempts 5
%define RelocatedBootloaderSegment 0x60
%define DirectoryTableEntrySize 32	
;;; Location of the root directory table right after the stack
%define RootDirPointer 0x2200
%define StackSegment 0x80
%define StackSize 4096
	
%macro cluster2LBA 0
	;; This macro calculates the LBA from the cluster in ax and saves it in
	;; the ax register.
	;; Cluster numbering starts at 2, therefore first subtract 2 from the
	;; cluster number to get zero-based cluster numbers.
	;; LBA = Cluster * SectorsPerCluster + RootStartSector + RootSize
	sub ax, 2
	xor cx, cx
	mov cl, [SectorsPerCluster]
	mul cx
	add al, [RootStartSector]
	add ax, [RootSize]
%endmacro

%macro lbachs 0
	;; This macro converts a LBA address stored in ax to a chs address
	;; and saves the track/cylinder in the ch register, the sector in the
	;; cl register and the head in the dh register.
	xor dx, dx
	div word [SectorsPerTrack]
	;; ax -> lba / spt
	;; dx -> lba % spt
	inc dx
	;; sectors = lba mod spt + 1
	mov cl, dl
	xor dx, dx
	div word [NumberOfHeads]
	;; ax -> lba / (spt * heads)
	;; dx -> (lba / spt) % heads
	;; Save the head to dh
	mov dh, dl
	;; Save the cylinder to ch
	mov ch, al
%endmacro

%macro getNextCluster 0
	;; Get the next cluster for the cluster in ax
	;; Saves the next cluster in ax.
	mov cx, ax
	mov dx, ax
	;; The current cluster is now in ax, cx and dx
	;; Divide ax by two
	shr     ax, 1
	;; The cluster size in FAT12 is 12 bits, 3/2 bytes. The next cluster
	;; is the FAT pointer + 3/2 the current cluster.
	add     cx, ax
	mov     bx, [FatPointer]
	add     bx, cx
	;; Read two bytes
	mov     ax, [bx]
	;; Test if even or odd cluster number and extract the 12 bits of the
	;; cluster.
	test    dx, 1
	jnz     %%odd_cluster

%%even_cluster:
	;; Get the least significant 12 bits.
	and ax, 0111111111111b
	jmp %%done

%%odd_cluster:
	;; Shift ax 4 bits right to get the 12 most significant bits.
	shr ax, 4
%%done:
%endmacro
	
;;; This bootloader loads a file from a FAT12 formatted drive. According to the
;;; FAT specification, the first three bytes should be used to jump to the
;;; beginning of the code. Since jmp short start assembles into 2 bytes we add a
;;; nop instruction.
jmp short start
nop

;;; Bios Parameter Block, short BPB.
OEMLabel:		db "mkfs.fat"
SectorSize:		dw 512
SectorsPerCluster:	db 1
ReservedForBoot:	dw 1
NumberOfFats:		db 2
NumberOfRootDirEntries:	dw 224
;;; 1.440 MB floppy with a sector size of 512 bytes = 2880 sectors
LogicalSectors:		dw 2880
;;; The next byte describes the type of the used devices. More than one device
;;; per type is possible.
;;; 0xf0  3.5 inch, 2.88 MB, 2 heads, 36 sectors /
;;;       3.5 inch, 1.44 MB, 2 heads, 18 sectors
;;; 0xf9  3.5 inch,  720 KB, 2 heads,  9 sectors /
;;;      5.25 inch,  1.2 MB, 2 heads, 15 sectors
;;; 0xfd 5.25 inch,  360 KB, 2 heads,  9 sectors
;;; 0xff 5.25 inch,  320 KB, 2 heads,  8 sectors
;;; 0xfc 5.25 inch,  180 KB, 1 head,   9 sectors
;;; 0xfe 5.25 inch,  160 KB, 1 head,   8 sectors
;;; 0xf8 fixed disk
MediumByte:		db 0xf0
SectorsPerFat:		dw 9
SectorsPerTrack:	dw 18
NumberOfHeads:		dw 2
HiddenSectors:		dd 0
LargeSectors:		dd 0
DriveNumber:		dw 0
;;; Boot signature, the version of the BPB
Signature:		db 41
VolumeID:		dd 0
;;; 11 bytes
VolumeLabel:		db "sibolo     "
;;; 8 bytes
FileSystem:		db "FAT12   "

start:
	;; Disable interrupts. They usually push data on the stack, which
	;; may not be setup yet.
	cli
	;; Now move the bootloader out of place, so we could load the file to
	;; the current location.
	;; The new location will be 0x50:0
	;; Clear the direction flag -> forward
	cld
	;; Setup source segment and address
	mov ax, InitialBootloaderSegment
	mov ds, ax
	xor si, si
	;; Setup destination segment and address
	mov ax, RelocatedBootloaderSegment
	mov es, ax
	xor di, di
	;; Move 256 words
	mov cx, 256
	rep movsw

	jmp RelocatedBootloaderSegment:go_on
go_on:
	mov ds, ax
	mov ax, StackSegment
	mov ss, ax
	;; Set 4K of stack
	mov sp, StackSize
	;; Setup stack frame
	mov bp, sp
	;; Restore interrups
	sti
	;; The bios passes the boot drive to the bootloader in the dl register
	mov [BootDrive], dl

	;; Get the first sector the the root directory table.
	;; It comes right after the FAT(s).
	;; RootStartSector = NumberOfFats * SectorsPerFat + ReservedForBoot
	xor ax, ax
	mov al, [NumberOfFats]
	mul word [SectorsPerFat]
	add ax, [ReservedForBoot]
	mov [RootStartSector], al

	;; Get the size of the root directory table in sectors.
	;; RootSize = (NumberOfRootDirEntries * EntrySize) / SectorSize
	;; The size of an entry in the root directory table is 32 bytes
	mov ax, DirectoryTableEntrySize
	mul word [NumberOfRootDirEntries]
	div word [SectorSize]
	mov [RootSize], ax

	;; Get FAT pointer
	mul word [SectorSize]
	add ax, RootDirPointer
	mov word [FatPointer], ax

	;; Load the root directory table
	mov ax, [RootSize]
	xor bx, bx
	mov bl, [RootStartSector]
	mov cx, RootDirPointer
	call readsectors

	;; Load the first FAT into memory.
	mov ax, [SectorsPerFat]
	;; The first FAT starts on the second sector on the disk
	mov bx, 1
	mov cx, [FatPointer]
	call readsectors

	;; This function never returns
	call loop_over_root

readsectors:
	;; Read n sectors starting from LBA with n in ax and LBA in bx to the
	;; segment:address stored in es:cx
	push bp
	mov bp, sp
	sub sp, 8
	mov [bp-2], ax
	mov [bp-4], bx
	mov [bp-6], cx
	mov word [bp-8], MaxReadAttempts
	
.read_loop:
	;; Lets read data from the drive. There are at maximum 5 attempts to
	;; read, so that the motor has enough time to reach the correct speed.
	;; Knowing how a floppy is made up really helps understanding the
	;; following code.
	;; Floppy disks had those thin magnet disks. Some disks were read- and
	;; write able and both sides and others only at one. Reading and writing
	;; to such a disk happens by the head over the disk, so a side of the
	;; is commonly referred the by the number of its head.
	;; Each disk is split in many circular magnet stripes. These are
	;; called tracks for one or two heads and cylinders for more heads.
	;; Furthermore a cylinder is split in several sectors, which are
	;; 1-indexed.
	;; For this bootloader a 3.5" High Density floppy with 1.44Mb and 80
	;; tracks/cylinders, each with 18 sectors of 512 bytes is simulated.
	xor ah, ah
	mov dl, [BootDrive]
	int 0x13
	mov ax, [bp-4]
	lbachs
	;; Read to es:[bp-6]
	mov bx, [bp-6]
	;; ch, cl and dh are already set from the call to the lbachs function
	mov dl, [BootDrive]
	;; Move 2 in ah and 1 in al
	mov ax, 0000001000000001b
	int 0x13
	jnc .read_next_sector
	dec word [bp-8]
	jnz .read_loop
	;; Enter an endless loop if reading wasn't successful in the fifth try.
	mov si, ErrorIO
	call print_error

.read_next_sector:
	dec word [bp-2]
	;; Finish if no sectors are remaining
	jz .read_done
	inc word [bp-4]
	mov ax, [SectorSize]
	add [bp-6], ax
	mov word [bp-8], MaxReadAttempts
	jmp .read_loop

.read_done:
	add sp, 8
	pop bp
	ret

load_file:
	;; This function loads a file with the starting cluster in ax to the
	;; address stored in bx.
	push bp
	mov bp, sp
	sub sp, 4

	mov [bp-2], ax
	mov [bp-4], bx

.load_file_loop:
	mov ax, [bp-2]
	cluster2LBA

	;; Read cluster into memory
	mov bx, ax
	xor ax, ax
	mov al, [SectorsPerCluster]
	mov cx, [bp-4]
	call readsectors

	;; Increase the file pointer by the size of a cluster
	xor ax, ax
	mov al, [SectorsPerCluster]
	mov cx, [SectorSize]
	mul cx
	add [bp-4], ax

	mov ax, [bp-2]
	getNextCluster
	mov [bp-2], ax
	;; Test for the special "end of file" marker
	cmp ax, 0xFFF
	jne .load_file_loop

	add sp, 4
	pop bp
	ret

loop_over_root:
	;; This function loops over all entries of the root directory, loads the
	;; entry with the name stored in FileName to 050h:0 and jumps to it.
	;; It never returns.
	mov bp, sp
	sub sp, 4
	mov ax, [NumberOfRootDirEntries]
	mov [bp-2], ax
	mov word [bp-4], RootDirPointer

.loop_over_root_loop:
	mov ax, [bp-4]
	call process_entry

	add word [bp-4], DirectoryTableEntrySize
	dec word [bp-2]
	jnz .loop_over_root_loop
	;; At this point the file was not found, enter an endless loop
	mov si, ErrorFileNotFound
	call print_error

process_entry:
	;; This function processes an entry of the root directory table with its
	;; address in ax and loads the file describe by the entry if the name
	;; matches the 8.3 name stored in FileName.
	mov cx, 11
	mov si, ax
	mov di, FileName
	repe cmpsb
	je .pass_control
	ret

.pass_control:
	;; The si register holds the address of the root directory table entry
	;; of the file to load + 11
	;; The address of the first cluster of the file to load is the address
	;; of the root directory table entry + 26
	;; [si+15] holds the first cluster.
	mov ax, [si+15]
	mov bx, FileSegment
	;; Load to FileSegment:0
	mov es, bx
	xor bx, bx
	call load_file
	;; Pass the boot drive to the next stage.
	mov dl, [BootDrive]
	;; Far jump to the next stage
	jmp FileSegment:0

print_error:
	;; Prints the error string from the address in the si register.
	;; It does not return.
	mov ah, 0xe
	xor bx, bx
.loop:
	lodsb
	int 0x10
	test al, al
	jnz .loop
	jmp $

;;; DATA
	BootDrive 		db 0
	;; Short zero-terminated error message for IO problems
	ErrorIO 		db "IO error", 0
	FatPointer 		dw 0
	RootSize 		dw 0
	RootStartSector 	db 0
	;; The BIOS loads exact 512 bytes.
	;; Here come a few padding bytes to make sure this file is exactly 512
	;; bytes in size.
	times BootcodeSize \
		- FileNotFoundErrorSize \
		- FilenameSize \
		- 1 \
		- BootSignatureSize \
		- ($ - $$) \
		db 0
	;; Short error message for the case that the file is not found.
	;; The message itself has no zero terminator and therefore includes
	;; the 8.3 filename of the file that should be booted.
	ErrorFileNotFound 	db FileNotFoundError
	;; Reserve eleven bytes for the name of the file to boot. The
	;; placeholder will be replaced with the actual name by the program,
	;; that installs the bootloader.
	;; It is placed after the padding bytes to keep its offset in the
	;; bootloader independent from changes it the code at 498.
	FileName times FilenameSize db 0x32
	;; Zero terminate the string with the file not found error
	db 0
	;; The last two bytes contain the standard PC boot signature.
	dw 0xAA55

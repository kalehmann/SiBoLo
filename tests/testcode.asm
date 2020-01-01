;;; Copyright 2020 by Karsten Lehmann <mail@kalehmann.de>
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
;;; This is the test code for the simple bootloader. It is more than one
;;; sector in size and displays a short success message including the boot
;;; drive passed in the dl register.

BITS 16	

;;; The following code is for initialization
init:
	;; Save all registers
	push sp
	push bp
	push ss
	push cs
	push es
	push ds
	push di
	push si
	push dx
	push cx
	push bx
	push ax

	;; Setup the data segment
	mov ax, 0x7c0
	mov ds, ax

	;; Save the boot drive
	mov [boot_drive], dl
	
	;; Set the video mode to text with 16 rows, 80 columns and 16 colors
	xor ah, ah
	mov al, 3
	int 0x10
	
	;; Jump to the test code
	jmp tests

;;; Add a padding to make sure the test binary spans across several sectors on
;;; the floppy
padding:
	times 4096 db 0

tests:
	;; Print a welcome message, the boot drive and the contents of all registers
	mov si, header
	call print_string

	mov si, msg_boot_drive
	call print_string

	xor ax, ax
	mov al, [boot_drive]
	call print_hex
	call line_break

	mov si, msg_registers
	call print_string
	
	mov si, register_ax
	call print_string
	pop ax
	call print_hex
	mov si, register_bx
	call print_string
	pop ax
	call print_hex
	call line_break
	
	mov si, register_cx
	call print_string
	pop ax
	call print_hex
	mov si, register_dx
	call print_string
	pop ax
	call print_hex
	call line_break

	mov si, register_si
	call print_string
	pop ax
	call print_hex
	mov si, register_di
	call print_string
	pop ax
	call print_hex
	call line_break

	mov si, register_ds
	call print_string
	pop ax
	call print_hex
	mov si, register_es
	call print_string
	pop ax
	call print_hex
	call line_break
	
	mov si, register_cs
	call print_string
	pop ax
	call print_hex
	mov si, register_ss
	call print_string
	pop ax
	call print_hex
	call line_break

	mov si, register_bp
	call print_string
	pop ax
	call print_hex
	mov si, register_sp
	call print_string
	pop ax
	call print_hex
	call line_break

loop:
	jmp loop

;;; This function rints the string given in DX:SI to the screen.
;;; It respects line breaks
print_string:
	push bp
	mov bp, sp
	sub sp, 2
.print_loop:
	lodsb
	cmp al, 0
	je .done
	cmp al, 0xa
	jne .no_linebreak
	mov [bp-2], si
	call line_break
	mov si, [bp-2]
	jmp .print_loop
.no_linebreak:
	mov ah, 0xe
	xor bx, bx
	int 0x10
	jmp .print_loop
.done:
	add sp, 2
	pop bp
	ret

line_break:
	mov ah, 3
	xor bx, bx
	int 0x10
	;; Move the cursor to the beginning of the next line
	xor dl, dl
	inc dh
	mov ah, 2
	int 0x10
	ret
	
;;; This function prints the value stored in the AX register as hexadecimal
;;; number to the screen.
print_hex:
	push bp
	mov bp, sp
	sub sp, 2

	;; Save the value of the AX register on the stack
	mov [bp-2], ax

	;; Print the prefix '0x'
	mov ah, 0xe
	mov al,	0x30		; Ascii '0'
	xor bx, bx
	int 10h
	mov al, 0x78		; Ascii 'x'
	int 10h

	ror word [bp-2], 4
	mov cx, 4
.print_loop:
	rol word [bp-2], 4
	;; Fill the AX register with the four most significant bits
	mov ax, [bp-2]
	and ax, 0xf000
	rol ax, 4
	;; Translate the number to the ascii code of its hexadecimal
	;; representation
	mov si, hex_characters
	add si, ax
	;; Print the hexadecimal representation of the number
	mov al, [si]
	mov ah, 0xe
	int 10h
	loop .print_loop
	
	add sp, 2
	pop bp
	ret
	

boot_drive:	db 0
header:		db 0xa, " Simple Bootloader Testcode - Test succeeded", 0xa, 0
hex_characters:	db "0123456789ABCDEF"	
msg_boot_drive:	db " The boot drive passed in the DL register is ", 0
msg_registers:	db " Register contents : ", 0xa, 0xa,  0
register_ax:	db "  AX  ", 0
register_bx:	db " BX  ", 0
register_cx:	db "  CX  ", 0
register_dx:	db " DX  ", 0
register_si:	db "  SI  ", 0
register_di:	db " DI  ", 0
register_bp:	db "  BP  ", 0
register_sp:	db " SP  ", 0
register_ds:	db "  DS  ", 0
register_es:	db " ES  ", 0
register_cs:	db "  CS  ", 0
register_ss:	db " SS  ", 0

org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A



; FAT12 header

jmp short start
nop

dbd_oem: db 'MSWIN4.1' ; 8 bytes
dbd_bytes_per_sector: dw 512 ; 512 bytes
dbd_sectors_per_clustor: db 1
dbd_reserved_sector: dw 1
dbd_fat_cout: db 2
dbd_dir_entires_count: dw 0E0h
dbd_total_sectors: dw 2880
dbd_media_descriptor_type: db 0F0h
dbd_sectors_per_fat: dw 9
dbd_sectors_per_track: dw 18
dbd_heads: dw 2
dbd_hidden_sectors: dd 0
dbd_large_sector_count: dd 0

; extended boot record

ebr_drive_number: db 0
db 0
ebr_signature: db 29h
ebr_volume_id: db 12h, 34h, 56h, 78h
ebr_volume_label: db 'NANOBYTE OS'
ebr_system_id: db 'FAT12   '

start:
	jmp main

puts:
	push si
	push ax
.loop:
	lodsb
	or al, al
	jz .done

	mov ah, 0x0e
	mov bh, 0
	int 0x10

	jmp .loop

.done:
	pop ax
	pop si
	ret


main:
	mov ax, 0
	mov ds, ax
	mov es, ax

	mov ss, ax
	mov sp, 0x7C00

	mov [ebr_drive_number], dl

	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call disk_read

	mov si, msg_hello
	call puts

	cli
	hlt

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0

.halt:
    cli
    hlt

lba_to_chs:
    push ax
    push dx

    xor dx, dx
    div word [dbd_sectors_per_track]

    inc dx
    mov cx, dx

    xor dx, dx
    div word [dbd_heads]

    mov dh, dl
    mov ch, al
    shl ah, 6
    or cl, ah

    pop ax
    mov dl, al
    pop ax
    ret

; reads sectors from a disk
; Parameters:
; - ax: LBA address
; - cl: number of sectors to read (up to 128)
; - dl: drive number
; - es:bx: memory addresses where to store the read data
disk_read:

    push ax
    push bx
    push cx
    push dx
    push di

    push cx ; save cx by pushing to stack
    call lba_to_chs
    pop ax
    mov ah, 02h
    mov di, 3 ; retry count

.retry:
    pusha ; push everything to the stack
    stc ; set cary flag
    int 13h
    jnc .done

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_hello: db 'Hello World', ENDL, 0
msg_read_failed db 'Read from disk failed', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
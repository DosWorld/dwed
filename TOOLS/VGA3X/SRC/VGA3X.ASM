;
; VGA3x
;
;       Here are two resident programs that allow forcibly set VGA adapters
; to 30-line mode when trying to install via BIOS 2nd or 3rd video mode.
;
; VGA3x - checks the video mode setting, and if the 2nd or 3rd one is set,
; then independently sets the 30(34) line mode using VGA ports.
;
; When writing this program, the source code of the program was used
; VGA480 by Dmitry Gurtyak.
;
; Ways of changing the source texts to change the inline modes are
; indicated in the comments.
;
; Published in Softpanorama 1993, Vol 4(38). SP54A
;
; Build:
;
;  nasm -f bin vga3x.asm -DVGA30 -o vga30.com
;  nasm -f bin vga3x.asm -DVGA34 -o vga34.com
;
; License
;
; Public domain
;
; I am (DosWorld) not author, just translate to english and Nasm. :)
;
; Added lines (to reduce tsr-size):
;
;       mov      es, word[PSP_ENV_SEG]
;       mov      ah, INT21_FREE_MEM
;       int      21h
;
; Also, added few minor changes.
;
; Original author:
;
; Vadim V.Belman,
; Dniepropetrovsk,
; Work phone : (0562)448-158
; Network 2:464/20.4@fidonet
;

PSP_ENV_SEG        equ 2Ch

INT21_FREE_MEM     equ 49h
INT21_GET_INT_VECT equ 35h
INT21_SET_INT_VECT equ 25h

INT27_TSR          equ 27h

        section  .code
        bits     16
        org      100h

        jmp      main_part

SeqData:
        dw       00100h
        dw       00001h
        dw       00302h
        dw       00003h
        dw       00204h
        dw       00300h

        dw       00c11h
        dw       00b06h
        dw       03e07h
%ifdef VGA30
; 04f09h for 30 lines
        dw       04f09h
%endif
%ifdef VGA34
; 04d09h for 34 lines
        dw       04d09h
%endif
        dw       0ea10h
        dw       08c11h
%ifdef VGA30
; 0df12h for 30 lines
        dw       0df12h
%endif
%ifdef VGA34
; 0db12h for 34 lines
        dw       0db12h
%endif
        dw       0e715h
        dw       00416h
clear_scr:
        db       0
int10h:
        pushf
        cmp      ah, 0
        je       analog_mode
        jmp      end_res
analog_mode:
        mov      byte[cs: clear_scr],1
        cmp      al, 3
        je       set_30
        cmp      al, 2
        jne      without_cls
        jmp      short set_30

without_cls:
        cmp      al, 82h
        je       set_30_wc
        cmp      al, 83h
        je       set_30_wc
        jmp      end_res
set_30_wc:
        mov      byte[cs: clear_scr],0
set_30:
        push     ax
        push     bx
        push     cx
        push     dx
        push     si
        push     ds
        push     es

        mov      ax, cs
        mov      ds, ax

        mov      ax, 0003h
        pushf
; call dword[old_10] is replaced with 0ffh, 1eh
        db       0ffh, 1eh
        dw       old_10
%ifdef VGA30
; 1114h for 30 lines
        mov      ax, 1114h
%endif
%ifdef VGA34
; 1111h for 34 lines
        mov      ax, 1111h
%endif

        mov      bl, 0
        pushf
; call dword[old_10] is replaced with 0ffh, 1eh
        db       0ffh, 1eh
        dw       old_10
        mov      si, SeqData
        mov      dx, 3c4h
        mov      cx, 5
        cld
lp1:
        lodsw
        out      dx, ax
; loop sequencer write
        loop     lp1
        mov      dl, 0c2h
; code for 480
        mov      al, 0e7h
; write misc register
        out      dx, al
; sequencer adr. again
        mov      dl, 0c4h
        lodsw
        out      dx, ax
; 0b4h for mono
        mov      dl, 0d4h
        mov      cx, 9
lp2:
        lodsw
        out      dx, ax
; loop CRTC write
        loop     lp2

        xor      ax, ax
        mov      es, ax
%ifdef VGA30
; 29 for 30 lines
        mov      byte[es: 484h],29
%endif
%ifdef VGA34
; 33 for 34 lines
        mov      byte[es: 484h],33
%endif
; for cursor emulate
        and      byte[es: 487h],0feh
; set video mode 3
        mov      byte[es: 449h],3
%ifdef VGA30
; 12C0 for 30 lines
        mov      word[es: 44Ch],12C0h
%endif
%ifdef VGA34
; 1540 for 34 lines
        mov      word[es: 44Ch],1540h
%endif
        mov      bx,[es: 044eh]
        mov      ax, 0b800h
        mov      es, ax
        mov      byte[es: bx],'#'

        cmp      byte[cs: clear_scr],1
        jne      end_set
        mov      ax, 0600h
        xor      cx, cx
        mov      dx, 1D4Fh
        mov      bh, 07h
        pushf
; call dword[old_10] is replaced with 0ffh, 1eh
        db       0ffh, 1eh
        dw       old_10
end_set:
        pop      es
        pop      ds
        pop      si
        pop      dx
        pop      cx
        pop      bx
        pop      ax
        popf
        iret
end_res:
        popf
; jmp far
        db       0eah
old_10:
offs:
        dw       0
segm:
        dw       0
; ----------------------------------------------
tsr_end:
msg:    db 'VGA3x driver installed.', 0Dh, 0Ah, '$'
main_part:
        push     cs
        pop      ds
        mov      ah, INT21_GET_INT_VECT
        mov      al, 10h
        int      21h
        mov      word[segm],es
        mov      word[offs],bx

        mov      dx, int10h
        mov      al, 10h
        mov      ah, INT21_SET_INT_VECT
        int      21h

        mov      ah, 0
        mov      al, 3
        int      10h

        mov      es, word[PSP_ENV_SEG]
        mov      ah, INT21_FREE_MEM
        int      21h

        mov      dx, msg
        mov      ah, 9
        int      21h

        mov      dx, tsr_end
        int      INT27_TSR


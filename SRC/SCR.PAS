{ MIT License

Copyright (c) 2020 Viacheslav Komenda

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. }
{$F+}
unit scr;

interface

var
        screen        : pchar;
        cursor        : word;

procedure cls(clr : byte);
procedure cln(x, y : integer; clr : byte);
procedure print(x, y : integer; clr : byte; s : string);
procedure printhl(x, y : integer; clr, hlclr : byte; s : string);
procedure hprint(x, y:integer; clr : byte; c : char; len : integer);
procedure vprint(x, y:integer; clr : byte; c : char; len : integer);
procedure chcolor(x, y:integer; clr : byte; len: integer);

procedure push;
procedure pop;
procedure pick;
procedure show;

procedure locate(x, y:integer);

procedure cursor_off;
procedure cursor_on;
procedure cursor_big;

function get_cursor:word;
procedure set_cursor(w : word);

procedure set_blink(on : boolean);

function getwidth:integer;
function getheight:integer;

function getx:integer;
function gety:integer;

procedure scroll_up(stx, sty, w, h, lines : integer);
procedure scroll_down(stx, sty, w, h, lines : integer);

procedure spinner_start;
procedure spinner_stop;

procedure Fade0;
procedure FadeIn;
procedure FadeOut;

procedure reset_palette;
procedure gray_palette;

procedure WaitRetrace;

implementation

uses kminput, dos, detect;

const vseg : word = 0;
SPINNER : string[8] = '|/-\|/-\';

type

PScr=^TScr;
TScr=record
        prev   : PScr;
        size   : word;
        x, y   : integer;
        buf    : byte;
end;

const
last_scr_buf : PScr = nil;
FADE_STEP  = 8;
FADE_DELAY = 15;

var
screen_size, line_size : word;

spinnerValue  : word;
spinnerOldInt : pointer;
spinnerOn     : boolean;

palette : array[0..(256 * 3)] of byte;
vga     : boolean;

function getheight : integer;assembler;
asm
        push       ds
        mov        ax, seg0040
        mov        ds, ax
        mov        al, byte ptr[$0084]
        xor        ah, ah
        inc        ax
        pop        ds
end;

function getwidth : integer;assembler;
asm
        push       ds
        mov        ax, seg0040
        mov        ds, ax
        mov        ax, word ptr[$004a]
        pop        ds
end;

{ in: ax = x, cx = y }
{ out: es:di }
procedure buf_es_di;assembler;
asm
        mov        bx, ax
        mov        ax, line_size
        mul        cx
        xchg       bx, ax
        shl        ax, 1
        add        ax, bx
        les        di, screen
        add        di, ax
end;

procedure cls(clr : byte);assembler;
asm
        push       es

        mov        ax, screen_size
        shr        ax, 1
        xchg       ax, cx
        mov        ah, clr
        mov        al, ' '
        les        di, screen
        cld
        repz       stosw

        pop        es
end;

procedure cln(x, y : integer; clr : byte);assembler;
asm
        push       es

        call       getwidth
        push       ax
        mov        ax, x
        mov        cx, y
        call       buf_es_di
        pop        cx
        sub        cx, x
        mov        ah, clr
        mov        al, ' '
        cld
        repz       stosw

        pop        es
end;

procedure hprint(x, y : integer; clr : byte; c : char; len : integer);assembler;
asm
        push       es
        mov        ax, x
        mov        cx, y
        call       buf_es_di
        xor        ch, ch
        mov        cx, len
        xor        ch, ch
        mov        ah, clr
        mov        al, c
        cld
        repz       stosw
        pop        es
end;

procedure chcolor(x, y : integer; clr : byte; len : integer);assembler;
asm
        push       es
        mov        ax, x
        mov        cx, y
        call       buf_es_di
        inc        di
        mov        cx, len
        mov        al, clr
        cld
        or         cl, cl
        jz         @end
@cont:
        stosb
        inc        di
        dec        cl
        jnz        @cont
@end:
        pop        es
end;

procedure vprint(x, y : integer; clr : byte; c : char; len : integer);assembler;
asm
        push       es
        mov        ax, x
        mov        cx, y
        call       buf_es_di
        mov        bx, line_size
        sub        bx, 2
        mov        cx, len
        mov        ah, clr
        mov        al, c
        cld
        or         cl, cl
        jz         @end
@cont:
        stosw
        add        di, bx
        dec        cl
        jnz        @cont
@end:
        pop        es
end;

procedure print(x, y:integer; clr : byte; s : string);assembler;
asm
        push       es
        push       ds

        mov        ax, x
        mov        cx, y
        call       buf_es_di
        mov        ah, clr
        lds        si, s
        lodsb
        or         al, al
        jz         @end
        mov        cl, al
        cld
@cont:
        lodsb
        stosw
        dec        cl
        jnz        @cont
@end:
        pop        ds
        pop        es
end;

procedure printhl(x, y : integer; clr, hlclr : byte; s : string);assembler;
asm
        push       es
        push       ds

        mov        ax, x
        mov        cx, y
        call       buf_es_di

        mov        ah, clr
        mov        bh, hlclr
        lds        si, s
        lodsb
        or         al, al
        jz         @end
        mov        cl, al
        cld
@cont:
        lodsb
        cmp        al, '~'
        jnz        @print
        xchg       ah, bh
        jmp        @cont2
@print:
        stosw
@cont2:
        dec        cl
        jnz        @cont
@end:
        pop        ds
        pop        es
end;

procedure show;assembler;
asm
        call       mouse_hide
        call       WaitRetrace
        push       es
        push       ds


        mov        ax, screen_size
        shr        ax, 1
        mov        cx, ax
        mov        ax, vseg
        mov        es, ax
        lds        si, screen
        xor        di, di
        cld
        repz       movsw

        pop        ds
        pop        es

        call       mouse_show
end;

procedure locate(x, y : integer);assembler;
asm
        push       ds
        mov        ax, word ptr [seg0040]
        mov        ds, ax
        mov        bh, byte ptr [$0062]
        pop        ds

        mov        dl, byte ptr [x]
        mov        dh, byte ptr [y]
        mov        ah, 2
        int        $10
end;

function getx : integer;assembler;
asm
        push       ds
        mov        ax, word ptr [seg0040]
        mov        ds, ax
        mov        bh, byte ptr [$0062]
        pop        ds

        mov        ah, 3
        int        $10
        mov        al,dl
        xor        ah,ah
end;

function gety : integer;assembler;
asm
        push       ds
        mov        ax, word ptr [seg0040]
        mov        ds, ax
        mov        bh, byte ptr [$0062]
        pop        ds

        mov        ah, 3
        int        $10
        mov        al,dh
        xor        ah,ah
end;

procedure push;
var p : PScr;
begin
        getmem(p, screen_size + sizeof(TScr) - 1);
        p^.size := screen_size;
        p^.prev := last_scr_buf;
        p^.x := getx;
        p^.y := gety;
        move(screen^, p^.buf, p^.size);
        last_scr_buf := p;
end;

procedure pop;
var p : PScr;
begin
        if last_scr_buf = nil then exit;
        WaitRetrace;
        move(last_scr_buf^.buf, screen^, last_scr_buf^.size);
        p := last_scr_buf;
        last_scr_buf := last_scr_buf^.prev;
        scr.locate(p^.x, p^.y);
        freemem(p, p^.size + sizeof(TScr) - 1);
end;

procedure pick;
begin
        if last_scr_buf = nil then exit;
        WaitRetrace;
        move(last_scr_buf^.buf, screen^, last_scr_buf^.size);
        scr.locate(last_scr_buf^.x, last_scr_buf^.y);
end;

procedure set_cursor(w : word);assembler;
asm
        mov        cx, w
        mov        ah, 1
        int        $10
end;

function get_cursor : word;assembler;
asm
        mov        ah, $0f
        int        $10
        mov        ah, 3
        int        $10
        mov        ax, cx
end;


procedure cursor_off;
begin
        set_cursor($2020);
end;

procedure cursor_on;
begin
        set_cursor(cursor);
end;

procedure cursor_big;
begin
        set_cursor(cursor and $FF);
end;

procedure set_blink(on : boolean);assembler;
asm
        mov        bl, byte ptr [on]
        mov        ax, $1003
        int        $10
end;

procedure scroll_up(stx, sty, w, h, lines : integer);
var i      : integer;
    scrw   : integer;
    slines : integer;
    cur    : integer;
begin
        i := 0; w := w shl 1; scrw := getwidth;
        slines := (lines * scrw) shl 1;
        cur := (stx + (sty * scrw)) shl 1;
        scrw := scrw shl 1;
        WaitRetrace;
        while i < (h - lines) do begin
                move(screen[slines + cur], screen[cur], w);
                inc(cur, scrw);
                inc(i);
        end;
end;

procedure scroll_down(stx, sty, w, h, lines : integer);
var i      : integer;
    scrw   : integer;
    slines : integer;
    cur    : integer;
begin
        i := h - lines; w := w shl 1; scrw := getwidth;
        slines := (lines * scrw) shl 1;
        cur := (stx + i * scrw) shl 1;
        scrw := scrw shl 1;
        WaitRetrace;
        while i >= 0 do begin
                move(screen[cur], screen[slines + cur], w);
                dec(cur, scrw);
                dec(i);
        end;
end;

procedure spinner1c;interrupt;
var spin : char;
begin
        spin := SPINNER[((spinnerValue shr 3) mod length(SPINNER)) + 1];
        mem[vseg:0] := Ord(spin);
        mem[vseg:1] := $20;
        screen^ := spin;
        screen[1] := #$20;
        Inc(spinnerValue);
        if spinnerValue = 90 then gray_palette;
end;

procedure spinner_start;
begin
        if spinnerOn then exit;
        spinnerValue := 0;
        SetIntVec($1c, @spinner1c);
        spinnerOn := true;
end;

procedure spinner_stop;
begin
        SetIntVec($1c, spinnerOldInt);
        reset_palette;
        spinnerOn := false;
end;

procedure delay(ms : word); assembler;
asm
        mov  ax, 1000
        mul  ms
        mov  cx, dx
        mov  dx, ax
        mov  ah, $86
        int  $15
end;

procedure save_palette;
var     i : integer;
begin
        if not vga then exit;
        for i := 0 to 255 do begin
                Port[$3C7] := i;
                Palette[i * 3] := Port[$3C9];
                Palette[i * 3 + 1] := Port[$3C9];
                Palette[i * 3 + 2] := Port[$3C9];
        end;
end;

procedure set_color(num, r, g, b : byte);
begin
        Port[$3C8] := num;
        Port[$3C9] := r;
        Port[$3C9] := g;
        Port[$3C9] := b;
end;

procedure reset_palette;
var     i : integer;
begin
        if not vga then exit;
        for i := 0 to 255 do begin
                set_color(i, palette[i * 3], palette[i * 3 + 1], palette[i * 3 + 2]);
        end;
end;

procedure gray_palette;
var     i, n : integer;
begin
        if not vga then exit;
        for i := 0 to 255 do begin
                n := palette[i * 3] + palette[i * 3 + 1] + palette[i * 3 + 2];
                n := n div 6;
                set_color(i, n, n, n);
        end;
end;

procedure Fade0;
var     i : integer;
begin
        if not vga then exit;
        WaitRetrace;
        for i := 0 to 255 do begin
                set_color(i, 0, 0, 0);
        end;
end;

procedure FadeIn;
var     op1, op2, op3 : byte;
        p1, p2, p3    : byte;
        i, j          : integer;
begin
        if not vga then exit;
        Fade0;
        for j := 0 to 7 do begin
                WaitRetrace;
                for i := 0 to 255 do begin
                        Port[$3C7] := i;
                        op1 := Port[$3C9];
                        op2 := Port[$3C9];
                        op3 := Port[$3C9];
                        p1 := palette[i * 3];
                        p2 := palette[i * 3 + 1];
                        p3 := palette[i * 3 + 2];
                        if op1 + FADE_STEP <= p1 then Inc(op1, FADE_STEP) else op1 := p1;
                        if op2 + FADE_STEP <= p2 then Inc(op2, FADE_STEP) else op2 := p2;
                        if op3 + FADE_STEP <= p3 then Inc(op3, FADE_STEP) else op3 := p3;
                        set_color(i, op1, op2, op3);
                end;
                delay(FADE_DELAY);
        end;
end;


procedure FadeOut;
var     op1, op2, op3 : byte;
        i, j          : integer;
begin
        if not vga then exit;
        for j := 0 to 7 do begin
                WaitRetrace;
                for i := 0 to 255 do begin
                        Port[$3C7] := i;
                        op1 := Port[$3C9];
                        op2 := Port[$3C9];
                        op3 := Port[$3C9];
                        if op1 >= FADE_STEP then Dec(op1, FADE_STEP) else op1 := 0;
                        if op2 >= FADE_STEP then Dec(op2, FADE_STEP) else op2 := 0;
                        if op3 >= FADE_STEP then Dec(op3, FADE_STEP) else op3 := 0;
                        set_color(i, op1, op2, op3);
                end;
                delay(FADE_DELAY);
        end;
        reset_palette;
end;

procedure WaitRetrace; assembler;
asm
        mov  dx, $3da
@l1:    in   al, dx
        test al, 8
        jnz  @l1
@l2:    in   al, dx
        test al, 8
        jz   @l2
end;

begin
        GetIntVec($1c, spinnerOldInt);
        spinnerOn := false;
        vga := Detect.IsVga;
        save_palette;
        cursor := scr.get_cursor;
        if (not vga) and IsMonochrome then vseg := segb000 else vseg := segb800;
        scr.set_blink(false);
        screen_size := (scr.getwidth * scr.getheight) shl 1;
        line_size := scr.getwidth shl 1;
        getmem(screen, screen_size);
        move(mem[vseg:0], screen^, screen_size);
        mouse_show;
end.

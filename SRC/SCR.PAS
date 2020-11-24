{
 MIT License

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
SOFTWARE.
}
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
function is_monochrome:boolean;

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

implementation

uses mouse;

const vseg : word = 0;

type

PScr=^TScr;
TScr=record
        prev   : PScr;
        size   : word;
        x, y   : integer;
        buf    : byte;
end;

const

last_scr_buf    : PScr = nil;

var screen_size, line_size : word;

function getheight:integer;assembler;
asm
        push       ds
        mov        ax, seg0040
        mov        ds, ax
        mov        al, byte ptr[$0084]
        xor        ah, ah
        inc        ax
        pop        ds
end;

function getwidth:integer;assembler;
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
        call       mhide

        push       es
        push       ds


        mov        ax, vseg
        mov        es, ax
        mov        cx, screen_size
        lds        si, screen
        xor        di, di
        cld
        repz       movsb

        pop        ds
        pop        es

        call       mshow
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

function getx:integer;assembler;
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

function gety:integer;assembler;
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
var     p : PScr;
begin
        getmem(p, screen_size + sizeof(TScr) - 1);
        p^.size := screen_size;
        p^.prev := last_scr_buf;
        p^.x := getx;
        p^.y := gety;
        move(screen[0], p^.buf, p^.size);
        last_scr_buf := p;
end;

procedure pop;
var p : PScr;
begin
        if last_scr_buf = nil then exit;
        move(last_scr_buf^.buf, screen[0], last_scr_buf^.size);
        p := last_scr_buf;
        last_scr_buf := last_scr_buf^.prev;
        scr.locate(p^.x, p^.y);
        freemem(p, p^.size + sizeof(TScr) - 1);
end;

procedure pick;
begin
        if last_scr_buf = nil then exit;
        move(last_scr_buf^.buf, screen[0], last_scr_buf^.size);
        scr.locate(last_scr_buf^.x, last_scr_buf^.y);
end;

procedure set_cursor(w : word);assembler;
asm
        mov        cx, w
        mov        ah, 1
        int        $10
end;

function get_cursor:word;assembler;
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

function is_monochrome:boolean;assembler;
asm
        push       ds
        mov        ax, word ptr [seg0040]
        mov        ds, ax
        mov        al, byte ptr [$0065]
        pop        ds
        and        al, 4
end;

procedure scroll_up(stx, sty, w, h, lines : integer);
var i    : integer;
    scrw : integer;
begin
        i := 0; w := w shl 1; scrw := getwidth;
        while i < (h - lines) do begin
                move(screen[(stx + (sty + i + lines) * scrw) shl 1], screen[(stx + (sty + i) * scrw) shl 1], w);
                inc(i);
        end;
end;

procedure scroll_down(stx, sty, w, h, lines : integer);
var i    : integer;
    scrw : integer;
begin
        i := h - lines; w := w shl 1; scrw := getwidth;
        while i >= 0 do begin
                move(screen[(stx + (sty + i) * scrw) shl 1], screen[(stx + (sty + i + lines) * scrw) shl 1], w);
                dec(i);
        end;
end;

begin
        cursor := get_cursor;
        if is_monochrome then vseg := segb000 else vseg := segb800;
        set_blink(false);
        screen_size := (getwidth * getheight) shl 1;
        line_size := getwidth shl 1;
        getmem(screen, screen_size);
        move(mem[vseg:0], screen[0], screen_size);
        mouse.mshow;
end.

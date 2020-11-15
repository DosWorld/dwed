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
{$G-,B-,F+,S-,R-,I-}
unit scr;
{$ifdef go32v2}
{$asmmode intel}
{$endif}
interface

var
        screen        : pchar;
        cursor_start  : byte;
        cursor_end    : byte;

procedure init;
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

function get_cursor_start:byte;
function get_cursor_end:byte;
procedure set_cursor(start_line, end_line : byte);

procedure set_blink(on : boolean);

function getwidth:integer;
function getheight:integer;

function getx:integer;
function gety:integer;

implementation

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
        mov        ax, word ptr [seg0040]
        mov        ds, ax
        mov        al, byte ptr[$0084]
        xor        ah, ah
        inc        ax
        pop        ds
end;

function getwidth:integer;assembler;
asm
        push       ds
        mov        ax, word ptr [seg0040]
        mov        ds, ax
        mov        ax, word ptr[$004a]
        pop        ds
end;

{ in: ax = x, cx = y }
{ out: es:di }
procedure buf_es_di;assembler;
asm
        mov        bx, ax
        mov        ax, word ptr [line_size]
        mul        cx
        xchg       bx, ax
        shl        ax, 1
        add        ax, bx
        les        di, [screen]
        add        di, ax
end;

procedure cls(clr : byte);assembler;
asm
        mov        ax, word ptr [screen_size]
        shr        ax, 1
        xchg       ax, cx
        mov        ah, clr
        mov        al, ' '
        push       es
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
        mov        cx, len
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
        or         cx, cx
        jz         @end
@cont:
        stosb
        inc        di
        dec        cx
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
        mov        cx, len
        mov        ah, clr
        mov        al, c
        or         cx, cx
        jz         @end
@cont:
        mov        word ptr [es:di], ax
        add        di, bx
        dec        cx
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
        lea        bx, s
        mov        ah, clr
        mov        si, [ss:bx]
        mov        bx, [ss:bx+2]
        mov        ds, bx
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

        mov        ax, word ptr [x]
        mov        cx, word ptr [y]
        call       buf_es_di

        lea        bx, s
        mov        si, word ptr [ss:bx]
        mov        ax, word ptr [ss:bx+2]
        mov        ds, ax
        xor        ah, ah
        lodsb
        or         ax, ax
        jz         @end
        mov        cx, ax
        mov        ah, byte ptr [ss:clr]
        mov        bh, byte ptr [ss:hlclr]
        cld
@cont:
        lodsb
        cmp        al, '~'
        jnz        @print
        xchg       ah,bh
        jmp        @cont2
@print:
        stosw
@cont2:
        dec        cx
        jnz        @cont
@end:
        pop        ds
        pop        es
end;

procedure show;assembler;
asm
        push       es
        push       ds

        mov        ax, word ptr [vseg]
        mov        es, ax
        mov        cx, [screen_size]
        mov        si, word ptr [screen]
        mov        ax, word ptr [screen+2]
        mov        ds, ax
        xor        di, di
        cld
        repz       movsb

        pop        ds
        pop        es
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
        mov        al, byte ptr [$0062]
        xor        ah, ah
        shl        ax, 1
        add        ax, $50
        mov        bx, ax
        mov        al, byte ptr [bx];
        xor        ah, ah
        pop        ds
end;
{
begin
        getx := mem[Seg0040 : (mem[Seg0040:$62] shl 1) + $50] and $ff;
end;
}

function gety:integer;assembler;
asm
        push       ds
        mov        ax, word ptr [seg0040]
        mov        ds, ax
        mov        al, byte ptr [$0062]
        xor        ah, ah
        shl        ax, 1
        add        ax, $51
        mov        bx, ax
        mov        al, byte ptr [bx];
        xor        ah, ah
        pop        ds
end;
{
begin
        gety := mem[Seg0040:(mem[Seg0040:$62] shl 1) + $51] and $ff;
end;
}

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

procedure set_cursor(start_line, end_line : byte);assembler;
asm
        push       ds
        push       es
        push       bp
        mov        ch, byte ptr [start_line]
        mov        cl, byte ptr [end_line]
        mov        ah, 1
        int        $10
        pop        bp
        pop        es
        pop        ds
end;

procedure cursor_off;
begin
        set_cursor($20, $20);
end;

procedure cursor_on;
begin
        set_cursor(cursor_start, cursor_end);
end;

procedure cursor_big;
begin
        set_cursor(0, cursor_end);
end;

procedure set_blink(on : boolean);assembler;
asm
        mov        bl, byte ptr [on]
        mov        ax, $1003
        int        $10
end;

function get_cursor_start:byte;assembler;
asm
        mov        ah, 3
        int        $10
        mov        al, ch
end;

function get_cursor_end:byte;assembler;
asm
        mov        ah, 3
        int        $10
        mov        al, cl
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

procedure init;
begin
        if is_monochrome then vseg := segb000 else vseg := segb800;
        set_blink(false);
        cursor_start := get_cursor_start;
        cursor_end := get_cursor_end;
        screen_size := (getwidth * getheight) shl 1;
        line_size := getwidth shl 1;
        getmem(screen, screen_size);
{$ifdef go32v2}
        move(ptr(vseg, 0), screen[0], screen_size);
{$else}
        move(mem[vseg:0], screen[0], screen_size);
{$endif}
end;

begin
        init;
end.

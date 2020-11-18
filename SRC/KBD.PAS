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
{$G-,S-,R-,I-}
unit kbd;

interface

const

K_ESC            = $011b;
K_ENTER          = $1c0d;

K_UP             = $4800;
K_DOWN           = $5000;
K_LEFT           = $4B00;
K_RIGHT          = $4D00;
K_PGUP           = $4900;
K_PGDN           = $5100;
K_HOME           = $4700;
K_END            = $4F00;

K_SHIFT_UP       = $4800;
K_SHIFT_DOWN     = $5000;
K_SHIFT_LEFT     = $4B00;
K_SHIFT_RIGHT    = $4D00;
K_SHIFT_PGUP     = $4939;
K_SHIFT_PGDN     = $5133;
K_SHIFT_HOME     = $4737;
K_SHIFT_END      = $4F31;

K_CTRL_LEFT      = $7300;
K_CTRL_RIGHT     = $7400;
K_CTRL_PGUP      = $8400;
K_CTRL_PGDN      = $7600;

K_CTRL_HOME      = $7700;
K_CTRL_END       = $7500;

K_TAB            = $0F09;
K_SHIFT_TAB      = $0F00;

K_BS             = $0E08;
K_DEL            = $5300;
K_INS            = $5200;

K_F1             = $3B00;
K_F2             = $3C00;
K_F3             = $3D00;
K_F5             = $3F00;
K_F6             = $4000;
K_F7             = $4100;
K_F8             = $4200;
K_F9             = $4300;
K_F10            = $4400;

K_SHIFT_F2       = $5500;

K_ALT_F2         = $6900;
K_ALT_F3         = $6A00;
K_ALT_F4         = $6B00;
K_ALT_F5         = $6C00;
K_ALT_F6         = $6D00;
K_ALT_F10        = $7100;

K_CTRL_S         = $1F13;

K_CTRL_X         = $2D18;
K_CTRL_C         = $2E03;
K_CTRL_V         = $2F16;

K_CTRL_Y         = $1519;
K_CTRL_U         = $1615;
K_CTRL_G         = $2207;
K_CTRL_L         = $260C;
K_CTRL_F         = $2106;
K_CTRL_K         = $250B;
K_CTRL_O         = $180F;

K_CTRL_ALT_A     = $1E00;
K_CTRL_ALT_C     = $2E00;
K_CTRL_ALT_H     = $2300;

function getkey:word;
function haskey:boolean;
procedure reset;
procedure fast;

function is_ctrl:boolean;
function is_alt:boolean;
function is_shift:boolean;

implementation

var have_ext_kb : boolean;

function getkey:word;assembler;
asm
        xor        ah, ah
        cmp        have_ext_kb, 0
        je         @cont
        mov        ah, $10
@cont:
        int        $16
end;

function haskey:boolean;assembler;
asm
        mov        ah, 1
        int        $16
        mov        cx, 0
        jz         @nokey
        dec        cx
@nokey:
        mov        ax, cx
end;

function flags:byte;assembler;
asm
        push       es
        mov        ax, Seg0040
        mov        es, ax
        mov        al, byte ptr es:[$17]
        pop        es
end;

function is_ctrl:boolean;
begin
        is_ctrl := (flags and $4) <> 0;
end;

function is_alt:boolean;
begin
        is_alt := (flags and $8) <> 0;
end;

function is_shift:boolean;
begin
        is_shift := (flags and $3) <> 0;
end;

procedure fast;assembler;
asm
        mov        ax, $0305
        xor        bx, bx
        int        $16
end;

procedure reset;
begin
        while haskey do getkey;
end;

function get_kbd_funct:byte;assembler;
asm
        mov        ax, $0900
        int        $16
end;

begin
        have_ext_kb := false; { (get_kbd_funct and $20) <> 0;}
end.

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
unit mouse;

interface

const
MOUSE_B1 = 1;
MOUSE_B2 = 2;

procedure mshow;
procedure mhide;
function mvisible:boolean;
function mbuttons:byte;
function mgetx:integer;
function mgety:integer;
function mavail:boolean;

implementation

var present : boolean;
state : boolean;

function mavail:boolean;assembler;
asm
        mov      al, present
end;

function mvisible:boolean;assembler;
asm
        mov       al, present
        or        al, al
        jz        @nomouse
        mov       al, state
@nomouse:
end;

procedure mshow;assembler;
asm
        mov       al, present
        or        al, al
        jz        @nomouse
        mov       ax, 1
        int       $33
        mov       al, 1
        mov       state, al
@nomouse:
end;

procedure mhide;assembler;
asm
        mov       al, present
        or        al, al
        jz        @nomouse
        mov       ax, 2
        xor       al, al
        mov       state, al
@nomouse:
end;

function mbuttons:byte;assembler;
asm
        mov       al, present
        or        al, al
        jz        @nomouse
        mov       ax, 3
        int       $33
        mov       al, bl
        and       al, 3
@nomouse:
end;

function mgetx:integer;assembler;
asm
        mov       al, present
        or        al, al
        jz        @nomouse
        mov       ax, 3
        int       $33
        mov       ax, cx
        mov       cl ,3
        shr       ax, cl
@nomouse:
end;

function mgety:integer;assembler;
asm
        mov       al, present
        or        al, al
        jz        @nomouse
        mov       ax, 3
        int       $33
        mov       ax, dx
        mov       cl ,3
        shr       ax, cl
@nomouse:
end;

begin
asm
        xor       ax, ax
        int       $33
        mov       present, al
end;
end.
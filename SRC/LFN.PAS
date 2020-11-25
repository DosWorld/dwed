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
{$G-,S-,R-,I-,F+}
unit lfn;

interface

const
SEEK_BEG   = 0;
SEEK_CUR   = 1;
SEEK_END   = 2;

function checkDriveExist(disk : byte):boolean;
function getAllDrives:string;

procedure file_create(fname : string);
function file_exists(fname : string):boolean;
procedure file_delete(fname : string);
function file_size(fname : string):longint;

function lopen_r(fname:string):word;
function lopen_w(fname:string):word;
function lopen_rw(fname:string):word;

function lread(handl : word; var dest; count : word):word;
procedure lreadln(handl : word; var s : string);
function lreadc(handl : word):integer;

function lwrite(handl : word; var dest; count : word):word;
procedure lwriteln(handl : word; s : string);
procedure lwritec(handl : word; c : char);

procedure ltruncate(handl : word);
procedure lseek(handl : word; seek_typ : byte; pos : longint);
function ltell(handl : word) : longint;
function lsize(handl : word) : longint;

function leof(handl : word):boolean;
procedure lclose(handl : word);

implementation

var lfnbuf1, lfnbuf2 :string;

function checkDriveExist(disk : byte):boolean;assembler;
asm
        mov        dl, byte ptr [disk]
        inc        dl
        mov        ah, $36
        int        $21
        xor        cl, cl
        cmp        ax, $FFFF
        dec        cl
@nodrive:
        mov        al, cl
end;

function getAllDrives:string;
var r : string;
    i : integer;
    k : integer;
begin
        r := '';
        k := 1;
        for i := ord('A') to ord('Z') do begin
                if checkDriveExist(i - ord('A')) then begin
                        r[k] := chr(i);
                        inc(k);
                end;
        end;
        r[0] := chr(k - 1);
        getAllDrives := r;
end;

procedure file_delete(fname : string);assembler;
asm
        push       ds
        push       ds
        pop        es
        lds        si, fname
        lea        di, lfnbuf1
        cld
        lodsb
        stosb
        push       di
        xor        ah, ah
        xchg       cx, ax
        rep        movsb
        xor        al, al
        stosb
        pop        dx
        pop        ds
        push       ds
        xor        cx, cx
        mov        ax, seg lfnbuf1
        mov        ds, ax
        xor        si, si
        stc
        mov        ax, $7141
        int        $21
        mov        al, 1
        jc         @cont
        dec        al
@cont:
        or         al, al
        jz         @end
        xor        cx, cx
        mov        dx, offset lfnbuf1 + 1
        mov        ax, seg lfnbuf1
        mov        ds, ax
        stc
        mov        ah, $41
        int        $21
@end:
        pop        ds
end;

function file_exists(fname : string):boolean;
var w : word;
begin
        w := lopen_r(fname);
        if w <> 0 then lclose(w);
        file_exists := w <> 0;
end;

procedure file_create(fname : string);
var w : word;
begin
        w := lopen_rw(fname);
        if w <> 0 then lclose(w);
end;

function lopen_r(fname:string):word; assembler;
asm
        push       ds
        push       ds
        pop        es
        lds        si, fname
        lea        di, lfnbuf1
        cld
        lodsb
        stosb
        push       di
        xor        ah, ah
        xchg       cx, ax
        rep        movsb
        xor        al, al
        stosb
        pop        si
        pop        ds
        push       ds
        mov        bx, $22
        xor        cx, cx
        mov        dx, $1
        mov        ax, seg lfnbuf1
        mov        ds, ax
        xor        di, di
        stc
        mov        ax, $716C
        int        $21
        jnc        @end

        mov        dx, offset lfnbuf1 + 1
        mov        ax, seg lfnbuf1
        mov        ds, ax

        mov        ax, $3d00
        int        $21
        jnc        @end
        xor        ax, ax
@end:
        pop        ds
end;

function lopen_w(fname:string):word;assembler;
asm
        push       ds
        push       ds
        pop        es
        lds        si, fname
        lea        di, lfnbuf1
        cld
        lodsb
        stosb
        push       di
        xor        ah, ah
        xchg       cx, ax
        rep        movsb
        xor        al, al
        stosb
        pop        si
        pop        ds
        push       ds
        mov        bx, $22
        xor        cx, cx
        mov        dx, $12
        mov        ax, seg lfnbuf1
        mov        ds, ax
        xor        di, di
        stc
        mov        ax, $716C
        int        $21
        jnc        @end

        mov        dx, offset lfnbuf1 + 1
        mov        ax, seg lfnbuf1
        mov        ds, ax

        mov        ah, $3c
        xor        cx, cx
        int        $21
        jnc        @end
        xor        ax, ax
@end:
        pop        ds
end;

function lopen_rw(fname:string):word;assembler;
asm
        push       ds
        push       ds
        pop        es
        lds        si, fname
        lea        di, lfnbuf1
        cld
        lodsb
        stosb
        push       di
        xor        ah, ah
        xchg       cx, ax
        rep        movsb
        xor        al, al
        stosb
        pop        si
        pop        ds
        push       ds
        mov        bx, $22
        xor        cx, cx
        mov        dx, $11
        mov        ax, seg lfnbuf1
        mov        ds, ax
        xor        di, di
        stc
        mov        ax, $716C
        int        $21
        jnc        @end

        mov        dx, offset lfnbuf1 + 1
        mov        ax, seg lfnbuf1
        mov        ds, ax

        mov        ax, $3d01
        int        $21
        jnc        @end

        mov        dx, offset lfnbuf1 + 1
        mov        ax, seg lfnbuf1
        mov        ds, ax

        mov        ah, $3c
        xor        cx, cx
        int        $21
        jnc        @end
        xor        ax, ax
@end:
        pop        ds
end;

function lread(handl : word; var dest; count : word):word;assembler;
asm
        push       ds
        mov        bx, handl
        mov        cx, count
        lds        dx, dest
        mov        ah, $3F
        int        $21
        jnc        @ok
        xor        ax, ax
@ok:
        pop        ds
end;

function lwrite(handl : word; var dest; count : word):word;assembler;
asm
        push       ds
        mov        bx, handl
        mov        cx, count
        lds        dx, dest
        mov        ah, $40
        int        $21
        jnc        @ok
        xor        ax, ax
@ok:
        pop        ds
end;

procedure ltruncate(handl : word);assembler;
asm
        mov        bx, handl
        xor        cx, cx
        mov        ah, $40
        int        $21
end;

procedure lseek(handl : word; seek_typ : byte; pos : longint);assembler;
asm
        mov        bx, handl
        mov        dx, word ptr [pos]
        mov        cx, word ptr [pos + 2]
        mov        ah, $42
        mov        al, seek_typ
        int        $21
end;

function ltell(handl : word) : longint;assembler;
asm
        mov        bx, handl
        xor        dx, dx
        mov        cx, dx
        mov        ax, $4201
        int        $21
end;

procedure lwriteln(handl : word; s : string);
begin
        lfnbuf1 := s;
        lfnbuf2 := #$0d+#$0a;
        lwrite(handl, lfnbuf1[1], length(lfnbuf1));
        lwrite(handl, lfnbuf2[1], 2);
end;

procedure lwritec(handl : word; c : char);
begin
        lwrite(handl, c, 1);
end;

procedure lreadln(handl : word; var s : string);
var buf : array[0..258] of char;
        count  : word;
        posit  : longint;
        i, j   : integer;
        c      : char;
begin
        posit := ltell(handl);
        count := lread(handl, buf, 258);
        i := 1; j := 0;
        while (i <= 255) and (j < count) do begin
                c := buf[j];
                inc(j);
                if c = #$0A then break;
                if c <> #$0D then begin
                        s[i] := c;
                        inc(i);
                end;
        end;
        s[0] := chr(i - 1);
        lseek(handl, SEEK_BEG, posit + j);
end;

function lsize(handl : word) : longint;
var p1, p2 : longint;
begin
        p1 := ltell(handl);
        lseek(handl, SEEK_END, 0);
        p2 := ltell(handl);
        lseek(handl, SEEK_BEG, p1);
        lsize := p2;
end;

function leof(handl : word):boolean;
var p1, p2 : longint;
begin
        p1 := ltell(handl);
        lseek(handl, SEEK_END, 0);
        p2 := ltell(handl);
        lseek(handl, SEEK_BEG, p1);
        leof := p1 = p2;
end;

procedure lclose(handl : word);assembler;
asm
        mov        bx, handl
        mov        ah, $3e
        int        $21
end;

function lreadc(handl : word):integer;
var i : integer;
    c : char;
begin
        if lread(handl, c, 1) <> 1 then i := -1 else i:= ord(c) and $ff;
        lreadc := i;
end;

function file_size(fname : string):longint;
var r, h : longint;
begin
        h := lopen_r(fname);
        if h <> 0 then begin
                lseek(h, SEEK_END, 0);
                r := ltell(h);
                lclose(h);
        end else r := 0;
        file_size := r;
end;

end.

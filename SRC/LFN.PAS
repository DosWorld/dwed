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
unit lfn;

interface

procedure create(fname : string);
procedure assign(var f : file; fname : string);
procedure assign_text(var t : text; fname : string);
function file_exists(fname : string):boolean;
procedure file_delete(fname : string);

function checkDriveExist(disk : byte):boolean;
function getAllDrives:string;

implementation

var lfnbuf1, lfnbuf2 :string;

function lfn2dos(fname : string) : string;
var
    err : boolean;
    i   : integer;
begin
        lfnbuf1 := fname + #0;
        asm
                push    ds
                push    es
                mov     ax, seg lfnbuf1
                mov     es, ax
                mov     si, offset lfnbuf1 + 1
                mov     di, offset lfnbuf2 + 1
                mov     ax, $7160
                mov     cx, 1
                stc
                int     $21
                pop     es
                pop     ds
                mov     al, 1
                jc      @dos_err
                dec     al
        @dos_err:
                mov     err,al
        end;
        if not err then begin
                fname := '';
                i := 1;
                while lfnbuf2[i] <> #0 do begin
                        fname := fname + lfnbuf2[i];
                        inc(i);
                end;
        end;
        lfn2dos := fname;
end;

procedure file_delete(fname : string);
var err : boolean;
begin
        lfnbuf1 := fname + #0;
        asm
                push       ds
                xor        cx, cx
                mov        dx, offset lfnbuf1 + 1
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
                pop        ds
                mov        err, al
        end;
        if err then begin
                asm
                                push       ds
                                xor        cx, cx
                                mov        dx, offset lfnbuf1 + 1
                                mov        ax, seg lfnbuf1
                                mov        ds, ax
                                stc
                                mov        ah, $41
                                int        $21
                                pop        ds
                end;
        end;
end;

function file_exists(fname : string):boolean;
var f   : file;
    r   : boolean;
    err : boolean;
begin
        lfnbuf1 := fname + #0;
        asm
                push       ds
                mov        bx, $0002
                xor        cx, cx
                mov        dx, $1
                mov        si, offset lfnbuf1 + 1
                mov        ax, seg lfnbuf1
                mov        ds, ax
                xor        di, di
                stc
                mov        ax, $716C
                int        $21
                mov        al, 0
                mov        ah, 1
                jc         @end
                mov        bx, ax
                mov        ah, $3e
                int        $21
                mov        ax, 1
        @end:
                pop        ds
                mov        r, al
                mov        err, ah
        end;


        if err then begin
                r := false;
                System.assign(f, fname);
                reset(f, 1);
                if ioresult = 0 then begin
                        r := true;
                        close(f);
                end;
        end;
        file_exists := r;
end;

procedure create(fname : string);
var f   : file;
    err : boolean;
begin
        lfnbuf1 := fname + #0;
        asm
                push       ds
                mov        bx, $0002
                xor        cx, cx
                mov        dx, $11
                mov        si, offset lfnbuf1 + 1
                mov        ax, seg lfnbuf1
                mov        ds, ax
                xor        di, di
                stc
                mov        ax, $716C
                int        $21
                mov        bx, ax
                mov        al, 1
                jc         @end
                mov        ah, $3e
                int        $21
                xor        al, al
        @end:
                pop        ds
                mov        err, al
        end;
        if err then begin
                System.assign(f, fname);
                rewrite(f, 1);
                close(f);
        end;
end;

procedure assign(var f : file; fname : string);
begin
        System.assign(f, lfn2dos(fname));
end;

procedure assign_text(var t : text; fname : string);
begin
        System.assign(t, lfn2dos(fname));
end;

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
begin
        r := '';
        for i := ord('A') to ord('Z') do begin
                if checkDriveExist(i - ord('A')) then r := r + chr(i);
        end;
        getAllDrives := r;
end;

end.

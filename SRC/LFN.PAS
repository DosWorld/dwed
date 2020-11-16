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

function check : boolean;

procedure create(fname : string);
procedure assign(var f : file; fname : string);
procedure assign_text(var t : text; fname : string);
function file_exists(fname : string):boolean;
procedure file_delete(fname : string);

implementation

function check : boolean;assembler;
asm
        mov     ax, $7100
        stc
        int     $21
end;


var lfnbuf1, lfnbuf2 :string;

function lfn2dos(fname : string) : string;
var
    err : boolean;
    i   : integer;
begin
        if lfn.check then begin
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
                        lfnbuf1 := '';
                        i := 1;
                        while lfnbuf2[i] <> #0 do begin
                                lfnbuf1 := lfnbuf1 + lfnbuf2[i];
                                inc(i);
                        end;
                        fname := lfnbuf1;
                end;
        end;
        lfn2dos := fname;
end;

procedure file_delete(fname : string);
begin
        lfnbuf1 := fname + #0;
        if lfn.check then begin
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
                        pop        ds
                end;
        end else asm
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

function file_exists(fname : string):boolean;
var f : file;
    r : boolean;
begin
        r := false;
        if lfn.check then begin
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
                        jc         @end
                        mov        bx, ax
                        mov        ah, $3e
                        int        $21
                        mov        al, 1
                @end:
                        pop        ds
                        mov        r, al
                end;
        end else begin
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
var f : file;
begin
        if lfn.check then begin
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
                        jc         @end
                        mov        bx, ax
                        mov        ah, $3e
                        int        $21
                @end:
                        pop        ds
                end;
        end else begin
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

end.

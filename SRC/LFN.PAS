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
procedure assign(var f : file; fname : string);
procedure assign_text(var t : text; fname : string);

implementation

function check : boolean;assembler;
asm
        mov     ax, $7100
        stc
        int     $21
        or      al, al
        jz      @nolfn
@nolfn:
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
                        mov     si, offset lfnbuf1
                        mov     di, offset lfnbuf2
                        inc     si
                        inc     di
                        mov     ax, $7160
                        mov     cx, 1
                        stc
                        push    ds
                        pop     es
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

procedure assign(var f : file; fname : string);
begin
        System.assign(f, lfn2dos(fname));
end;

procedure assign_text(var t : text; fname : string);
begin
        System.assign(t, lfn2dos(fname));
end;

end.

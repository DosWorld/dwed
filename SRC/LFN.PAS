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
function lfn2dos(fname : string) : string;

implementation

function check : boolean;assembler;
asm
        mov     ax, $7100
        int     $21
        mov     al, 0
        jc      @nolfn
        dec     al
@nolfn:
end;

function lfn2dos(fname : string) : string;
var spath : string;
        nfname : string;
        err : boolean;
        i : integer;
begin
        if lfn.check then begin
                nfname := fname + #0;
                asm
                        push    ds
                        push    es
                        lea     si, nfname
                        lea     di, spath
                        inc     si
                        inc     di
                        mov     ax, $7160
                        mov     cx, 1
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
                        while spath[i] <> #0 do begin
                                fname := fname + spath[i];
                                inc(i);
                        end;
                end;
        end;
{       writeln(fname);}
        lfn2dos := fname;
end;

end.

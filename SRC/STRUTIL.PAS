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
{G-,S-,R-,I-}
unit strutil;

interface

function basename(s:string):string;
function getpathname(s:string):string;
function change_ext(s:string; new_ext:string):string;
function get_filename_ext(s:string):string;

function strlen(p : pchar):word;
procedure strcpy(dst, src : pchar);
procedure strupr(p : pchar);
function strhash(p : pchar):word;
function strchr(p : pchar; c : char) : pchar;

function upstr(s : string):string;

function hcode(s : string):word;

function hexb(b : byte):string;
function hexw(w : word):string;
function hexdw(dw : longint):string;
function hexp(p : pchar):string;

function binb(b : byte):string;
function bindw(l : longint):string;

function octb(b : byte):string;

function is_digit(c : char):boolean;
function is_hdigit(c : char):boolean;
function is_alpha(c : char):boolean;
function is_id(c : char):boolean;
function is_blank(c : char):boolean;

function ltrim(s : string):string;
function rtrim(s : string):string;
function trim(s : string):string;

function rpad(s : string; len : integer):string;
function lpad(s : string; len : integer):string;

function itoa(i : integer):string;
function wtoa(w : word):string;
function ltoa(l : longint):string;
function atol(s : string; default_val : longint) : longint;
function ahtob(str : string) : byte;

implementation

function get_filename_ext(s : string):string;
var r : string;
        i : integer;
begin
        r := '';
        i := length(s);
        while i <> 0 do begin
                if s[i] = '.' then break;
                dec(i);
        end;
        if i = 0 then r := '' else r := copy(s, i + 1, length(s) - i);
        get_filename_ext := r;
end;

procedure strupr(p:pchar);
begin
        while p[0] <> #0 do begin
                p[0] := upcase(p[0]);
                inc(p);
        end;
end;

function upstr(s:string):string;
var i, l : integer;
begin
        l := length(s);
        for i := 1 to l do s[i] := upcase(s[i]);
        upstr := s;
end;

procedure strcpy(dst, src:pchar);
begin
        while src[0] <> #0 do begin
                src[0] := dst[0];
                inc(src);
                inc(dst);
        end;
        src[0] := #0;
end;

function strlen(p:pchar):word;
var s:pchar;
begin
        s := p;
        while p[0] <> #0 do inc(p);
        strlen := p - s;
end;

function basename(s:string):string;
var r:string;
        i : integer;
begin
        i := length(s);
        for i:=length(s) downto 0 do
        begin
                case s[i] of
                ':','\','/': break;
                end;
        end;
        if i = 0 then r := s else r := copy(s, i+1, length(s) - i);
        basename := r;
end;

function getpathname(s:string):string;
var r:string;
        i : integer;
begin
        i := length(s);
        for i:=length(s) downto 0 do
        begin
                case s[i] of
                ':','\','/': break;
                end;
        end;
        if i = 0 then r := '' else r := copy(s, 1, i);
        getpathname := r;
end;

function change_ext(s:string; new_ext:string):string;
var r : string;
        i, p, l : integer;
begin
        l := length(s);
        p := 0;
        for i := l downto 0 do begin
                case s[i] of
                '.': break;
                '/', '\', ':': begin p:=0; break; end;
                end;
                p := i;
        end;
        if p = 0 then r := s else begin
                r := copy(s, 1, p - 1);
        end;
        change_ext := r + new_ext;
end;

function hcode(s:string):word;
var h : word;
        i, l : integer;
begin
        l := length(s); h := 0;
        for i := 1 to l do h := h * 33 + ord(s[i]);
        hcode := h;
end;

function strhash(p:pchar):word;
var h : word;
begin
        h := 0;
        while p[0] <> #0 do begin h := h * 33 + ord(p[0]); inc(p); end;
        strhash := h;
end;

function hexb(b : byte):string;
const a:string[16] = '0123456789ABCDEF';
begin
        hexb := a[((b shr 4) and $0f) + 1] + a[(b and $0f) + 1];
end;

function hexw(w : word):string;
begin
        hexw := hexb(hi(w)) + hexb(lo(w));
end;

function hexdw(dw : longint):string;
begin
        hexdw := hexw((dw shr 16) and $ffff) + hexw(dw and $ffff);
end;

function hexp(p : pchar):string;
begin
        hexp := hexw(seg(p[0])) + ':' + hexw(ofs(p[0]));
end;

function binb(b:byte):string;
var s : string[8];
        i : integer;
begin
        s[0] := #8;
        for i := 7 downto 0 do if (b and (1 shl i)) <> 0 then s[8-i] := '1' else s[8-i] := '0';
        binb := s;
end;

function bindw(l : longint):string;
begin
        bindw := concat(binb(l shr 24), binb(l shr 16), binb(l shr 8), binb(l));
end;

function octb(b : byte):string;
var s : string[4];
begin
        s := '   ';
        s[3] := chr($30 + (b and 7));
        b := b shr 3;
        s[2] := chr($30 + (b and 7));
        b := b shr 3;
        s[1] := chr($30 + (b and 3));
        octb := s;
end;

function is_blank(c:char):boolean;
begin
        is_blank := c <= ' ';
end;

function is_digit(c:char):boolean;
begin
        is_digit := (c >= '0') and (c <= '9');
end;

function is_alpha(c:char):boolean;
begin
        is_alpha := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z'));
end;

function is_hdigit(c:char):boolean;
begin
        is_hdigit := ((c >= '0') and (c <= '9')) or ((c >= 'a') and (c <= 'f')) or ((c >= 'A') and (c <= 'F'));
end;

function is_id(c:char):boolean;
begin
        is_id := is_alpha(c) or (c = '_');
end;

function ltrim(s:string):string;
var k, l : integer;
begin
        k := 1; l := length(s);
        while k < l do begin
                if s[k] > ' ' then break;
                inc(k);
        end;
        s := copy(s, k, l - k + 1);
        ltrim := s;
end;

function rtrim(s:string):string;
var k, l : integer;
begin
        l := length(s); k := l;
        while k > 0 do begin
                if s[k] > ' ' then break;
                dec(k);
        end;
        if k = 0 then s := '' else if k <> l then s := copy(s, 1, k);
        rtrim := s;
end;

function trim(s:string):string;
begin
        trim := ltrim(rtrim(s));
end;

function rpad(s:string; len:integer):string;
begin
        if length(s) > len then s := copy(s, 1, len)
        else while length(s) < len do s := s + ' ';
        rpad := s;
end;

function lpad(s:string; len:integer):string;
begin
        if length(s) > len then s := copy(s, 1, len)
        else while length(s) < len do s := ' ' + s;
        lpad := s;
end;

function itoa(i:integer):string;
var s : string;
begin
        str(i, s);
        itoa := s;
end;

function wtoa(w:word):string;
var s : string;
begin
        str(w, s);
        wtoa := s;
end;

function ltoa(l:longint):string;
var s : string;
begin
        str(l, s);
        ltoa := s;
end;

function strchr(p : pchar; c : char) : pchar;assembler;
asm
        mov        ah, byte ptr [c]
        mov        si, word ptr [p]
        mov        bx, word ptr [p+2]
        push       ds
        mov        ds, bx
        cld
@cont:
        lodsb
        or         al, al
        jz         @end
        cmp        al, ah
        jnz        @cont
@end:
        mov        ax, si
        mov        dx, ds
        pop        ds
end;

function atol(s:string; default_val : longint) : longint;
var res : longint; err_pos : integer;
begin
     val(s, res, err_pos);
     if err_pos <> 0 then res := default_val;
     atol := res;
end;

function ahtob(str : string) : byte;
var r : byte;
        i        : integer;
        c        : char;
        k        : byte;
begin
        r := 0;
        if length(str) = 1 then str := '0' + str;
        str := upstr(str);
        if length(str) > 2 then str := copy(str, 1, 2);
        for i := 1 to 2 do begin
                c := str[i];
                k := 0;
                if c in ['0'..'9'] then k := ord(c) - ord('0')
                else if c in ['A'..'F'] then k := ord(c) - ord('A') + 10;
                r := (r shl 4) or (k and $0F);
        end;
        ahtob := r;
end;

end.

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
{$F-,R-}
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

procedure upstr(var s : string);

function hcode(var s : string):word;

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

function starts_with(var s : string; start : string):boolean;

function rpad(s : string; len : integer):string;
function lpad(s : string; len : integer):string;

function itoa(i : integer):string;
function wtoa(w : word):string;
function ltoa(l : longint):string;
function atoi(s : string; default_val : integer) : integer;
function atol(s : string; default_val : longint) : longint;
function ahtob(str : string) : byte;

function unquote(str : string) : string;

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

procedure strupr(p : pchar);assembler;
asm
        push       ds
        push       es

        lds        si, p
        push       ds
        pop        es
        cld
        mov        di, si
@cont:
        lodsb
        cmp        al, 'a'
        jl         @noconv
        cmp        al, 'z'
        jg         @noconv
        sub        al, $20
@noconv:
        stosb
        or         al, al
        jnz        @cont
@end:
        pop        es
        pop        ds
end;

procedure upstr(var s : string);assembler;
asm
        push       ds
        push       es

        lds        si, s
        push       ds
        pop        es
        cld
        lodsb
        mov        cl, al
        or         cl, cl
        jz         @end
        mov        di, si
@cont:
        lodsb
        cmp        al, 'a'
        jl         @noconv
        cmp        al, 'z'
        jg         @noconv
        sub        al, $20
@noconv:
        stosb
        dec        cl
        jnz        @cont
@end:
        pop        es
        pop        ds
end;

procedure strcpy(dst, src:pchar);assembler;
asm
        push       ds
        push       es
        lds        si, src
        les        di, dst
        cld
@cont:
        lodsb
        stosb
        or         al, al
        jnz        @cont
        pop        es
        pop        ds
end;

function strlen(p : pchar):word;assembler;
asm
        push       ds
        lds        si, p
        xor        bx, bx
        cld
@cont:
        lodsb
        or         al, al
        jnz        @end
        inc        bx
        jmp        @cont
@end:
        mov        ax, bx
        pop        ds
end;

function basename(s : string):string;
var i : integer;
begin
        for i := length(s) downto 0 do
        begin
                if s[i] in [':','\','/'] then break;
        end;
        if i <> 0 then s := copy(s, i+1, length(s) - i);
        basename := s;
end;

function getpathname(s : string):string;
var i : integer;
begin
        for i := length(s) downto 0 do
        begin
                if s[i] in [':','\','/'] then break;
        end;
        if i <> 0 then s := copy(s, 1, i);
        getpathname := s;
end;

function change_ext(s : string; new_ext : string):string;
var     i : integer;
begin
        i := length(s);
        while i > 0 do begin
                case s[i] of
                '.': begin s[0] := chr(i - 1); break; end;
                '/', '\', ':': break;
                end;
                dec(i);
        end;
        change_ext := s + new_ext;
end;

function hcode(var s : string):word;assembler;
asm
        push       ds
        lds        si, s
        cld
        xor        bx, bx
        lodsb
        or         al, al
        jz         @end
        mov        cl, al
@cont:
        mov        ax, 33
        mul        bx
        xchg       bx, ax
        lodsb
        add        bx, ax
        dec        cl
        jnz        @cont
@end:
        mov        ax, bx
        pop        ds
end;

function strhash(p : pchar):word;
var h : word;
begin
        h := 0;
        while p[0] <> #0 do begin h := h * 33 + ord(p[0]); inc(p); end;
        strhash := h;
end;

function hexb(b : byte):string;
const a : string[16] = '0123456789ABCDEF';
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

function binb(b : byte):string;
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

function is_blank(c : char) : boolean;assembler;
asm
        xor        al, al
        mov        ah, c
        cmp        ah, ' '
        jg         @end
        dec        al
@end:
end;

function is_digit(c : char):boolean;assembler;
asm
        xor        al, al
        mov        ah, c
        cmp        ah, '0'
        jl         @cont1
        cmp        ah, '9'
        jg         @cont1
        dec        al
@cont1:
end;

function is_alpha(c : char):boolean;assembler;
asm
        xor        al, al
        mov        ah, c
        cmp        ah, 'a'
        jl         @cont1
        cmp        ah, 'z'
        jg         @cont1
        dec        al
        jmp        @end
@cont1:
        cmp        ah, 'A'
        jl         @cont2
        cmp        ah, 'Z'
        jg         @cont2
        dec        al
@cont2:
@end:
end;

function is_hdigit(c : char):boolean;assembler;
asm
        xor        al, al
        mov        ah, c
        cmp        ah, 'a'
        jl         @cont1
        cmp        ah, 'f'
        jg         @cont1
        dec        al
        jmp        @end
@cont1:
        cmp        ah, 'A'
        jl         @cont2
        cmp        ah, 'f'
        jg         @cont2
        dec        al
        jmp        @end
@cont2:
        cmp        ah, '0'
        jl         @end
        cmp        ah, '9'
        jg         @end
        dec        al
@end:
end;

function is_id(c : char):boolean;assembler;
asm
        xor        al, al
        mov        ah, c
        cmp        ah, 'a'
        jl         @cont1
        cmp        ah, 'z'
        jg         @cont1
        dec        al
        jmp        @end
@cont1:
        cmp        ah, 'A'
        jl         @cont2
        cmp        ah, 'Z'
        jg         @cont2
        dec        al
        jmp        @end
@cont2:
        cmp        ah, '0'
        jl         @cont3
        cmp        ah, '9'
        jg         @cont3
        dec        al
        jmp        @end
@cont3: cmp        ah, '_'
        jnz        @end
        dec        al
@end:
end;

function ltrim(s : string):string;
var k, l : integer;
begin
        k := 1; l := length(s);
        while k < l do begin
                if s[k] > ' ' then break;
                inc(k);
        end;
        if k <> 1 then s := copy(s, k, l - k + 1);
        ltrim := s;
end;

function rtrim(s : string):string;
var k, l : integer;
begin
        l := length(s); k := l;
        while k > 0 do begin
                if s[k] > ' ' then break;
                dec(k);
        end;
        if k = 0 then s := '' else if k <> l then s[0] := chr(k);
        rtrim := s;
end;

function trim(s : string):string;
begin
        trim := ltrim(rtrim(s));
end;

function rpad(s : string; len : integer):string;
begin
        if length(s) > len then s := copy(s, 1, len)
        else while length(s) < len do s := s + ' ';
        rpad := s;
end;

function lpad(s : string; len : integer):string;
begin
        if length(s) > len then s := copy(s, 1, len)
        else while length(s) < len do s := ' ' + s;
        lpad := s;
end;

function itoa(i : integer):string;
var s : string;
begin
        str(i, s);
        itoa := s;
end;

function wtoa(w : word):string;
var s : string;
begin
        str(w, s);
        wtoa := s;
end;

function ltoa(l : longint):string;
var s : string;
begin
        str(l, s);
        ltoa := s;
end;

function strchr(p : pchar; c : char) : pchar;assembler;
asm
        push       ds
        mov        ah, c
        lds        si, p
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

function atol(s : string; default_val : longint) : longint;
var res : longint; err_pos : integer;
begin
     val(s, res, err_pos);
     if err_pos <> 0 then res := default_val;
     atol := res;
end;

function atoi(s : string; default_val : integer) : integer;
var res : integer; err_pos : integer;
begin
     val(s, res, err_pos);
     if err_pos <> 0 then res := default_val;
     atoi := res;
end;

function ahtob(str : string) : byte;
var r  : byte;
    i  : integer;
    c  : char;
    k  : byte;
begin
        r := 0;
        if length(str) = 1 then str := '0' + str;
        upstr(str);
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

function starts_with(var s : string; start : string):boolean;
var n : string;
begin
        n := s;
        if s[0] >= start[0] then begin
                n := s; n[0] := start[0];
                starts_with := n = start;
        end else starts_with := false;
end;

function unquote(str : string) : string;
begin
        if length(str) > 0 then begin
                if (str[1] = '"') and (str[length(str)] = '"') then begin
                        str := copy(str, 2, length(str) - 2);
                end;
        end;
        unquote := str;
end;

end.
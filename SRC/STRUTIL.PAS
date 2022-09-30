{ MIT License

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
SOFTWARE. }
{$F-,R-}
unit strutil;

interface

function hexb(b : byte):string;
function hexw(w : word):string;
function hexdw(dw : longint):string;
function hexp(p : pchar):string;

function binb(b : byte):string;
function bindw(l : longint):string;

function octb(b : byte):string;

function unquote(str : string) : string;

procedure remove_tabs(var s : string; var tabs : string);

implementation

uses str;

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

function unquote(str : string) : string;
begin
        if length(str) > 0 then begin
                if (str[1] = '"') and (str[length(str)] = '"') then begin
                        str := copy(str, 2, length(str) - 2);
                end;
        end;
        unquote := str;
end;

procedure remove_tabs(var s : string; var tabs : string);
var     i : integer;
        r : string;
begin
        if poschr(s, #9) = -1 then exit;
        i := 1;
        r := '';
        while (i <= ord(s[0])) and (ord(r[0]) < 255) do begin
                if s[i] = #9 then begin
                        r := r + tabs;
                end else begin
                        r[ord(r[0]) + 1] := s[i];
                        inc(r[0]);
                end;
                inc(i);
        end;
        s := r;
end;

end.

{ MIT License

Copyright (c) 2022 Viacheslav Komenda

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
{$A-,F-}
unit dwedlnch;

interface

const
EXEC_USER_CMD = 254;
MAX_TAIL = 126;

function is_installed : boolean;
function get_temp_name : string;
function short_path(s : string) : string;
function short_dir(dir : string) : string;
function set_exec_cmd(cmd, batname : string) : boolean;

implementation

uses dwedtype, system2;

var     parent : pchar;
        ppsp   : word;

function is_installed : boolean;
begin
        is_installed := PString(parent)^ = 'DWED';
end;

function get_temp_name : string;
begin
        get_temp_name := PString(parent + 5)^;
end;

function short_path(s : string) : string;
var     src, dst : array[0..263] of char;
        ok       : boolean;
        n        : integer;
        res      : string;
begin
        short_path := s;
        if (length(s) = 0) or (length(s) > 255) then exit;
        move(s[1], src, length(s));
        src[length(s)] := #0;
        dst[0] := #0;
        ok := false;
        asm
                push ds
                mov  ax, ss
                mov  ds, ax
                lea  si, src
                push ss
                pop  es
                lea  di, dst
                mov  cx, 1
                mov  ax, $7160
                stc
                int  $21
                pop  ds
                jc   @e
                mov  ok, 1
        @e:
        end;
        if ok and (dst[0] <> #0) then begin
                n := 0;
                while (n < 255) and (dst[n] <> #0) do inc(n);
                if n < 255 then begin
                        move(dst, res[1], n);
                        res[0] := chr(n);
                        short_path := res;
                end;
        end;
end;

function short_dir(dir : string) : string;
var     d : string;
begin
        d := dir;
        if (length(d) = 2) and (d[2] = ':') then begin
                short_dir := d;
                exit;
        end;
        if (length(d) > 3) and (d[length(d)] in ['\', '/']) then dec(d[0]);
        d := short_path(d);
        if (length(d) > 1) and (d[length(d)] = '\') and (d[length(d) - 1] = '\') then dec(d[0]);
        if (length(d) <> 0) and (not (d[length(d)] in ['\', '/'])) then d := d + '\';
        short_dir := d;
end;

function set_exec_cmd(cmd, batname : string) : boolean;
var     s, t : string;
        f    : bfile;
        i    : integer;
begin
        set_exec_cmd := false;
        s := ' /C ' + cmd;
        (parent + 530)^ := #0;
        if length(s) > MAX_TAIL then begin
                if (pos(' ', batname) <> 0) or (length(batname) > 128) then exit;
                assign(f, batname);
                rewrite(f);
                if not isopen(f) then exit;
                writeln(f, '@echo off');
                t := '';
                i := 1;
                while i <= length(cmd) do begin
                        if length(t) > 200 then begin
                                write(f, t);
                                t := '';
                        end;
                        if (cmd[i] = '%') and (i < length(cmd)) and (cmd[i + 1] in ['0'..'9', '*', '~']) then t := t + '%%'
                        else if (cmd[i] = '%') and (i < length(cmd)) and (cmd[i + 1] = '%') then begin
                                t := t + '%%%%';
                                inc(i);
                        end else t := t + cmd[i];
                        inc(i);
                end;
                writeln(f, t);
                close(f);
                if f.ioresult <> 0 then begin
                        FileDelete(batname);
                        exit;
                end;
                s := ' /C ' + batname;
                if length(s) > MAX_TAIL then begin
                        FileDelete(batname);
                        exit;
                end;
                move(batname[1], (parent + 530)^, length(batname));
                (parent + 530 + length(batname))^ := #0;
        end;
        t := copy(cmd, 1, 250);
        PString(parent + 274)^ := t;
        (parent + 275 + length(t))^ := #0;
        PString(parent + 18)^ := s;
        (parent + 19 + length(s))^ := #13;
        (parent + 20 + length(s))^ := #0;
        set_exec_cmd := true;
end;

begin
        ppsp := PWord(ptr(PrefixSeg, $16))^;
        parent := ptr(ppsp, PWord(ptr(ppsp, 5))^);
end.

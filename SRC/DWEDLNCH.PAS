{
 MIT License

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
SOFTWARE.
}
unit dwedlnch;

interface

const

EXEC_USER_CMD = 254;

function is_installed : boolean;
function get_temp_name : string;
procedure set_exec_cmd(cmd : string);

implementation

uses dos, strutil, system2;

Type
PString = ^String;
PWord = ^Word;

Var     parent : pchar;
        ppsp   : word;

function is_installed : boolean;
begin
        is_installed := PString(parent)^ = 'DWED';
end;

function get_temp_name : string;
begin
        get_temp_name := PString(parent + 5)^;
end;

procedure set_exec_cmd(cmd : string);
begin
        PString(parent + 18)^ := ' /C ' + cmd + #0;
end;

begin
        ppsp := PWord(ptr(PrefixSeg, $16))^;
        parent := ptr(ppsp, PWord(ptr(ppsp, 5))^);
end.

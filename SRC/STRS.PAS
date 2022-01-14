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
{$I-}
unit strs;

interface

type

MemoryType = (DOS, EMS, XMS);

EditorStr = pointer;

procedure init(mType : MemoryType);

function new : EditorStr;

function from_file(fname : string; tab_size : integer; var errCode : integer; scrupdate : pointer) : EditorStr;
procedure to_file(fname : string; r : EditorStr; var errCode : integer; scrupdate : pointer);

function create(next, prev : EditorStr; var body : string) : EditorStr;
procedure free(r : EditorStr);

function put(r : EditorStr; var body : string) : EditorStr;
procedure get(r : EditorStr; var dest : string);
function delete(r : EditorStr; num_from, num_to : longint) : EditorStr;
function merge(r : EditorStr) : EditorStr;

function is_first(r : EditorStr) : boolean;
function is_last(r : EditorStr) : boolean;

function go_first(r : EditorStr) : EditorStr;
function go_last(r : EditorStr) : EditorStr;

function go_prev(r : EditorStr) : EditorStr;
function go_next(r : EditorStr) : EditorStr;

function renum(r : EditorStr) : longint;
function get_num(r : EditorStr) : longint;
function find_num(r : EditorStr; num : longint) : EditorStr;

function append(r : EditorStr; var pos : integer; p : pchar; var lnum:word) : EditorStr;
function split(r : EditorStr; pos : integer) : EditorStr;

function is_nil(r : EditorStr) : boolean;

implementation

uses strsd, dwedtype, system2;

const memType : MemoryType = DOS;
const BUF_SIZE = 4 * 1024;

procedure init(mType : MemoryType);
begin
        memType := mType;
end;

function put(r : EditorStr; var body : string) : EditorStr;
begin
        put := strsd.put(r, body);
end;

function create(next, prev : EditorStr; var body : string) : EditorStr;
begin
        create := strsd.create(next, prev, body);
end;

procedure remove_tabs(var s : string; var tabs : string);
var     i : integer;
        r : string;
begin
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

function from_file(fname : string; tab_size : integer; var errCode : integer; scrupdate : pointer) : EditorStr;
var     root, cur, last : Pointer;
        f          : bfile;
        s          : string;
        i          : integer;
        total      : longint;
        position   : longint;
        percent    : integer;
        ppercent   : integer;
        scrup      : TPercentUpdateProc;
        tabs       : string;
begin
        scrup := TPercentUpdateProc(scrupdate);
        fillchar(tabs[0], 256, #32);
        tabs[0] := chr(tab_size);
        ppercent := -1;
        root := nil; last := nil;
        errCode := 0;
        if not FileExists(fname) then begin
                errCode := 104;
        end;
        if errCode = 0 then begin
                assign(f, fname);
                reset(f);
                if not IsOpen(f) then errCode := 104;
        end;
        position := 0;
        if errCode = 0 then begin
                total := filesize(f);
                if total <> 0 then begin
                        while not eof(f) do begin
                                readln(f, s);
                                remove_tabs(s, tabs);
                                cur := strs.create(nil, last, s);
                                if root = nil then root := cur;
                                last := cur;
                                position := filepos(f);
                                if scrupdate <> nil then begin
                                        percent := (position * 100) div total;
                                        if percent <> ppercent then begin
                                                scrup(position, total);
                                                ppercent := percent;
                                        end;
                                end;
                        end;
                end else begin
                        root := strs.new;
                end;
                close(f);
        end;
        if root = nil then root := strs.new;
        from_file := root;
end;

procedure to_file(fname : string; r : EditorStr; var errCode : integer; scrupdate : pointer);
var
        f       : bfile;
        buf     : array[0..BUF_SIZE-1] of char;
        inbuf   : word;
        len     : word;
        s       : string;
        total      : longint;
        position   : longint;
        percent    : integer;
        ppercent   : integer;
        scrup      : TPercentUpdateProc;
begin
        assign(f, fname);
        rewrite(f);
        if not isopen(f) then errCode := 105 else errCode := 0;
        if errCode <> 0 then exit;
        inbuf := 0;
        scrup := TPercentUpdateProc(scrupdate);
        total := renum(r);
        position := 0;
        ppercent := -1;
        while r <> nil do begin
                strs.get(r, s);
                len := length(s);
                if (len + 2) >= (BUF_SIZE - inbuf) then begin
                        blockwrite(f, buf[0], inbuf);
                        inbuf := 0;
                end;
                move(s[1], buf[inbuf], len);
                inc(inbuf, len);
                if not strs.is_last(r) then begin
                        buf[inbuf] := #$0d;
                        inc(inbuf, 1);
                        buf[inbuf] := #$0a;
                        inc(inbuf, 1);
                end;
                r := strs.go_next(r);
                if scrupdate <> nil then begin
                        inc(position);
                        percent := (position * 100) div total;
                        if percent <> ppercent then begin
                                scrup(position, total);
                                ppercent := percent;
                        end;
                end;
        end;
        if inbuf <> 0 then blockwrite(f, buf[0], inbuf);
        truncate(f);
        close(f);
end;

function new : EditorStr;
begin
        new := strsd.new;
end;

procedure get(r : EditorStr; var dest : string);
begin
        strsd.get(r, dest);
end;

function is_first(r : EditorStr) : boolean;
begin
        is_first := strsd.is_first(r);
end;

function is_last(r : EditorStr) : boolean;
begin
        is_last := strsd.is_last(r);
end;

function go_first(r : EditorStr) : EditorStr;
begin
        go_first := strsd.go_first(r);
end;

function go_last(r : EditorStr) : EditorStr;
begin
        go_last := strsd.go_last(r);
end;

function go_prev(r : EditorStr) : EditorStr;
begin
        go_prev := strsd.go_prev(r);
end;

function go_next(r : EditorStr) : EditorStr;
begin
        go_next := strsd.go_next(r);
end;

procedure free(r : EditorStr);
begin
        strsd.free(r);
end;

function renum(r : EditorStr) : longint;
begin
        renum := strsd.renum(r);
end;

function get_num(r : EditorStr) : longint;
begin
        get_num := strsd.get_num(r);
end;

function find_num(r : EditorStr; num : longint) : EditorStr;
begin
        while r <> nil do begin
                if num = strs.get_num(r) then break;
                r := strs.go_next(r);
        end;
        find_num := r;
end;

function delete(r : EditorStr; num_from, num_to : longint) : EditorStr;
begin
        delete := strsd.delete(r, num_from, num_to);
end;

function merge(r : EditorStr) : EditorStr;
begin
        merge := strsd.merge(r);
end;

function append(r : EditorStr; var pos : integer; p : pchar; var lnum:word) : EditorStr;
begin
        append := strsd.append(r, pos, p, lnum);
end;

function split(r : EditorStr; pos : integer) : EditorStr;
begin
        split := strsd.split(r, pos);
end;

function is_nil(r : EditorStr) : boolean;
begin
        is_nil := r = nil;
end;

end.
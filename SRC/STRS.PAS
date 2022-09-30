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
{$I-}
unit strs;

{ proxy for string storage calls }

interface

type
MemoryType = (MT_DOS, MT_TEMP);
EditorStr = pointer;

procedure init(mType : MemoryType);
procedure done;

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

uses strsdos, strsext, dwedtype, system2, str, strutil;

const
memType : MemoryType = MT_DOS;

procedure init(mType : MemoryType);
begin
        memType := mType;
        if mType = MT_TEMP then strsext.init else strsdos.init;
end;

procedure done;
begin
        if memType = MT_TEMP then strsext.done else strsdos.done;
end;

function put(r : EditorStr; var body : string) : EditorStr;
begin
        if memType = MT_TEMP then put := EditorStr(strsext.put(dword(r), body))
        else put := EditorStr(strsdos.put(pointer(r), body));
end;

function create(next, prev : EditorStr; var body : string) : EditorStr;
begin
        if memType = MT_TEMP then create := EditorStr(strsext.create(dword(next), dword(prev), body))
        else create := EditorStr(strsdos.create(pointer(next), pointer(prev), body));
end;

function from_file(fname : string; tab_size : integer; var errCode : integer; scrupdate : pointer) : EditorStr;
begin
        errCode := 0;
        if not FileExists(fname) then begin
                errCode := 104;
                from_file := EditorStr(strs.new);
        end else if memType = MT_TEMP then
                from_file := EditorStr(strsext.from_file(fname, tab_size, errCode, scrupdate))
        else
                from_file := EditorStr(strsdos.from_file(fname, tab_size, errCode, scrupdate));
end;

procedure to_file(fname : string; r : EditorStr; var errCode : integer; scrupdate : pointer);
var     f        : bfile;
        fnamebak : string;
begin
        errCode := 0;
        if FileExists(fname) then begin
                fnamebak := change_ext(fname, '.bak');
                if FileExists(fnamebak) then FileDelete(fnamebak);
                assign(f, fname);
                rename(f, fnamebak);
        end;

        if memType = MT_TEMP then
                strsext.to_file(fname, dword(r), errCode, scrupdate)
        else
                strsdos.to_file(fname, pointer(r), errCode, scrupdate);
end;

function new : EditorStr;
begin
        if memType = MT_TEMP then new := EditorStr(strsext.new)
        else new := EditorStr(strsdos.new);
end;

procedure get(r : EditorStr; var dest : string);
begin
        if memType = MT_TEMP then strsext.get(dword(r), dest)
        else strsdos.get(pointer(r), dest);
end;

function is_first(r : EditorStr) : boolean;
begin
        if memType = MT_TEMP then is_first := strsext.is_first(dword(r))
        else is_first := strsdos.is_first(pointer(r));
end;

function is_last(r : EditorStr) : boolean;
begin
        if memType = MT_TEMP then is_last := strsext.is_last(dword(r))
        else is_last := strsdos.is_last(pointer(r));
end;

function go_first(r : EditorStr) : EditorStr;
begin
        if memType = MT_TEMP then go_first := EditorStr(strsext.go_first(dword(r)))
        else go_first := EditorStr(strsdos.go_first(pointer(r)));
end;

function go_last(r : EditorStr) : EditorStr;
begin
        if memType = MT_TEMP then go_last := EditorStr(strsext.go_last(dword(r)))
        else go_last := EditorStr(strsdos.go_last(pointer(r)));
end;

function go_prev(r : EditorStr) : EditorStr;
begin
        if memType = MT_TEMP then go_prev := EditorStr(strsext.go_prev(dword(r)))
        else go_prev := EditorStr(strsdos.go_prev(pointer(r)));
end;

function go_next(r : EditorStr) : EditorStr;
begin
        if memType = MT_TEMP then go_next := EditorStr(strsext.go_next(dword(r)))
        else go_next := EditorStr(strsdos.go_next(pointer(r)));
end;

procedure free(r : EditorStr);
begin
        if memType = MT_TEMP then strsext.free(dword(r))
        else strsdos.free(pointer(r));
end;

function renum(r : EditorStr) : dword;
begin
        if memType = MT_TEMP then renum := strsext.renum(dword(r))
        else renum := strsdos.renum(pointer(r));
end;

function get_num(r : EditorStr) : dword;
begin
        if memType = MT_TEMP then get_num := strsext.get_num(dword(r))
        else get_num := strsdos.get_num(pointer(r));
end;

function find_num(r : EditorStr; num : dword) : EditorStr;
begin
        while not is_nil(r) do begin
                if num = strs.get_num(r) then break;
                r := strs.go_next(r);
        end;
        find_num := r;
end;

function delete(r : EditorStr; num_from, num_to : dword) : EditorStr;
begin
        if memType = MT_TEMP then delete := EditorStr(strsext.delete(dword(r), num_from, num_to))
        else delete := EditorStr(strsdos.delete(pointer(r), num_from, num_to));
end;

function merge(r : EditorStr) : EditorStr;
begin
        if memType = MT_TEMP then merge := EditorStr(strsext.merge(dword(r)))
        else merge := EditorStr(strsdos.merge(pointer(r)));
end;

function append(r : EditorStr; var pos : integer; p : pchar; var lnum:word) : EditorStr;
begin
        if memType = MT_TEMP then append := EditorStr(strsext.append(dword(r), pos, p, lnum))
        else append := EditorStr(strsdos.append(pointer(r), pos, p, lnum));
end;

function split(r : EditorStr; pos : integer) : EditorStr;
begin
        if memType = MT_TEMP then split := EditorStr(strsext.split(dword(r), pos))
        else split := strsdos.split(pointer(r), pos);
end;

function is_nil(r : EditorStr) : boolean;
begin
        if memType = MT_TEMP then is_nil := strsext.is_nil(dword(r))
        else is_nil := strsdos.is_nil(pointer(r));
end;

end.

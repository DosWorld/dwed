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
MemoryType = (MT_DOS, MT_SWAP, MT_SXMS);
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

uses system2, scr, strsdos, strssxms, strsswap, dwedtype, str, strutil;

const
memType : MemoryType = MT_DOS;

procedure init(mType : MemoryType);
begin
        memType := mType;
        if mType = MT_SXMS then strssxms.init
        else if mType = MT_SWAP then strsswap.init
        else strsdos.init;
end;

procedure done;
begin
        if memType = MT_SXMS then strssxms.done
        else if memType = MT_SWAP then strsswap.done
        else strsdos.done;
end;

function put(r : EditorStr; var body : string) : EditorStr;
begin
        if memType = MT_SXMS then put := EditorStr(strssxms.put(dword(r), body))
        else if memType = MT_SWAP then put := EditorStr(strsswap.put(dword(r), body))
        else put := EditorStr(strsdos.put(pointer(r), body));
end;

function create(next, prev : EditorStr; var body : string) : EditorStr;
begin
        if memType = MT_SXMS then create := EditorStr(strssxms.create(dword(next), dword(prev), body))
        else if memType = MT_SWAP then create := EditorStr(strsswap.create(dword(next), dword(prev), body))
        else create := EditorStr(strsdos.create(pointer(next), pointer(prev), body));
end;

function from_file(fname : string; tab_size : integer; var errCode : integer; scrupdate : pointer) : EditorStr;
begin
        spinner_start;
        errCode := 0;
        if not FileExists(fname) then begin
                errCode := 104;
                from_file := EditorStr(strs.new);
        end else if memType = MT_SXMS then
                from_file := EditorStr(strssxms.from_file(fname, tab_size, errCode, scrupdate))
        else if memType = MT_SWAP then
                from_file := EditorStr(strsswap.from_file(fname, tab_size, errCode, scrupdate))
        else
                from_file := EditorStr(strsdos.from_file(fname, tab_size, errCode, scrupdate));
        spinner_stop;
end;

procedure to_file(fname : string; r : EditorStr; var errCode : integer; scrupdate : pointer);
var     f        : bfile;
        fnamebak : string;
begin
        spinner_start;
        errCode := 0;
        if FileExists(fname) then begin
                fnamebak := change_ext(fname, '.bak');
                if FileExists(fnamebak) then FileDelete(fnamebak);
                assign(f, fname);
                rename(f, fnamebak);
        end;

        if memType = MT_SXMS then
                strssxms.to_file(fname, dword(r), errCode, scrupdate)
        else if memType = MT_SWAP then
                strsswap.to_file(fname, dword(r), errCode, scrupdate)
        else
                strsdos.to_file(fname, pointer(r), errCode, scrupdate);
        spinner_stop;
end;

function new : EditorStr;
begin
        if memType = MT_SXMS then new := EditorStr(strssxms.new)
        else if memType = MT_SWAP then new := EditorStr(strsswap.new)
        else new := EditorStr(strsdos.new);
end;

procedure get(r : EditorStr; var dest : string);
begin
        if memType = MT_SXMS then strssxms.get(dword(r), dest)
        else if memType = MT_SWAP then strsswap.get(dword(r), dest)
        else strsdos.get(pointer(r), dest);
end;

function is_first(r : EditorStr) : boolean;
begin
        if memType = MT_SXMS then is_first := strssxms.is_first(dword(r))
        else if memType = MT_SWAP then is_first := strsswap.is_first(dword(r))
        else is_first := strsdos.is_first(pointer(r));
end;

function is_last(r : EditorStr) : boolean;
begin
        if memType = MT_SXMS then is_last := strssxms.is_last(dword(r))
        else if memType = MT_SWAP then is_last := strsswap.is_last(dword(r))
        else is_last := strsdos.is_last(pointer(r));
end;

function go_first(r : EditorStr) : EditorStr;
begin
        if memType = MT_SXMS then go_first := EditorStr(strssxms.go_first(dword(r)))
        else if memType = MT_SWAP then go_first := EditorStr(strsswap.go_first(dword(r)))
        else go_first := EditorStr(strsdos.go_first(pointer(r)));
end;

function go_last(r : EditorStr) : EditorStr;
begin
        if memType = MT_SXMS then go_last := EditorStr(strssxms.go_last(dword(r)))
        else if memType = MT_SWAP then go_last := EditorStr(strsswap.go_last(dword(r)))
        else go_last := EditorStr(strsdos.go_last(pointer(r)));
end;

function go_prev(r : EditorStr) : EditorStr;
begin
        if memType = MT_SXMS then go_prev := EditorStr(strssxms.go_prev(dword(r)))
        else if memType = MT_SWAP then go_prev := EditorStr(strsswap.go_prev(dword(r)))
        else go_prev := EditorStr(strsdos.go_prev(pointer(r)));
end;

function go_next(r : EditorStr) : EditorStr;
begin
        if memType = MT_SXMS then go_next := EditorStr(strssxms.go_next(dword(r)))
        else if memType = MT_SWAP then go_next := EditorStr(strsswap.go_next(dword(r)))
        else go_next := EditorStr(strsdos.go_next(pointer(r)));
end;

procedure free(r : EditorStr);
begin
        if memType = MT_SXMS then strssxms.free(dword(r))
        else if memType = MT_SWAP then strsswap.free(dword(r))
        else strsdos.free(pointer(r));
end;

function renum(r : EditorStr) : dword;
begin
        spinner_start;
        if memType = MT_SXMS then renum := strssxms.renum(dword(r))
        else if memType = MT_SWAP then renum := strsswap.renum(dword(r))
        else renum := strsdos.renum(pointer(r));
        spinner_stop;
end;

function get_num(r : EditorStr) : dword;
begin
        if memType = MT_SXMS then get_num := strssxms.get_num(dword(r))
        else if memType = MT_SWAP then get_num := strsswap.get_num(dword(r))
        else get_num := strsdos.get_num(pointer(r));
end;

function find_num(r : EditorStr; num : dword) : EditorStr;
begin
        spinner_start;
        while not is_nil(r) do begin
                if num = strs.get_num(r) then break;
                r := strs.go_next(r);
        end;
        spinner_stop;
        find_num := r;
end;

function delete(r : EditorStr; num_from, num_to : dword) : EditorStr;
begin
        spinner_start;
        if memType = MT_SXMS then delete := EditorStr(strssxms.delete(dword(r), num_from, num_to))
        else if memType = MT_SWAP then delete := EditorStr(strsswap.delete(dword(r), num_from, num_to))
        else delete := EditorStr(strsdos.delete(pointer(r), num_from, num_to));
        spinner_stop;
end;

function merge(r : EditorStr) : EditorStr;
begin
        if memType = MT_SXMS then merge := EditorStr(strssxms.merge(dword(r)))
        else if memType = MT_SWAP then merge := EditorStr(strsswap.merge(dword(r)))
        else merge := EditorStr(strsdos.merge(pointer(r)));
end;

function append(r : EditorStr; var pos : integer; p : pchar; var lnum:word) : EditorStr;
begin
        spinner_start;
        if memType = MT_SXMS then append := EditorStr(strssxms.append(dword(r), pos, p, lnum))
        else if memType = MT_SWAP then append := EditorStr(strsswap.append(dword(r), pos, p, lnum))
        else append := EditorStr(strsdos.append(pointer(r), pos, p, lnum));
        spinner_stop;
end;

function split(r : EditorStr; pos : integer) : EditorStr;
begin
        if memType = MT_SXMS then split := EditorStr(strssxms.split(dword(r), pos))
        else if memType = MT_SWAP then split := EditorStr(strsswap.split(dword(r), pos))
        else split := strsdos.split(pointer(r), pos);
end;

function is_nil(r : EditorStr) : boolean;
begin
        if memType = MT_SXMS then is_nil := strssxms.is_nil(dword(r))
        else if memType = MT_SWAP then is_nil := strsswap.is_nil(dword(r))
        else is_nil := strsdos.is_nil(pointer(r));
end;

end.

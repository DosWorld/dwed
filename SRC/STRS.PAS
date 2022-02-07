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
{$I-}
unit strs;

{ proxy for string storage calls }

interface

type

MemoryType = (MT_DOS, MT_TEMP_WO_CACHE, MT_TEMP_WITH_CACHE, MT_BIGMEM);

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

uses strsd, strsb, dwedtype, system2, strutil;

const memType : MemoryType = MT_DOS;
const BUF_SIZE = 4 * 1024;

procedure init(mType : MemoryType);
begin
        memType := mType;
        if mType <> MT_DOS THEN strsb.init(mType);
end;

function put(r : EditorStr; var body : string) : EditorStr;
begin
        if memType = MT_DOS then put := strsd.put(r, body)
        else put := strsb.put(r, body);
end;

function create(next, prev : EditorStr; var body : string) : EditorStr;
begin
        if memType = MT_DOS then create := strsd.create(next, prev, body)
        else create := strsb.create(next, prev, body)
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
        s       : string;
        total      : longint;
        position   : longint;
        percent    : integer;
        ppercent   : integer;
        scrup      : TPercentUpdateProc;
        fnamebak   : STRING;
begin
        if FileExists(fname) THEN BEGIN
                fnamebak := change_ext(fname, '.bak');
                if FileExists(fnamebak) then FileDelete(fnamebak);
                assign(f, fname);
                rename(f, fnamebak);
        END;
        assign(f, fname);
        rewrite(f);
        if not isopen(f) then errCode := 105 else errCode := 0;
        if errCode <> 0 then exit;
        scrup := TPercentUpdateProc(scrupdate);
        total := renum(r);
        position := 0;
        ppercent := -1;
        while r <> nil do begin
                strs.get(r, s);
                writeln(f, s);
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
        truncate(f);
        close(f);
end;

function new : EditorStr;
begin
        if memType = MT_DOS then new := strsd.new
        else new := strsb.new
end;

procedure get(r : EditorStr; var dest : string);
begin
        if memType = MT_DOS then strsd.get(r, dest)
        else strsb.get(r, dest)
end;

function is_first(r : EditorStr) : boolean;
begin
        if memType = MT_DOS then is_first := strsd.is_first(r)
        else is_first := strsb.is_first(r)
end;

function is_last(r : EditorStr) : boolean;
begin
        if memType = MT_DOS then is_last := strsd.is_last(r)
        else is_last := strsb.is_last(r)
end;

function go_first(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then go_first := strsd.go_first(r)
        else go_first := strsb.go_first(r)
end;

function go_last(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then go_last := strsd.go_last(r)
        else go_last := strsb.go_last(r)
end;

function go_prev(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then go_prev := strsd.go_prev(r)
        else go_prev := strsb.go_prev(r)
end;

function go_next(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then go_next := strsd.go_next(r)
        else go_next := strsb.go_next(r)
end;

procedure free(r : EditorStr);
begin
        if memType = MT_DOS then strsd.free(r)
        else strsb.free(r);
end;

function renum(r : EditorStr) : longint;
begin
        if memType = MT_DOS then renum := strsd.renum(r)
        else renum := strsb.renum(r)
end;

function get_num(r : EditorStr) : longint;
begin
        if memType = MT_DOS then get_num := strsd.get_num(r)
        else get_num := strsb.get_num(r)
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
        if memType = MT_DOS then delete := strsd.delete(r, num_from, num_to)
        else delete := strsb.delete(r, num_from, num_to)
end;

function merge(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then merge := strsd.merge(r)
        else merge := strsb.merge(r)
end;

function append(r : EditorStr; var pos : integer; p : pchar; var lnum:word) : EditorStr;
begin
        if memType = MT_DOS then append := strsd.append(r, pos, p, lnum)
        else append := strsb.append(r, pos, p, lnum)
end;

function split(r : EditorStr; pos : integer) : EditorStr;
begin
        if memType = MT_DOS then split := strsd.split(r, pos)
        else split := strsb.split(r, pos)
end;

function is_nil(r : EditorStr) : boolean;
begin
        is_nil := r = nil;
end;

end.

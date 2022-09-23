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

uses strsdos, strsext, dwedtype, system2, str;

const memType : MemoryType = MT_DOS;
const BUF_SIZE = 4 * 1024;

procedure init(mType : MemoryType);
begin
        memType := mType;

        case mType of
        MT_TEMP:     strsext.init_tempfile;
        ELSE strsdos.done;
        end;
end;

procedure done;
begin
        if memType = MT_DOS then strsdos.done
        else strsext.done;
end;

function put(r : EditorStr; var body : string) : EditorStr;
begin
        if memType = MT_DOS then put := strsdos.put(r, body)
        else put := EditorStr(strsext.put(longint(r), body));
end;

function create(next, prev : EditorStr; var body : string) : EditorStr;
begin
        if memType = MT_DOS then create := strsdos.create(next, prev, body)
        else create := EditorStr(strsext.create(longint(next), longint(prev), body));
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
        if memType = MT_DOS then new := strsdos.new
        else new := EditorStr(strsext.new);
end;

procedure get(r : EditorStr; var dest : string);
begin
        if memType = MT_DOS then strsdos.get(r, dest)
        else strsext.get(longint(r), dest);
end;

function is_first(r : EditorStr) : boolean;
begin
        if memType = MT_DOS then is_first := strsdos.is_first(r)
        else is_first := strsext.is_first(longint(r));
end;

function is_last(r : EditorStr) : boolean;
begin
        if memType = MT_DOS then is_last := strsdos.is_last(r)
        else is_last := strsext.is_last(longint(r));
end;

function go_first(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then go_first := strsdos.go_first(r)
        else go_first := EditorStr(strsext.go_first(longint(r)));
end;

function go_last(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then go_last := strsdos.go_last(r)
        else go_last := EditorStr(strsext.go_last(longint(r)));
end;

function go_prev(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then go_prev := strsdos.go_prev(r)
        else go_prev := EditorStr(strsext.go_prev(longint(r)));
end;

function go_next(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then go_next := strsdos.go_next(r)
        else go_next := EditorStr(strsext.go_next(longint(r)));
end;

procedure free(r : EditorStr);
begin
        if memType = MT_DOS then strsdos.free(r)
        else strsext.free(longint(r));
end;

function renum(r : EditorStr) : longint;
begin
        if memType = MT_DOS then renum := strsdos.renum(r)
        else renum := strsext.renum(longint(r));
end;

function get_num(r : EditorStr) : longint;
begin
        if memType = MT_DOS then get_num := strsdos.get_num(r)
        else get_num := strsext.get_num(longint(r));
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
        if memType = MT_DOS then delete := strsdos.delete(r, num_from, num_to)
        else delete := EditorStr(strsext.delete(longint(r), num_from, num_to));
end;

function merge(r : EditorStr) : EditorStr;
begin
        if memType = MT_DOS then merge := strsdos.merge(r)
        else merge := EditorStr(strsext.merge(longint(r)));
end;

function append(r : EditorStr; var pos : integer; p : pchar; var lnum:word) : EditorStr;
begin
        if memType = MT_DOS then append := strsdos.append(r, pos, p, lnum)
        else append := EditorStr(strsext.append(longint(r), pos, p, lnum));
end;

function split(r : EditorStr; pos : integer) : EditorStr;
begin
        if memType = MT_DOS then split := strsdos.split(r, pos)
        else split := EditorStr(strsext.split(longint(r), pos));
end;

function is_nil(r : EditorStr) : boolean;
begin
        is_nil := r = nil;
end;

end.

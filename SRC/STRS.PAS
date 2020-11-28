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

uses strsd, lfn, dwedtype;

const memType : MemoryType = DOS;
const BUF_SIZE = 8 * 1024;

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

function from_file(fname : string; tab_size : integer; var errCode : integer; scrupdate : pointer) : EditorStr;
var     root, cur, last : Pointer;
        f          : word;
        buf        : array[0..BUF_SIZE-1] of char;
        readed     : word;
        pos        : word;
        c          : char;
        strbuf     : array[0..4096] of char;
        strbufpos  : word;
        s          : string;
        i          : integer;
        total      : longint;
        position   : longint;
        percent    : integer;
        ppercent   : integer;
        scrup      : TPercentUpdateProc;
begin
        scrup := TPercentUpdateProc(scrupdate);
        ppercent := -1;
        pos := 0;
        root := nil; last := nil;
        f := lfn.lopen_r(fname);
        if f = 0 then errCode := 104 else errCode := 0;
        position := 0;
        if errCode = 0 then begin
                total := lfn.lsize(f);
                readed := lfn.lread(f, buf[0], BUF_SIZE);
                strbufpos := 0;
                while readed <> 0 do begin
                        while pos < readed do begin
                                c := buf[pos];
                                case c of
                                #$0A: begin
                                        if strbufpos > 255 then strbufpos := 255;
                                        move(strbuf[0], s[1], strbufpos);
                                        s[0] := chr(strbufpos);
                                        cur := strs.create(nil, last, s);
                                        if root = nil then root := cur;
                                        last := cur;
                                        strbufpos := 0;
                                        end;
                                #$09:   for i := 1 to tab_size do begin
                                                strbuf[strbufpos] := ' ';
                                                inc(strbufpos);
                                        end;
                                #$0D:
                                else begin
                                        strbuf[strbufpos] := c;
                                        inc(strbufpos);
                                        end;
                                end;
                                inc(pos);
                        end;
                        inc(position, readed);
                        if scrupdate <> nil then begin
                                percent := (position * 100) div total;
                                if percent <> ppercent then begin
                                        scrup(position, total);
                                        ppercent := percent;
                                end;
                        end;
                        readed := lfn.lread(f, buf[0], BUF_SIZE);
                        pos := 0;
                end;
                if strbufpos > 255 then strbufpos := 255;
                move(strbuf[0], s[1], strbufpos);
                s[0] := chr(strbufpos);
                cur := strs.create(nil, last, s);
                if root = nil then root := cur;
                lfn.lclose(f);
        end else begin
                root := strs.new;
        end;
        from_file := root;
end;

procedure to_file(fname : string; r : EditorStr; var errCode : integer; scrupdate : pointer);
var
        f       : word;
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
        f := lfn.lopen_w(fname);
        if f = 0 then errCode := 105 else errCode := 0;
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
                        lfn.lwrite(f, buf[0], inbuf);
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
        if inbuf <> 0 then lfn.lwrite(f, buf[0], inbuf);
        lfn.ltruncate(f);
        lfn.lclose(f);
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

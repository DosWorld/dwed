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

{$F-}
function EditorStr2Dos(var r : EditorStr) : pointer;
begin
        EditorStr2Dos := r;
end;

{$F-}
function Dos2EditorStr(r : pointer) : EditorStr;
begin
        Dos2EditorStr := r;
end;

function put(r : EditorStr; var body : string) : EditorStr;
begin
        case memType of
        DOS: r := strsd.put(r, body);
        EMS: r := strsd.put(r, body);
        XMS: r := strsd.put(r, body);
        else r := nil;
        end;
        put := r
end;

function create(next, prev : EditorStr; var body : string) : EditorStr;
begin
        case memType of
        DOS: next := strsd.create(next, prev, body);
        EMS: next := strsd.create(next, prev, body);
        XMS: next := strsd.create(next, prev, body);
        else next := nil;
        end;
        create := next;
end;

function from_file(fname : string; tab_size : integer; var errCode : integer; scrupdate : pointer) : EditorStr;
var     root, cur, last : Pointer;
        f          : file;
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
        lfn.assign(f, fname);
        {$I-}
        reset(f, 1);
        errCode := ioresult;
        {$I+}
        position := 0;
        if errCode = 0 then begin
                total := filesize(f);
                seek(f, 0);
                blockread(f, buf[0], BUF_SIZE, readed);
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
                        blockread(f, buf[0], BUF_SIZE, readed);
                        pos := 0;
                end;
                if strbufpos > 255 then strbufpos := 255;
                move(strbuf[0], s[1], strbufpos);
                s[0] := chr(strbufpos);
                cur := strs.create(nil, last, s);
                if root = nil then root := cur;
                close(f);
        end else begin
                root := strs.new;
        end;
        from_file := root;
end;

procedure to_file(fname : string; r : EditorStr; var errCode : integer; scrupdate : pointer);
var
        f       : file;
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
        lfn.create(fname);
        lfn.assign(f, fname);
        {$I-}
        rewrite(f, 1);
        errCode := ioresult;
        {$I+}
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
var r : EditorStr;
begin
        case memType of
        DOS: r := strsd.new;
        EMS: r := strsd.new;
        XMS: r := strsd.new;
        else r := nil;
        end;
        new := r;
end;

procedure get(r : EditorStr; var dest : string);
begin
        case memType of
        DOS: strsd.get(r, dest);
        EMS: strsd.get(r, dest);
        XMS: strsd.get(r, dest);
        else dest := '';
        end;
end;

function is_first(r : EditorStr) : boolean;
var b : boolean;
begin
        case memType of
        DOS: b := strsd.is_first(r);
        EMS: b := strsd.is_first(r);
        XMS: b := strsd.is_first(r);
        else b := true;
        end;
        is_first := b;
end;

function is_last(r : EditorStr) : boolean;
var b : boolean;
begin
        case memType of
        DOS: b := strsd.is_last(r);
        EMS: b := strsd.is_last(r);
        XMS: b := strsd.is_last(r);
        else b := true;
        end;
        is_last := b;
end;

function go_first(r : EditorStr) : EditorStr;
begin
        case memType of
        DOS: r := strsd.go_first(r);
        EMS: r := strsd.go_first(r);
        XMS: r := strsd.go_first(r);
        else r := nil;
        end;
        go_first := r;
end;

function go_last(r : EditorStr) : EditorStr;
begin
        case memType of
        DOS: r := strsd.go_last(r);
        EMS: r := strsd.go_last(r);
        XMS: r := strsd.go_last(r);
        else r := nil;
        end;
        go_last := r;
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
        case memType of
        DOS: strsd.free(r);
        EMS: strsd.free(r);
        XMS: strsd.free(r);
        end;
end;

function renum(r : EditorStr) : longint;
var res : longint;
begin
        case memType of
        DOS: res := strsd.renum(r);
        EMS: res := strsd.renum(r);
        XMS: res := strsd.renum(r);
        else res := 0;
        end;
        renum := res;
end;

function get_num(r : EditorStr) : longint;
var res : longint;
begin
        case memType of
        DOS: res := strsd.get_num(r);
        EMS: res := strsd.get_num(r);
        XMS: res := strsd.get_num(r);
        else res := 0;
        end;
        get_num := res;
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
        case memType of
        DOS: r := strsd.delete(r, num_from, num_to);
        EMS: r := strsd.delete(r, num_from, num_to);
        XMS: r := strsd.delete(r, num_from, num_to);
        else r := nil;
        end;
        delete := r
end;

function merge(r : EditorStr) : EditorStr;
begin
        case memType of
        DOS: r := strsd.merge(r);
        EMS: r := strsd.merge(r);
        XMS: r := strsd.merge(r);
        else r := nil;
        end;
        merge := r;
end;

function append(r : EditorStr; var pos : integer; p : pchar; var lnum:word) : EditorStr;
begin
        case memType of
        DOS: r := strsd.append(r, pos, p, lnum);
        EMS: r := strsd.append(r, pos, p, lnum);
        XMS: r := strsd.append(r, pos, p, lnum);
        else r := strsd.append(r, pos, p, lnum);
        end;
        append := r;
end;

function split(r : EditorStr; pos : integer) : EditorStr;
begin
        case memType of
        DOS: r := strsd.split(r, pos);
        EMS: r := strsd.split(r, pos);
        XMS: r := strsd.split(r, pos);
        else r := strsd.split(r, pos);
        end;
        split := r;
end;

function is_nil(r : EditorStr) : boolean;
begin
        is_nil := r = nil;
end;

end.

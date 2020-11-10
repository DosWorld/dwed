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
{$G-,B-,S-,R-,I-}
unit strs;

interface

type

MemoryType = (DOS, EMS, XMS);

EditorStr = pointer;

procedure init(mType : MemoryType);

function new : EditorStr;

function from_file(fname : string; tab_size : integer) : EditorStr;
procedure to_file(fname : string; r : EditorStr);

function create(next, prev : EditorStr; body : string) : EditorStr;
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

function append(r : EditorStr; var pos : integer; p : pchar) : EditorStr;
function split(r : EditorStr; pos : integer) : EditorStr;

implementation

uses strsd, lfn;

const memType : MemoryType = DOS;
const BUF_SIZE = 4 * 1024;

procedure init(mType : MemoryType);
begin
        memType := mType;
end;

{$F-}
function EditorStr2Dos(r : EditorStr) : pointer;
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
        DOS: r := Dos2EditorStr(strsd.put(EditorStr2Dos(r), body));
        EMS: r := Dos2EditorStr(strsd.put(EditorStr2Dos(r), body));
        XMS: r := Dos2EditorStr(strsd.put(EditorStr2Dos(r), body));
        else r := Dos2EditorStr(nil);
        end;
        put := r
end;

function create(next, prev : EditorStr; body : string) : EditorStr;
begin
        case memType of
        DOS: next := Dos2EditorStr(strsd.create(EditorStr2Dos(next), EditorStr2Dos(prev), body));
        EMS: next := Dos2EditorStr(strsd.create(EditorStr2Dos(next), EditorStr2Dos(prev), body));
        XMS: next := Dos2EditorStr(strsd.create(EditorStr2Dos(next), EditorStr2Dos(prev), body));
        else next := Dos2EditorStr(nil);
        end;
        create := next;
end;

function from_file(fname : string; tab_size : integer) : EditorStr;
var     root, cur, last : Pointer;
        f       : file;
        buf     : array[0..BUF_SIZE-1] of char;
        readed  : word;
        pos     : word;
        c       : char;
        strbuf  : array[0..4096] of char;
        strbufpos       :word;
        s       : string;
        i        : integer;
begin
        pos := 0;
        root := nil; last := nil;
        assign(f, lfn2dos(fname));
        reset(f, 1);
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
                blockread(f, buf[0], BUF_SIZE, readed);
                pos := 0;
        end;

        if strbufpos > 255 then strbufpos := 255;
        move(strbuf[0], s[1], strbufpos);
        s[0] := chr(strbufpos);
        cur := strs.create(nil, last, s);
        if root = nil then root := cur;
        close(f);
        from_file := root;
end;

procedure to_file(fname : string; r : EditorStr);
var
        f       : file;
        buf     : array[0..BUF_SIZE-1] of char;
        inbuf   : word;
        len     : word;
        s       : string;
begin
        assign(f, lfn2dos(fname));
        rewrite(f, 1);
        inbuf := 0;
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
        end;
        if inbuf <> 0 then blockwrite(f, buf[0], inbuf);
        truncate(f);
        close(f);
end;

function new : EditorStr;
var r : EditorStr;
begin
        case memType of
        DOS: r := Dos2EditorStr(strsd.new);
        EMS: r := Dos2EditorStr(strsd.new);
        XMS: r := Dos2EditorStr(strsd.new);
        else r := Dos2EditorStr(nil);
        end;
        new := r;
end;

procedure get(r : EditorStr; var dest : string);
begin
        case memType of
        DOS: strsd.get(EditorStr2Dos(r), dest);
        EMS: strsd.get(EditorStr2Dos(r), dest);
        XMS: strsd.get(EditorStr2Dos(r), dest);
        else dest := '';
        end;
end;

function is_first(r : EditorStr) : boolean;
var b : boolean;
begin
        case memType of
        DOS: b := strsd.is_first(EditorStr2Dos(r));
        EMS: b := strsd.is_first(EditorStr2Dos(r));
        XMS: b := strsd.is_first(EditorStr2Dos(r));
        else b := true;
        end;
        is_first := b;
end;

function is_last(r : EditorStr) : boolean;
var b : boolean;
begin
        case memType of
        DOS: b := strsd.is_last(EditorStr2Dos(r));
        EMS: b := strsd.is_last(EditorStr2Dos(r));
        XMS: b := strsd.is_last(EditorStr2Dos(r));
        else b := true;
        end;
        is_last := b;
end;

function go_first(r : EditorStr) : EditorStr;
begin
        case memType of
        DOS: r := Dos2EditorStr(strsd.go_first(EditorStr2Dos(r)));
        EMS: r := Dos2EditorStr(strsd.go_first(EditorStr2Dos(r)));
        XMS: r := Dos2EditorStr(strsd.go_first(EditorStr2Dos(r)));
        else r := Dos2EditorStr(nil);
        end;
        go_first := r;
end;

function go_last(r : EditorStr) : EditorStr;
begin
        case memType of
        DOS: r := Dos2EditorStr(strsd.go_last(EditorStr2Dos(r)));
        EMS: r := Dos2EditorStr(strsd.go_last(EditorStr2Dos(r)));
        XMS: r := Dos2EditorStr(strsd.go_last(EditorStr2Dos(r)));
        else r := Dos2EditorStr(nil);
        end;
        go_last := r;
end;

function go_prev(r : EditorStr) : EditorStr;
begin
        case memType of
        DOS: r := Dos2EditorStr(strsd.go_prev(EditorStr2Dos(r)));
        EMS: r := Dos2EditorStr(strsd.go_prev(EditorStr2Dos(r)));
        XMS: r := Dos2EditorStr(strsd.go_prev(EditorStr2Dos(r)));
        else r := Dos2EditorStr(nil);
        end;
        go_prev := r;
end;

function go_next(r : EditorStr) : EditorStr;
begin
        case memType of
        DOS: r := Dos2EditorStr(strsd.go_next(EditorStr2Dos(r)));
        EMS: r := Dos2EditorStr(strsd.go_next(EditorStr2Dos(r)));
        XMS: r := Dos2EditorStr(strsd.go_next(EditorStr2Dos(r)));
        else r := Dos2EditorStr(nil);
        end;
        go_next := r;
end;

procedure free(r : EditorStr);
begin
        case memType of
        DOS: strsd.free(EditorStr2Dos(r));
        EMS: strsd.free(EditorStr2Dos(r));
        XMS: strsd.free(EditorStr2Dos(r));
        end;
end;

function renum(r : EditorStr) : longint;
var res : longint;
begin
        case memType of
        DOS: res := strsd.renum(EditorStr2Dos(r));
        EMS: res := strsd.renum(EditorStr2Dos(r));
        XMS: res := strsd.renum(EditorStr2Dos(r));
        else res := 0;
        end;
        renum := res;
end;

function get_num(r : EditorStr) : longint;
var res : longint;
begin
        case memType of
        DOS: res := strsd.get_num(EditorStr2Dos(r));
        EMS: res := strsd.get_num(EditorStr2Dos(r));
        XMS: res := strsd.get_num(EditorStr2Dos(r));
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
        DOS: r := Dos2EditorStr(strsd.delete(EditorStr2Dos(r), num_from, num_to));
        EMS: r := Dos2EditorStr(strsd.delete(EditorStr2Dos(r), num_from, num_to));
        XMS: r := Dos2EditorStr(strsd.delete(EditorStr2Dos(r), num_from, num_to));
        else r := Dos2EditorStr(nil);
        end;
        delete := r
end;

function merge(r : EditorStr) : EditorStr;
begin
        case memType of
        DOS: r := Dos2EditorStr(strsd.merge(EditorStr2Dos(r)));
        EMS: r := Dos2EditorStr(strsd.merge(EditorStr2Dos(r)));
        XMS: r := Dos2EditorStr(strsd.merge(EditorStr2Dos(r)));
        else r := Dos2EditorStr(nil);
        end;
        merge := r;
end;

function append(r : EditorStr; var pos : integer; p : pchar) : EditorStr;
begin
        case memType of
        DOS: r := Dos2EditorStr(strsd.append(EditorStr2Dos(r), pos, p));
        EMS: r := Dos2EditorStr(strsd.append(EditorStr2Dos(r), pos, p));
        XMS: r := Dos2EditorStr(strsd.append(EditorStr2Dos(r), pos, p));
        else r := Dos2EditorStr(strsd.append(EditorStr2Dos(r), pos, p));
        end;
        append := r;
end;

function split(r : EditorStr; pos : integer) : EditorStr;
begin
        case memType of
        DOS: r := Dos2EditorStr(strsd.split(EditorStr2Dos(r), pos));
        EMS: r := Dos2EditorStr(strsd.split(EditorStr2Dos(r), pos));
        XMS: r := Dos2EditorStr(strsd.split(EditorStr2Dos(r), pos));
        else r := Dos2EditorStr(strsd.split(EditorStr2Dos(r), pos));
        end;
        split := r;
end;

end.

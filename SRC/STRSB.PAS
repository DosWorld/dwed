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
{$A-}
unit strsb;

{ ems/xms memory string storage }

interface

uses strs;

procedure init(mType : MemoryType);

function new : pointer;

procedure free(r : pointer);

function create(next, prev : pointer; body : string) : pointer;

function put(r : pointer; var body : string) : pointer;
procedure get(r : pointer; var dest : string);
function delete(r : pointer; num_from, num_to : longint) : pointer;
function merge(r : pointer) : pointer;

function is_first(r : pointer) : boolean;
function is_last(r : pointer) : boolean;

function go_first(r : pointer) : pointer;
function go_last(r : pointer) : pointer;

function go_prev(r : pointer) : pointer;
function go_next(r : pointer) : pointer;

function renum(r : pointer) : longint;
function get_num(r : pointer) : longint;
function append(r : pointer; var pos : integer; p : pchar; var lnum:word) : pointer;
function split(r : pointer; pos : integer) : pointer;

implementation

uses strutil, system2, dbu;

const
BLK_SIZE = 64;

type

PString =^ TString;
TString = record
        next       : PString;
        prev       : PString;
        allocated  : word;
        num        : longint;
        len        : byte;
        body       : array[1..1] of char;
end;

var     oldexitproc : pointer;
        idx : bfile;
        db  : DBUFile;

function norm_len(len : word) : word;
var w : word;
begin
        w := len shr 3;
        if (len and $07) <> 0 then inc(w);
        w := w shl 3;
        norm_len := w;
end;

function create(next, prev : pointer; body : string) : pointer;
var len, nlen : word;
        r : PString;
begin
        len := length(body);
        nlen := norm_len(len);
        getmem(r, sizeof(TString) + nlen - 1);
        r^.next := PString(next);
        r^.prev := PString(prev);
        r^.len := len;
        r^.allocated := nlen;
        move(body[1], r^.body[1], len);
        if prev <> nil then PString(prev)^.next := r;
        if next <> nil then PString(next)^.prev := r;
        create := r;
end;

procedure free_str(r : pointer);
begin
        if r = nil then exit;
        freemem(r, sizeof(TString) + PString(r)^.allocated - 1);
end;

function put(r : pointer; var body : string) : pointer;
var len : word;
        old : PString;
begin
        len := norm_len(length(body));
        if len = PString(r)^.allocated then begin
                len := length(body);
                move(body[1], PString(r)^.body[1], len);
                PString(r)^.len := len;
        end else begin
                old := r;
                r := PString(create(PString(r)^.next, PString(r)^.prev, body));
                PString(r)^.num := old^.num;
                free_str(old);
        end;
        put := r;
end;

function new : pointer;
begin
        new := create(nil, nil, '');
end;

procedure get(r : pointer; var dest : string);
begin
        if r <> nil then begin
                move(PString(r)^.body[1], dest[1], PString(r)^.len);
                dest[0] := chr(PString(r)^.len);
        end else dest := '';
end;

function is_first(r : pointer) : boolean;
begin
        is_first := PString(r)^.prev = nil;
end;

function is_last(r : pointer) : boolean;
begin
        is_last := PString(r)^.next = nil;
end;

function go_first(r : pointer) : pointer;
begin
        if r <> nil then begin
                while PString(r)^.prev <> nil do r := PString(r)^.prev;
        end;
        go_first := r;
end;

function go_last(r : pointer) : pointer;
begin
        if r <> nil then begin
                while PString(r)^.next <> nil do r := PString(r)^.next;
        end;
        go_last := r;
end;

function go_prev(r : pointer) : pointer;
begin
        if r <> nil then r := PString(r)^.prev;
        go_prev := r;
end;

function go_next(r : pointer) : pointer;
begin
        if r <> nil then r := PString(r)^.next;
        go_next := r;
end;

procedure free(r : pointer);
var o : pointer;
begin
        while r <> nil do begin
                o := PString(r)^.next;
                free_str(r);
                r := o;
        end;
end;

function renum(r : pointer) : longint;
var res : longint;
begin
        res := 0;
        while r <> nil do begin
                inc(res);
                PString(r)^.num := res;
                r := PString(r)^.next;
        end;
        renum := res;
end;

function get_num(r : pointer) : longint;
begin
        get_num := PString(r)^.num;
end;

function del_str(r : PString) : PString;
var t : PString;
begin
        if r <> nil then begin
                t := r;
                r := r^.next;
                with t^ do begin
                        if next <> nil then next^.prev := prev;
                        if prev <> nil then prev^.next := next;
                end;
                free_str(t);
        end;
        del_str := r;
end;

function delete(r : pointer; num_from, num_to : longint) : pointer;
var t  : PString;
    n  : longint;
begin
        t := r;
        n := 1;
        while (t <> nil) and (t^.num <> num_from) do begin
                if t^.prev = nil then r := t;
                t^.num := n; inc(n);
                t := t^.next;
        end;
        while (t <> nil) and (t^.num <= num_to) do begin
                        t := del_str(t);
                        if t^.prev = nil then r := t;
        end;
        while (t <> nil) do begin
                t^.num := n; inc(n);
                t := t^.next;
        end;
        delete := r;
end;

function merge(r : pointer) : pointer;
var s1, s2 : string;
        t1, t2 :PString;
begin
        if PString(r)^.next <> nil then begin
                t1 := r;
                t2 := t1^.next;
                get(t1, s1);
                get(t2, s2);
                if length(s1) + length(s2) <= 255 then begin
                        r := strsb.create(t2^.next, t1^.prev, s1 + s2);
                        free_str(t1);
                        free_str(t2);
                end;
        end;
        merge := r;
end;

function append(r : pointer; var pos : integer; p : pchar; var lnum:word) : pointer;
var     s, src, s1, s2 : string;
        c : char;
        len : integer;
begin
        lnum := 0;
        if not ((r = nil) or (p = nil)) then begin
                s := '';
                strsb.get(r, src);
                while p[0] <> #0 do begin
                        c := p[0];
                        case c of
                        #$0A: begin
                                inc(lnum);
                                s1 := '';
                                s2 := '';
                                len := length(src);
                                if len > 0 then s1 := copy(src, 1, pos - 1);
                                if pos <= len then s2 := copy(src, pos, len - pos + 1);
                                s1 := s1 + s;
                                r := strsb.put(r, s1);
                                r := strsb.create(Pstring(r)^.next, r, s2);
                                src := s2;
                                pos := 1;
                                s := '';
                        end;
                        else if c <> #$0d then s := s + c;
                        end;
                        inc(p);
                end;
                if length(s) <> 0 then begin
                        strsb.get(r, s1);
                        System.insert(s, s1, pos);
                        inc(pos, length(s));
                        r := strsb.put(r, s1);
                end;
        end;
        append := r;
end;

function split(r : pointer; pos : integer) : pointer;
var s1, s2 : string;
begin
        strsb.get(r, s1);
        s2 := copy(s1, pos, length(s1) - pos + 1);
        s1 := rtrim(copy(s1, 1, pos - 1));
        r := strsb.put(r, s1);
        strsb.create(PString(r)^.next, r, s2);
        split := r;
end;

procedure onexit;far;
begin
        close(idx);
        dbu_close(db);
        exitProc := oldexitproc;
end;

procedure init(mType : MemoryType);
begin
        oldexitproc := exitProc;
        FillChar(idx, SizeOf(BFile), #0);
        FillChar(db, SizeOf(DBUFile), #0);
        case mType of
        strs.MT_TEMP_WO_CACHE: BEGIN
                SetUseTempFiles(TRUE);
                SetDefaultCacheSize(0);
                dbu_rewrite_temp(db, BLK_SIZE);
                ReWriteTemp (idx);
                END;
        strs.MT_TEMP_WITH_CACHE: BEGIN
                SetUseTempFiles(TRUE);
                SetDefaultCacheSize(CACHE_PAGES_PER_FILE);
                dbu_rewrite_temp(db, BLK_SIZE);
                SetDefaultCacheSize(4);
                ReWriteTemp(idx);
                END;
        strs.MT_BIGMEM: BEGIN
                dbu_rewrite_memfile(db, BLK_SIZE);
                ReWriteMemFile(idx);
                END;
        end;
end;

end.

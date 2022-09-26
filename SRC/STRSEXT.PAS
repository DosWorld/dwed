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
unit strsext;

{ External memory string-storage }

interface

procedure init_tempfile;
procedure done;

function new : longint;

procedure free(r : longint);

function create(next, prev : longint; body : string) : longint;

function put(r : longint; var body : string) : longint;
procedure get(r : longint; var dest : string);
function delete(r : longint; num_from, num_to : longint) : longint;
function merge(r : longint) : longint;

function is_first(r : longint) : boolean;
function is_last(r : longint) : boolean;

function go_first(r : longint) : longint;
function go_last(r : longint) : longint;

function go_prev(r : longint) : longint;
function go_next(r : longint) : longint;

function renum(r : longint) : longint;
function get_num(r : longint) : longint;
function append(r : longint; var pos : integer; p : pchar; var lnum:word) : longint;
function split(r : longint; pos : integer) : longint;

implementation

uses system2, str, dbm, dbb;

type
TString = record
        next   : longint;
        prev   : longint;
        len    : word;
        num    : longint;
        recno  : longint;
end;

const   MEM_BLK_SIZE = 32;
        IDX_BLK_SIZE = sizeof(TString);

var     dbm_mem : DBMFile;
        dbb_idx : DBBFile;

function create(next, prev : longint; body : string) : longint;
var     r   : longint;
        rec : TString;
begin
        FillChar(rec, SizeOf(TString), #0);
        rec.next := next;
        rec.prev := prev;
        rec.recno := 0;
        rec.num := 0;
        rec.len := length(body) + 1;
        if rec.len <> 1 then rec.recno := dbm_add(dbm_mem, body, rec.len);
        r := dbb_add(dbb_idx, rec);
        if prev <> 0 then begin
                dbb_get(dbb_idx, prev, rec);
                rec.next := r;
                dbb_put(dbb_idx, prev, rec);
        end;
        if next <> 0 then begin
                dbb_get(dbb_idx, next, rec);
                rec.prev := r;
                dbb_put(dbb_idx, next, rec);
        end;
        create := r;
end;

procedure free_str(r : longint);
var     rec : TString;
begin
        if r = 0 then exit;
        dbb_get(dbb_idx, r, rec);
        dbm_free(dbm_mem, rec.recno);
        dbb_free(dbb_idx, r);
end;

function put(r : longint; var body : string) : longint;
var     rec : TString;
begin
        dbb_get(dbb_idx, r, rec);
        dbm_free(dbm_mem, rec.recno);
        rec.len := length(body) + 1;
        if rec.len = 1 then begin
                rec.recno := 0;
        end else begin
                rec.recno := dbm_add(dbm_mem, body, rec.len)
        end;
        dbb_put(dbb_idx, r, rec);
        put := r;
end;

function new : longint;
begin
        new := create(0, 0, '');
end;

procedure get(r : longint; var dest : string);
var     rec : TString;
begin
        dest := '';
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                if rec.recno <> 0 then dbm_get(dbm_mem, rec.recno, dest, rec.len);
        end;
end;

function is_first(r : longint) : boolean;
var     rec : TString;
begin
        dbb_get(dbb_idx, r, rec);
        is_first := rec.prev = 0;
end;

function is_last(r : longint) : boolean;
var     rec : TString;
begin
        dbb_get(dbb_idx, r, rec);
        is_last := rec.next = 0;
end;

function go_first(r : longint) : longint;
var     rec : TString;
begin
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                while rec.prev <> 0 do begin
                        r := rec.prev;
                        dbb_get(dbb_idx, r, rec);
                end;
        end;
        go_first := r;
end;

function go_last(r : longint) : longint;
var     rec : TString;
begin
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                while rec.next <> 0 do begin
                        r := rec.next;
                        dbb_get(dbb_idx, r, rec);
                end;
        end;
        go_last := r;
end;

function go_prev(r : longint) : longint;
var     rec : TString;
begin
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                r := rec.prev;
        end;
        go_prev := r;
end;

function go_next(r : longint) : longint;
var     rec : TString;
begin
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                r := rec.next;
        end;
        go_next := r;
end;

procedure free(r : longint);
var     rec : TString;
begin
        while r <> 0 do begin
                dbb_get(dbb_idx, r, rec);
                dbb_free(dbb_idx, r);
                dbm_free(dbm_mem, rec.recno);
                r := rec.next;
        end;
end;

function renum(r : longint) : longint;
var     rec : TString;
        res : longint;
begin
        res := 0;
        while r <> 0 do begin
                inc(res);
                dbb_get(dbb_idx, r, rec);
                rec.num := res;
                dbb_put(dbb_idx, r, rec);
                r := rec.next;
        end;
        renum := res;
end;

function get_num(r : longint) : longint;
var     rec : TString;
begin
        dbb_get(dbb_idx, r, rec);
        get_num := rec.num;
end;

function delete(r : longint; num_from, num_to : longint) : longint;
var     rno, lrno   : longint;
        line, lline : longint;
        rec         : TString;
begin
        rno := r;
        line := 1;
        lrno := 0;
        while (rno <> 0) and (line < num_from) do begin
                lrno := rno;
                dbb_get(dbb_idx, rno, rec);
                rno := rec.next;
                inc(line);
        end;
        lline := line;
        while (rno <> 0) and (line <= num_to) do begin
                dbb_get(dbb_idx, rno, rec);
                dbm_free(dbm_mem, rec.recno);
                dbb_free(dbb_idx, rno);
                rno := rec.next;
                inc(line);
        end;
        if lrno = 0 then r := rno;
        if lrno <> 0 then begin
                dbb_get(dbb_idx, lrno, rec);
                rec.next := rno;
                dbb_put(dbb_idx, lrno, rec);
        end;
        if rno <> 0 then begin
                dbb_get(dbb_idx, rno, rec);
                rec.prev := lrno;
                dbb_put(dbb_idx, rno, rec);
        end;
        line := lline;
        while rno <> 0 do begin
                dbb_get(dbb_idx, rno, rec);
                rec.num := line;
                dbb_put(dbb_idx, rno, rec);
                inc(line);
                rno := rec.next;
        end;
        delete := r;
end;

function merge(r : longint) : longint;
var     s1, s2 : string;
        t1, t2 : TString;
        r1, r2 : longint;
begin
        r1 := r;
        dbb_get(dbb_idx, r1, t1);
        r2 := t1.next;
        if r2 <> 0 then begin
                s1 := '';
                s2 := '';
                dbb_get(dbb_idx, r2, t2);
                if t1.recno <> 0 then dbm_get(dbm_mem, t1.recno, s1, t1.len);
                if t2.recno <> 0 then dbm_get(dbm_mem, t2.recno, s2, t2.len);
                if length(s1) + length(s2) <= 255 then begin
                        s1 := s1 + s2;
                        strsext.put(r, s1);
                        dbb_get(dbb_idx, r1, t1);
                        t1.next := t2.next;
                        dbb_put(dbb_idx, r1, t1);
                        dbb_free(dbb_idx, r2);
                        dbm_free(dbm_mem, t2.recno);

                        dbb_get(dbb_idx, t1.next, t2);
                        t2.prev := r1;
                        dbb_put(dbb_idx, t1.next, t2);
                end;
        end;
        merge := r;
end;

function append(r : longint; var pos : integer; p : pchar; var lnum:word) : longint;
var     s, src, s1, s2 : string;
        c   : char;
        len : integer;
        rec : TString;
begin
        lnum := 0;
        if not ((r = 0) or (p = nil)) then begin
                s := '';
                dbb_get(dbb_idx, r, rec);
                src := '';
                if (rec.recno <> 0) and (rec.len <> 1) then dbm_get(dbm_mem, rec.recno, src, rec.len);
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
                                rec.len := length(s1) + 1;
                                if rec.len <> 1 then begin
                                        if rec.recno <> 0 then dbm_put(dbm_mem, rec.recno, s1, rec.len)
                                        else rec.recno := dbm_add(dbm_mem, s1, rec.len);
                                end else begin
                                        dbm_free(dbm_mem, rec.recno);
                                        rec.recno := 0;
                                end;
                                dbb_put(dbb_idx, r, rec);
                                r := strsext.create(rec.next, r, s2);
                                dbb_get(dbb_idx, r, rec);
                                src := s2;
                                pos := 1;
                                s := '';
                        end;
                        else if c <> #$0d then s := s + c;
                        end;
                        inc(p);
                end;
                if length(s) <> 0 then begin
                        strsext.get(r, s1);
                        System.insert(s, s1, pos);
                        inc(pos, length(s));
                        r := strsext.put(r, s1);
                end;
        end;
        append := r;
end;

function split(r : longint; pos : integer) : longint;
var     s1, s2 : string;
        rec : TString;
begin
        s1 := '';
        dbb_get(dbb_idx, r, rec);
        if rec.recno <> 0 then dbm_get(dbm_mem, rec.recno, s1, rec.len);
        dbm_free(dbm_mem, rec.recno);
        rec.recno := 0;
        s2 := trim(copy(s1, pos, length(s1) - pos + 1));
        s1 := rtrim(copy(s1, 1, pos - 1));
        rec.len := length(s1) + 1;
        if rec.len <> 1 then rec.recno := dbm_add(dbm_mem, s1, rec.len);
        dbb_put(dbb_idx, r, rec);
        strsext.create(rec.next, r, s2);
        split := r;
end;
        
procedure init_tempfile;
begin
        dbm_rewrite_temp(dbm_mem, MEM_BLK_SIZE);
        dbb_rewrite_temp(dbb_idx, IDX_BLK_SIZE);
end;
procedure done;
begin
        dbm_close(dbm_mem);
        dbb_close(dbb_idx);
end;

begin
        FillChar(dbm_mem, SizeOf(DBMFile), #0);
        FillChar(dbb_idx, SizeOf(DBBFile), #0);
end.

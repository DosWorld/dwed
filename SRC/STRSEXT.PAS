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

uses system2, str, dbu;

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

var     dbu_mem : DBUFile;
        dbu_idx : DBUFile;

function create(next, prev : longint; body : string) : longint;
var     r   : longint;
        rec : TString;
begin
        FillChar(rec, SizeOf(TString), #0);
        rec.next := next;
        rec.prev := prev;
        rec.num := 0;
        rec.len := length(body) + 1;
        if rec.len <> 1 then rec.recno := dbu_add(dbu_mem, body, rec.len);
        r := dbu_add(dbu_idx, rec, IDX_BLK_SIZE);
        if prev <> 0 then begin
                dbu_get(dbu_idx, prev, rec, IDX_BLK_SIZE);
                rec.next := r;
                dbu_put(dbu_idx, prev, rec, IDX_BLK_SIZE);
        end;
        if next <> 0 then begin
                dbu_get(dbu_idx, next, rec, IDX_BLK_SIZE);
                rec.prev := r;
                dbu_put(dbu_idx, next, rec, IDX_BLK_SIZE);
        end;
        create := r;
end;

procedure free_str(r : longint);
var     rec : TString;
begin
        if r = 0 then exit;
        dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
        dbu_free(dbu_mem, rec.recno);
        dbu_free(dbu_idx, r);
end;

function put(r : longint; var body : string) : longint;
var     rec : TString;
begin
        dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
        rec.len := length(body) + 1;
        if rec.len = 1 then begin
                dbu_free(dbu_mem, rec.recno);
                rec.recno := 0;
        end else if rec.recno = 0 then begin
                rec.recno := dbu_add(dbu_mem, body, rec.len)
        end else begin
                dbu_put(dbu_mem, rec.recno, body, rec.len)
        end;
        dbu_put(dbu_idx, r, rec, IDX_BLK_SIZE);
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
                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                if rec.recno <> 0 then dbu_get(dbu_mem, rec.recno, dest, rec.len);
        end;
end;

function is_first(r : longint) : boolean;
var     rec : TString;
begin
        dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
        is_first := rec.prev = 0;
end;

function is_last(r : longint) : boolean;
var     rec : TString;
begin
        dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
        is_last := rec.next = 0;
end;

function go_first(r : longint) : longint;
var     rec : TString;
begin
        if r <> 0 then begin
                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                while rec.prev <> 0 do begin
                        r := rec.prev;
                        dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                end;
        end;
        go_first := r;
end;

function go_last(r : longint) : longint;
var     rec : TString;
begin
        if r <> 0 then begin
                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                while rec.next <> 0 do begin
                        r := rec.next;
                        dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                end;
        end;
        go_last := r;
end;

function go_prev(r : longint) : longint;
var     rec : TString;
begin
        if r <> 0 then begin
                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                r := rec.prev;
        end;
        go_prev := r;
end;

function go_next(r : longint) : longint;
var     rec : TString;
begin
        if r <> 0 then begin
                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                r := rec.next;
        end;
        go_next := r;
end;

procedure free(r : longint);
var     rec : TString;
begin
        while r <> 0 do begin
                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                dbu_free(dbu_idx, r);
                dbu_free(dbu_mem, rec.recno);
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
                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                rec.num := res;
                dbu_put(dbu_idx, r, rec, IDX_BLK_SIZE);
                r := rec.next;
        end;
        renum := res;
end;

function get_num(r : longint) : longint;
var     rec : TString;
begin
        dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
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
                dbu_get(dbu_idx, rno, rec, IDX_BLK_SIZE);
                rno := rec.next;
                inc(line);
        end;
        lline := line;
        while (rno <> 0) and (line < num_to) do begin
                dbu_get(dbu_idx, rno, rec, IDX_BLK_SIZE);
                dbu_free(dbu_mem, rec.recno);
                dbu_free(dbu_idx, rno);
                rno := rec.next;
                inc(line);
        end;
        if lrno = 0 then r := rno;
        if lrno <> 0 then begin
                dbu_get(dbu_idx, lrno, rec, IDX_BLK_SIZE);
                rec.next := rno;
                dbu_put(dbu_idx, lrno, rec, IDX_BLK_SIZE);
        end;
        if rno <> 0 then begin
                dbu_get(dbu_idx, rno, rec, IDX_BLK_SIZE);
                rec.prev := lrno;
                dbu_put(dbu_idx, rno, rec, IDX_BLK_SIZE);
        end;
        line := lline;
        while rno <> 0 do begin
                dbu_get(dbu_idx, rno, rec, IDX_BLK_SIZE);
                rec.num := line;
                dbu_put(dbu_idx, rno, rec, IDX_BLK_SIZE);
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
        dbu_get(dbu_idx, r1, t1, IDX_BLK_SIZE);
        r2 := t1.next;
        if r2 <> 0 then begin
                s1 := '';
                s2 := '';
                dbu_get(dbu_idx, r1, t1, IDX_BLK_SIZE);
                dbu_get(dbu_idx, r2, t2, IDX_BLK_SIZE);
                if t1.recno <> 0 then dbu_get(dbu_mem, t1.recno, s1, t1.len);
                if t2.recno <> 0 then dbu_get(dbu_mem, t2.recno, s2, t2.len);
                if length(s1) + length(s2) <= 255 then begin
                        s1 := s1 + s2;
                        strsext.put(r, s1);

                        dbu_get(dbu_idx, r1, t1, IDX_BLK_SIZE);
                        dbu_get(dbu_idx, r2, t2, IDX_BLK_SIZE);
                        t1.next := t2.next;
                        dbu_put(dbu_idx, r1, t1, IDX_BLK_SIZE);
                        dbu_free(dbu_idx, r2);
                        dbu_free(dbu_mem, t2.recno);

                        dbu_get(dbu_idx, t1.next, t2, IDX_BLK_SIZE);
                        t2.prev := r1;
                        dbu_put(dbu_idx, t1.next, t2, IDX_BLK_SIZE);
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
                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
                dbu_get(dbu_mem, rec.recno, src, rec.len);
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
                                if rec.len <> 1 then dbu_put(dbu_mem, rec.recno, s1, rec.len)
                                else begin
                                        dbu_free(dbu_mem, rec.recno);
                                        rec.recno := 0;
                                end;
                                dbu_put(dbu_idx, r, rec, IDX_BLK_SIZE);
                                r := strsext.create(rec.next, r, s2);
                                dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
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
        dbu_get(dbu_idx, r, rec, IDX_BLK_SIZE);
        dbu_get(dbu_mem, rec.recno, s1, rec.len);
        s2 := copy(s1, pos, length(s1) - pos + 1);
        s1 := rtrim(copy(s1, 1, pos - 1));
        rec.len := length(s1) + 1;
        if rec.len <> 1 then dbu_put(dbu_mem, rec.recno, s1, rec.len)
        else begin
                dbu_free(dbu_mem, rec.recno);
                rec.recno := 0;
        end;
        dbu_put(dbu_idx, r, rec, IDX_BLK_SIZE);
        strsext.create(rec.next, r, s2);
        split := r;
end;
        
procedure init_tempfile;
begin
        dbu_rewrite_temp(dbu_mem, MEM_BLK_SIZE);
        dbu_rewrite_temp(dbu_idx, IDX_BLK_SIZE);
end;
procedure done;
begin
        dbu_close(dbu_mem);
        dbu_close(dbu_idx);
end;

begin
        FillChar(dbu_mem, SizeOf(DBUFile), #0);
        FillChar(dbu_idx, SizeOf(DBUFile), #0);
end.

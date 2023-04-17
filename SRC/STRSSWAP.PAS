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
{$A-,F-}
unit strsswap;

{ External memory string-storage }

interface

uses dwedtype;

procedure init;
procedure done;

function new : dword;
procedure free(r : dword);

function create(next, prev : dword; body : string) : dword;

function put(r : dword; var body : string) : dword;
procedure get(r : dword; var dest : string);
function delete(r : dword; num_from, num_to : dword) : dword;
function merge(r : dword) : dword;

function is_first(r : dword) : boolean;
function is_last(r : dword) : boolean;

function go_first(r : dword) : dword;
function go_last(r : dword) : dword;

function go_prev(r : dword) : dword;
function go_next(r : dword) : dword;

function is_nil(r : dword) : boolean;

function renum(r : dword) : dword;
function get_num(r : dword) : dword;
function append(r : dword; var pos : integer; p : pchar; var lnum:word) : dword;
function split(r : dword; pos : integer) : dword;

function from_file(fname : string; tab_size : integer; var errCode : integer; scrupdate : pointer) : dword;
procedure to_file(fname : string; r : dword; var errCode : integer; scrupdate : pointer);

implementation

uses System2, scr, str, dbm, dbb, strutil, dwedutil;

type
TExtStringRec = record
        next   : dword;
        prev   : dword;
        len    : word;
        num    : dword;
        recno  : dword;
end;

const
MEM_BLK_SIZE = 32;
IDX_BLK_SIZE = sizeof(TExtStringRec);

var     dbm_mem : DBMFile;
        dbb_idx : DBBFile;

{$F-}

function create(next, prev : dword; body : string) : dword;
var     r   : dword;
        rec : TExtStringRec;
begin
        FillChar(rec, SizeOf(TExtStringRec), #0);
        rec.next := next;
        rec.prev := prev;
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

procedure free_str(r : dword);
var     rec : TExtStringRec;
begin
        if r = 0 then exit;
        dbb_get(dbb_idx, r, rec);
        dbm_free(dbm_mem, rec.recno);
        dbb_free(dbb_idx, r);
end;

function put(r : dword; var body : string) : dword;
var     rec : TExtStringRec;
begin
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                dbm_free(dbm_mem, rec.recno);
                rec.len := length(body) + 1;
                if rec.len = 1 then begin
                        rec.recno := 0;
                end else begin
                        rec.recno := dbm_add(dbm_mem, body, rec.len)
                end;
                dbb_put(dbb_idx, r, rec);
        end;
        put := r;
end;

function new : dword;
begin
        new := create(0, 0, '');
end;

procedure get(r : dword; var dest : string);
var     rec : TExtStringRec;
begin
        dest[0] := #0;
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                if rec.recno <> 0 then dbm_get(dbm_mem, rec.recno, dest, rec.len);
        end;
end;

function is_first(r : dword) : boolean;
var     rec : TExtStringRec;
begin
        dbb_get(dbb_idx, r, rec);
        is_first := rec.prev = 0;
end;

function is_last(r : dword) : boolean;
var     rec : TExtStringRec;
begin
        dbb_get(dbb_idx, r, rec);
        is_last := rec.next = 0;
end;

function go_first(r : dword) : dword;
var     rec : TExtStringRec;
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

function go_last(r : dword) : dword;
var     rec : TExtStringRec;
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

function go_prev(r : dword) : dword;
var     rec : TExtStringRec;
begin
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                r := rec.prev;
        end;
        go_prev := r;
end;

function go_next(r : dword) : dword;
var     rec : TExtStringRec;
begin
        if r <> 0 then begin
                dbb_get(dbb_idx, r, rec);
                r := rec.next;
        end;
        go_next := r;
end;

procedure free(r : dword);
var     rec : TExtStringRec;
begin
        while r <> 0 do begin
                dbb_get(dbb_idx, r, rec);
                dbb_free(dbb_idx, r);
                dbm_free(dbm_mem, rec.recno);
                r := rec.next;
        end;
end;

function renum(r : dword) : dword;
var     rec : TExtStringRec;
        res : dword;
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

function get_num(r : dword) : dword;
var     rec : TExtStringRec;
begin
        dbb_get(dbb_idx, r, rec);
        get_num := rec.num;
end;

function delete(r : dword; num_from, num_to : dword) : dword;
var     rno, lrno   : dword;
        line, lline : dword;
        rec         : TExtStringRec;
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

function merge(r : dword) : dword;
var     s1, s2 : string;
        t1, t2 : TExtStringRec;
        r1, r2 : dword;
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
                        strsswap.put(r, s1);
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

function append(r : dword; var pos : integer; p : pchar; var lnum:word) : dword;
var     s, src, s1, s2 : string;
        c   : char;
        len : integer;
        rec : TExtStringRec;
begin
        lnum := 0;
        if not ((r = 0) or (p = nil)) then begin
                s := '';
                dbb_get(dbb_idx, r, rec);
                src := '';
                if (rec.recno <> 0) and (rec.len <> 1) then dbm_get(dbm_mem, rec.recno, src, rec.len);
                while p^ <> #0 do begin
                        c := p^;
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
                                r := strsswap.create(rec.next, r, s2);
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
                        strsswap.get(r, s1);
                        System.insert(s, s1, pos);
                        inc(pos, length(s));
                        r := strsswap.put(r, s1);
                end;
        end;
        append := r;
end;

function split(r : dword; pos : integer) : dword;
var     s1, s2 : string;
        rec : TExtStringRec;
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
        strsswap.create(rec.next, r, s2);
        split := r;
end;
        
procedure init;
begin
        FillChar(dbm_mem, SizeOf(DBMFile), #0);
        FillChar(dbb_idx, SizeOf(DBBFile), #0);
        dbm_rewritetemp(dbm_mem, MEM_BLK_SIZE);
        dbb_rewritetemp(dbb_idx, IDX_BLK_SIZE);
end;

procedure done;
begin
        dbm_close(dbm_mem);
        dbb_close(dbb_idx);
end;

function from_file(fname : string; tab_size : integer; var errCode : integer; scrupdate : pointer) : dword;
var     root       : dword;
        f          : bfile;
        s          : string;
        total      : dword;
        position   : dword;
        scrup      : TPercentUpdateProc;
        tabs       : string;
        prec, crec : TExtStringRec;
        pno, cno   : dword;
        readed     : integer;
        start_date : longint;
begin
        scrup := TPercentUpdateProc(scrupdate);
        start_date := get_ticks;

        fillchar(f, sizeof(bfile), #0);
        fillchar(prec, sizeof(TExtStringRec), #0);
        fillchar(tabs[1], 255, #32);
        tabs[0] := chr(tab_size);

        root := 0;
        readed := 0;
        total := 0;
        position := 0;        

        pno := 0;
        cno := 0;

        assign(f, fname);
        reset(f);
        if not IsOpen(f) then errCode := 104 else total := filesize(f);

        if total <> 0 then begin
                while not eof(f) do begin
                        readln(f, s);
                        remove_tabs(s, tabs);
                        fillchar(crec, sizeof(TExtStringRec), #0);
                        crec.prev := pno;
                        crec.len := length(s) + 1;
                        if s[0] <> #0 then crec.recno := dbm_add(dbm_mem, s, crec.len);
                        cno := dbb_add(dbb_idx, crec);
                        if root = 0 then root := cno;
                        if pno <> 0 then begin
                                prec.next := cno;
                                dbb_put(dbb_idx, pno, prec);
                        end;
                        prec := crec;
                        pno := cno;
                        inc(readed, ord(s[0]));
                        if readed > PROGRESS_UPDATE then begin
                                if scrupdate <> nil then begin
                                        position := filepos(f);
                                        scrup(position, total, start_date);
                                end;
                                readed := 0;
                        end;

                end;
        end;
        if scrupdate <> nil then begin
                position := filepos(f);
                scrup(position, total, start_date);
        end;
        if IsOpen(f) then close(f);

        if root = 0 then root := strsswap.new;
        from_file := root;
end;

procedure to_file(fname : string; r : dword; var errCode : integer; scrupdate : pointer);
var     f          : bfile;
        s          : string;
        total      : dword;
        position   : dword;
        scrup      : TPercentUpdateProc;
        rec        : TExtStringRec;
        writed     : integer;
        start_date : longint;
begin
        assign(f, fname);
        rewrite(f);
        if not isopen(f) then begin
                errCode := 105;
                exit;
        end;

        scrup := TPercentUpdateProc(scrupdate);
        start_date := get_ticks;

        total := strsswap.renum(r);
        position := 0;
        writed := 0;

        while r <> 0 do begin
                dbb_get(dbb_idx, r, rec);
                if rec.recno <> 0 then dbm_get(dbm_mem, rec.recno, s, rec.len)
                else s[0] := #0;
                writeln(f, s);
                r := rec.next;
                inc(writed, ord(s[0]));
                inc(position);
                if writed > PROGRESS_UPDATE then begin
                        if scrupdate <> nil then begin
                                scrup(position, total, start_date);
                        end;
                        writed := 0;
                end;
        end;
        truncate(f);
        close(f);
end;

function is_nil(r : dword) : boolean;
begin
        is_nil := r = 0;
end;

end.

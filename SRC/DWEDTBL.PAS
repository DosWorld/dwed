{ MIT License

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
SOFTWARE. }
unit dwedtbl;

interface

uses dwedtype, event;

function is_in_table(var ctx:TEditorContext; event:PEvent) : boolean;
function tbl_next_column(var ctx:TEditorContext; event:PEvent) : integer;
function tbl_prev_column(var ctx:TEditorContext; event:PEvent) : integer;
function tbl_append_row(var ctx:TEditorContext; event:PEvent) : integer;

implementation

uses kminput, scr, scrui, strs, strutil, dwedhl, dwedlnch, dwedutil;

const
tbl_column_chars  : string[2]  = '³º';
tbl_transl_chars1 : string[26] = 'ÃÅÂ´ÆÑµÚ¿ÕØ¸³ÌÎË¹ÇÒ×¶Ö·É»º';
tbl_transl_chars2 : string[26] = '³³³³³³³³³³³³³ººººººººººººº';

function is_in_table_str(var line : string) : boolean;
var     r         : boolean;
        fc, lc    : char;
        fcpos     : integer;
        lcpos     : integer;
        i         : integer;
begin
        r := false;
        fc := #0; lc := #0;
        i := 1;
        while (i <= ord(line[0])) and (line[i] = ' ') do inc(i);
        fcpos := i;
        i := ord(line[0]);
        while (i > 1) and (line[i] = ' ') do dec(i);
        lcpos := i;
        if (fcpos < lcpos) and ((fcpos + lcpos) > 2) then begin
                fc := line[fcpos];
                lc := line[lcpos];
        end;
        r := (pos(fc, tbl_column_chars) > 0) and (pos(lc, tbl_column_chars) > 0);
        is_in_table_str := r;
end;

function is_in_table(var ctx:TEditorContext; event:PEvent) : boolean;
begin
        is_in_table := is_in_table_str(ctx.current^.editor.line);
end;

function tbl_next_column(var ctx:TEditorContext; event:PEvent) : integer;
var     r, x    : integer;
        line    : string;
        i       : integer;
        nl      : EditorStr;
        nl_body : string;
begin
        r := SCRU_NONE;
        ctx.current^.editor.selection := false;
        line := ctx.current^.editor.line;
        x := ctx.current^.editor.x;
        i := ord(line[0]);
        while (i > 1) and (line[i] = ' ') do dec(i);
        while (x <= i) and (pos(line[x], tbl_column_chars) = 0) do inc(x);
        if x < i then begin
                ctx.current^.editor.x := x + 1;
                r := SCRU_CLINE;
        end else begin
                nl := strs.go_next(ctx.current^.cline);
                if nl <> nil then begin
                        get(nl, nl_body);
                        if is_in_table_str(nl_body) then begin
                                commit(ctx);
                                ctx.current^.cline := strs.go_next(ctx.current^.cline);
                                load_ed(ctx);
{                               if ctx.current^.scry <> ctx.current^.config^.height - 2
                                        then inc(ctx.current^.scry); }
                                x := 1;
                                while (x < ord(nl_body[0])) and (nl_body[x] = ' ') do inc(x);
                                if x < ord(nl_body[0]) then inc(x);
                                ctx.current^.editor.x := x;
                                r := SCRU_FULL;
                        end;
                end;
        end;
        tbl_next_column := r;
end;

function tbl_prev_column(var ctx:TEditorContext; event:PEvent) : integer;
var     r, x : integer;
        line : string;
        i    : integer;
        pl      : EditorStr;
        pl_body : string;
begin
        r := SCRU_NONE;
        ctx.current^.editor.selection := false;
        line := ctx.current^.editor.line;
        x := ctx.current^.editor.x;
        i := 1;
        while (i < ord(line[0])) and (line[i] = ' ') do inc(i);
        while (x >= i) and (pos(line[x], tbl_column_chars) = 0) do dec(x);
        dec(x);
        while (x >= i) and (pos(line[x], tbl_column_chars) = 0) do dec(x);
        if x >= i then begin
                ctx.current^.editor.x := x + 1;
                r := SCRU_CLINE;
        end else begin
                pl := strs.go_prev(ctx.current^.cline);
                if pl <> nil then begin
                        get(pl, pl_body);
                        if is_in_table_str(pl_body) then begin
                                commit(ctx);
                                ctx.current^.cline := strs.go_prev(ctx.current^.cline);
                                load_ed(ctx);
{                                if ctx.current^.scry <> 0 then dec(ctx.current^.scry); }
                                x := ord(pl_body[0]);
                                while (x > 1) and (pl_body[x] = ' ') do dec(x);
                                if x > 0 then dec(x);
                                while (x >= 1) and (pos(pl_body[x], tbl_column_chars) = 0) do begin
                                        dec(x);
                                end;
                                if x > 0 then begin
                                        inc(x);
                                        ctx.current^.editor.x := x + 1;
                                end;
                                r := SCRU_FULL;
                        end;
                end;
        end;
        tbl_prev_column := r;
end;

function tbl_append_row(var ctx:TEditorContext; event:PEvent) : integer;
var     r, x  : integer;
        oline : string;
        nline : string;
        i     : integer;
        c     : char;
        nl    : EditorStr;
        tail  : string;
begin
        r := SCRU_FULL;
        ctx.current^.editor.selection := false;
        oline := ctx.current^.editor.line;
        nline := oline;
        while (nline[0] <> #0) and (nline[ord(nline[0])] <= ' ') do Dec(nline[0]);
        oline := nline;
        for i:= 1 to ord(nline[0]) do begin
                x := pos(nline[i], tbl_transl_chars1);
                if x = 0 then c := ' ' else c:= tbl_transl_chars2[x];
                nline[i] := c;
        end;
        i := ctx.current^.editor.x;
        tail := '';
        while i < ord(nline[0]) do begin
                x := pos(nline[i], tbl_column_chars);
                if x > 0 then break;
                tail := tail + oline[i];
                oline[i] := ' ';
                inc(i);
        end;
        ctx.current^.editor.line := oline;
        ctx.current^.editor.chg := true;
        commit(ctx);

        x := ctx.current^.editor.x;
        while (nline[x] = ' ') and (x <> 0) do dec(x);
        inc(x);
        system.delete(nline, x, length(tail));
        insert(tail, nline, x);
        nl := strs.create(strs.go_next(ctx.current^.cline), ctx.current^.cline, nline);
        ctx.current^.total := strs.renum(ctx.current^.rline);
        ctx.current^.cline := strs.go_next(ctx.current^.cline);
        load_ed(ctx);
        ctx.current^.editor.line := nline;
        ctx.current^.editor.chg := true;
{        if ctx.current^.scry <> ctx.current^.config^.height - 2 then inc(ctx.current^.scry);}
        ctx.current^.editor.x := x;

        tbl_append_row := r;
end;

end.

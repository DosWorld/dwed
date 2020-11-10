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
unit dwedscru;

interface

uses dwedtype;

procedure update(var ctx : TEditorContext; scru : integer);

implementation

uses scr, kbd, strutil, strs, lfn, dwedhndl, dwedutil, dwedhl;

function line_full_in_sel(num : longint; y1 : longint; y2 : longint) : boolean;
begin
        line_full_in_sel := (num > y1) and (num < y2);
end;

procedure get_str_part(var ctx : TEditorContext; var s, res : string);
var len : integer;
begin
        len := length(s);
        if len < ctx.current^.scrx then res := '' else res := copy(s, ctx.current^.scrx + 1, len - ctx.current^.scrx);
        if ord(res[0]) > ctx.current^.config^.width then res := copy(res, 1, ctx.current^.config^.width);
end;

procedure update_full(var ctx : TEditorContext);
var h, w, i, x1, len   : integer;
        p              : EditorStr;
        s              : string;
        sb_y, se_y, clinenum : longint;
        sb_x, se_x     : integer;
        color          : byte;
        scrx           : integer;
        text_color     : byte;
        text_sel_color : byte;
        selection      : boolean;
begin
        h := ctx.current^.config^.height;
        w := ctx.current^.config^.width;
        p := ctx.current^.scrline;
        text_sel_color := ctx.current^.config^.color.text_sel;
        text_color := ctx.current^.config^.color.text;
        selection := ctx.current^.editor.selection;
        scrx := ctx.current^.scrx;

        get_sel_coord(ctx, sb_x, sb_y, se_x, se_y);

        for i := 1 to h - 1 do begin
                clinenum := strs.get_num(p);
                if selection and line_full_in_sel(clinenum, sb_y, se_y) then color := text_sel_color else color := text_color;
                strs.get(p, s);
                get_str_part(ctx, s, s);
                scr.cln(0, i, color);
                scr.print(0, i, color, s);
                if selection and ((sb_y = clinenum) or (se_y = clinenum)) then begin
                        if (sb_y = clinenum) and (sb_x - 1 <= scrx + w) then begin
                                x1 := sb_x - scrx - 1;
                                if x1 < w then begin
                                        len := w - x1;
                                        scr.chcolor(x1, i, text_sel_color, len);
                                end;
                        end else if (se_y = clinenum) and (se_x - 1 >= scrx) then begin
                                len := se_x - 1 - scrx;
                                if len > w then len := w;
                                scr.chcolor(0, i, text_sel_color, len);
                        end;
                end;
                hight_light(ctx.current^.st, w
                        , ctx.config.color.text_hl
                        , text_color
                        , @scr.screen[(w * i) shl 1]);
                p := strs.go_next(p);
        end;
end;

procedure update_cline(var ctx : TEditorContext);
var
        sb_y, se_y, clinenum : longint;
        sb_x, se_x     : integer;
        x, len         : integer;
        line           : string;
begin
        with ctx.current^ do begin
                scr.cln(0, scry + 1, config^.color.text);
                scr.locate(editor.x - 1 - scrx, scry + 1);
        end;
        get_str_part(ctx, ctx.current^.editor.line, line);
        scr.print(0, ctx.current^.scry + 1, ctx.current^.config^.color.text, line);

        if ctx.current^.editor.selection then begin
                get_sel_coord(ctx, sb_x, sb_y, se_x, se_y);
                clinenum := strs.get_num(ctx.current^.cline);
                len := -1;
                if (sb_y = se_y) and (clinenum = sb_y) then begin
                        if ( sb_x - 1 < ctx.current^.scrx + ctx.current^.config^.width)
                         and (se_x - 1 >= ctx.current^.scrx) then begin
                                x := sb_x - 1;
                                if x < ctx.current^.scrx then x := ctx.current^.scrx;
                                len := se_x - x - 1;
                                dec(x, ctx.current^.scrx);
                                if x + len > ctx.current^.config^.width then len := ctx.current^.config^.width - x;
                        end;
                end else if (clinenum = sb_y) then begin
                                x := sb_x - 1;
                                if x < ctx.current^.scrx + ctx.current^.config^.width then begin
                                        if x < ctx.current^.scrx then x := 0 else dec(x, ctx.current^.scrx);
                                        len := ctx.current^.config^.width - x;
                                end;
                end else if (clinenum = se_y) then begin
                        x := 0;
                        if se_x - 1 > ctx.current^.scrx then begin
                                len := se_x - 1 - ctx.current^.scrx;
                                if len > ctx.current^.config^.width then len := ctx.current^.config^.width;
                        end;
                end;
                if len > 0 then scr.chcolor(x, ctx.current^.scry + 1, ctx.current^.config^.color.text_sel, len);
        end;
        with ctx do begin
                hight_light(current^.st, config.width
                , config.color.text_hl
                , config.color.text
                , @scr.screen[(config.width * (current^.scry + 1)) shl 1]);
                hight_light_braket(config.width
                , current^.editor.x - 1 - current^.scrx
                , #$B2
                , @scr.screen[(config.width * (current^.scry + 1)) shl 1]);
        end;
end;

procedure update_top(var ctx : TEditorContext);
var ch, i       : char;
        endline : string;
        fname   : string;
        total   : string;
begin
        ch := ' ';
        i := 'O';
        if ctx.current^.chg or ctx.current^.editor.chg then ch := '*';
        if ctx.ins then i := 'I';
        total := ltoa(ctx.current^.total);
        endline := concat(
                lpad(itoa(ctx.current^.editor.x), 3), ' ',
                lpad(ltoa(strs.get_num(ctx.current^.cline)), length(total)),
                '/', total, ' ', ch, i,' ');   

        fname := ' ' + trim(ctx.current^.sfname);
        endline := lpad(endline, ctx.current^.config^.width - length(fname));

        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, fname + endline);
end;

procedure update(var ctx : TEditorContext; scru : integer);
begin
        if scru <> SCRU_NONE then begin
                if scru >= SCRU_FULL then update_full(ctx);
                if scru >= SCRU_CLINE then update_cline(ctx);
                if scru >= SCRU_TOP then update_top(ctx);

                if ctx.ins then scr.set_cursor(scr.cursor_start, scr.cursor_end)
                else scr.set_cursor(0, scr.cursor_end);

                scr.show;
        end;
end;

end.

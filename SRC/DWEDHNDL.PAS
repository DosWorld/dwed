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
unit dwedhndl;

interface

uses dwedtype, dwedhelp, event;

function process_event(var ctx : TEditorContext; var e : TEvent) : integer;

implementation

uses scr, kbd, scrui, lfn, strs, strutil, dwedscru, dwedutil, dwedaddo, dwedhl, dwedlnch;

{$F+}

const handlers : PEventHandler = nil;

{$F+}

procedure reg_handler(key : word; is_ctrl, is_shift, is_alt, reset_selection : boolean; proc : pointer);
var h : PEventHandler;
begin
        getmem(h, sizeof(TEventHandler));
        h^.next := handlers;
        h^.proc := proc;
        h^.reset_selection := reset_selection;
        h^.event.key := key;
        h^.event.is_ctrl := is_ctrl;
        h^.event.is_alt := is_alt;
        h^.event.is_shift := is_shift;
        handlers := h;
end;

function hk_default(var ctx : TEditorContext; event : PEvent) : integer;forward;

{$F-}
function compare_event(var e1, e2 : TEvent) : boolean;
begin
        compare_event := (hi(e1.key) = hi(e2.key))
                        and (e1.is_shift = e2.is_shift)
                        and (e1.is_alt = e2.is_alt)
                        and (e1.is_ctrl = e2.is_ctrl);
end;
{$F+}

function process_event(var ctx : TEditorContext; var e : TEvent) : integer;
var h : PEventHandler;
        r : integer;
        xofs : integer;
        proc : TEventProc;
begin
        r := SCRU_NONE;
        if e.etype = KEYBOARD then begin
                h := handlers;
                xofs := ctx.current^.scrx;
                while (h <> nil) do begin
                        if compare_event(e, h^.event) then begin
                                proc := TEventProc(h^.proc);
                                r := proc(ctx, @e);
                                if h^.reset_selection and ctx.current^.editor.selection then begin
                                        ctx.current^.editor.selection := false;
                                        r := SCRU_FULL;
                                end;
                                break;
                        end;
                        h := h^.next;
                end;
                if h = nil then r := hk_default(ctx, @e);
                r := norm_xy(ctx, r);
                if xofs <> ctx.current^.scrx then r := SCRU_FULL;
        end;
        process_event := r;
end;

{$F+}

function hk_up(var ctx : TEditorContext; event : PEvent) : integer;
begin
        hk_up := go_line_up(ctx);
end;

function hk_down(var ctx : TEditorContext; event : PEvent) : integer;
begin
        hk_down := go_line_down(ctx);
end;

function hk_left(var ctx : TEditorContext; event : PEvent):integer;
begin
        hk_left := go_char_left(ctx);
end;

function hk_right(var ctx : TEditorContext; event : PEvent):integer;
begin
        hk_right := go_char_right(ctx);
end;

function hk_pgup(var ctx : TEditorContext; event : PEvent):integer;
begin
        hk_pgup := go_page_up(ctx);
end;

function hk_pgdown(var ctx : TEditorContext; event : PEvent):integer;
begin
        hk_pgdown := go_page_down(ctx);
end;

function hk_home(var ctx:TEditorContext; event:PEvent):integer;
begin
        hk_home := go_line_begin(ctx);
end;

function hk_end(var ctx:TEditorContext; event:PEvent):integer;
begin
        hk_end := go_line_end(ctx);
end;

procedure check_begin_selection(var ctx:TEditorContext);
begin
        with ctx.current^ do begin
                with editor do begin
                        if selection then exit;
                        selection := true;
                        sel_x := x;
                end;
                commit(ctx);
                editor.sel_row := strs.get_num(cline);
        end;
end;

function hk_sup(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        check_begin_selection(ctx);
        r := go_line_up(ctx);
        if r = SCRU_NONE then r := SCRU_CLINE;
        hk_sup := r;
end;

function hk_sdown(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        check_begin_selection(ctx);
        r := go_line_down(ctx);
        if r = SCRU_NONE then r := SCRU_CLINE;
        hk_sdown := r;
end;

function hk_sleft(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        check_begin_selection(ctx);
        r := go_char_left(ctx);
        if r < SCRU_CLINE then r := SCRU_CLINE;
        hk_sleft := r;
end;

function hk_sright(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        check_begin_selection(ctx);
        r := go_char_right(ctx);
        if r < SCRU_CLINE then r := SCRU_CLINE;
        hk_sright := r;
end;

function hk_spgup(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        check_begin_selection(ctx);
        r := go_page_up(ctx);
        if r < SCRU_CLINE then r := SCRU_CLINE;
        load_ed(ctx);
        hk_spgup := r;
end;

function hk_spgdown(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        check_begin_selection(ctx);
        r := go_page_down(ctx);
        if r < SCRU_CLINE then r := SCRU_CLINE;
        hk_spgdown := r;
end;

function hk_shome(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        check_begin_selection(ctx);
        r := go_line_begin(ctx);
        if r < SCRU_CLINE then r := SCRU_CLINE;
        hk_shome := r;
end;

function hk_send(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        check_begin_selection(ctx);
        r := go_line_end(ctx);
        if r < SCRU_CLINE then r := SCRU_CLINE;
        hk_send := r;
end;

function hk_file_begin(var ctx:TEditorContext; event:PEvent):integer;
begin
        commit(ctx);
        with ctx.current^ do begin
                scrline := rline;
                cline := rline;
                scry := 0;
                scrx := 0;
                editor.x := 1;
        end;
        load_ed(ctx);
        hk_file_begin := SCRU_FULL;
end;

function hk_file_end(var ctx:TEditorContext; event:PEvent):integer;
begin
        commit(ctx);
        with ctx.current^ do begin
                while not strs.is_last(cline) do cline := strs.go_next(cline);
                scrline := cline;
                scry := 0;
                while not strs.is_first(scrline) and (scry < config^.height - 2) do begin
                        scrline := strs.go_prev(scrline);
                        inc(scry);
                end;
                scrx := 0;
                editor.x := 1;
        end;
        load_ed(ctx);
        hk_file_end := SCRU_FULL;
end;

function hk_ins(var ctx:TEditorContext; event:PEvent):integer;
begin
        ctx.ins := not ctx.ins;
        hk_ins := SCRU_CLINE;
end;

function hk_enter(var ctx:TEditorContext; event:PEvent):integer;
var s : string;
        i : integer;
        r : integer;
begin
        commit(ctx);
        if ctx.current^.editor.selection then begin
                delete_selected(ctx);
                with ctx.current^ do total := strs.renum(rline);
        end;
        r := SCRU_FULL;
        s := '';
        for i := 1 to length(ctx.current^.editor.line) do begin
                if ctx.current^.editor.line[i] = ' ' then s := s + ' ' else break;
        end;
        with ctx.current^ do begin
                cline := strs.split(cline, editor.x);
                if strs.is_first(cline) then rline := cline;
                if scry = 0 then scrline := cline;
                if scry <> config^.height - 2 then inc(scry);
                editor.x := 1;
                cline := strs.go_next(cline);
                total := strs.renum(rline);
                load_ed(ctx);
        end;
        if length(s) <> 0 then ctx.current^.editor.line := s + ltrim(ctx.current^.editor.line);
        ctx.current^.chg := true;
        ctx.current^.editor.chg := length(s) <> 0;
        ctx.current^.editor.x := length(s) + 1;
        ctx.current^.scrx := 0;
        hk_enter := r;
end;

function hk_esc(var ctx:TEditorContext; event:PEvent):integer;
var r          : integer;
       c       : PFileContext;
       srcctx  : PFileContext;
       errCode : integer;
begin
        r := SCRU_QUIT;
        commit(ctx);
        c := ctx.all;
        srcctx := ctx.current;
        while (c <> nil) and (r = SCRU_QUIT) do begin
                ctx.current := c;
                commit(ctx);
                if ctx.current^.chg then begin
                        dwedscru.update(ctx, SCRU_FULL);
                        with ctx.current^ do begin
                                scr.cln(0, 0, config^.color.top);
                                scr.printhl(1, 0, config^.color.top,
                                        config^.color.top_hl,
                                        'Do you want save "' + sfname + '" ? (~Y~/~N~/~C~)');
                        end;
                        scr.show;
                        case scrui.yes_no_cancel of
                        YES: begin
                                        with ctx.current^ do begin
                                                scr.cln(0, 0, config^.color.top);
                                                scr.print(1, 0, config^.color.top, 'Save "' + sfname + '"');
                                                scr.show;
                                                strs.to_file(fname, rline, errCode, @file_progress);
                                                r := SCRU_FULL;
                                                if errCode <> 0 then begin
                                                        handle_error(ctx, errCode);
                                                        break;
                                                end else chg := false;
                                        end;
                                end;
                        CANCEL: begin
                                        r := SCRU_FULL;
                                        break;
                                end;
                        NO:
                        end;
                end;
                c := c^.next;
        end;
        ctx.current := srcctx;
        hk_esc := r;
end;

function hk_save(var ctx:TEditorContext; event:PEvent):integer;
var    srcctx  : PFileContext;
       errCode : integer;
begin
        srcctx := ctx.current;
        commit(ctx);
        if event^.is_shift then begin
                ctx.current := ctx.all;
                while (ctx.current <> nil) do begin
                        commit(ctx);
                        with ctx.current^ do begin
                                if chg then begin
                                        scr.cln(0, 0, config^.color.top);
                                        scr.print(1, 0, config^.color.top, 'Save "' + sfname + '"');
                                        scr.show;
                                        strs.to_file(fname, rline, errCode, @file_progress);
                                        if errCode <> 0 then begin
                                                handle_error(ctx, errCode);
                                        end else chg := false;
                                end;
                        end;
                        ctx.current := ctx.current^.next;
                end;
        end else with ctx.current^ do begin
                scr.cln(0, 0, config^.color.top);
                scr.print(1, 0, config^.color.top, 'Save "' + sfname + '"');
                scr.show;
                strs.to_file(fname, rline, errCode, @file_progress);
                if errCode <> 0 then handle_error(ctx, errCode) else chg := false;
        end;
        ctx.current := srcctx;
        hk_save := SCRU_FULL;
end;


function hk_save_as(var ctx:TEditorContext; event:PEvent):integer;
var    errCode    : integer;
       newname    : string;
       key        : word;
       start_save : boolean;
       msg        : string;
begin
        commit(ctx);

        newname := ctx.current^.fname;
        msg := ' Save file to :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scr.show;
                key := scrui.editstr(length(msg) + 1, 0, ctx.current^.config^.color.top, newname, 32, 255);
                if key = K_ESC then begin start_save := false; break; end;
                if key = K_ENTER then begin start_save := true; break; end;
        end;
        if start_save then begin
                scr.cln(0, 0, ctx.current^.config^.color.top);
                scr.print(1, 0, ctx.current^.config^.color.top, 'Save "' + newname + '"');
                scr.show;
                strs.to_file(newname, ctx.current^.rline, errCode, @file_progress);
                if errCode <> 0 then handle_error(ctx, errCode) else ctx.current^.chg := false;
                if errCode = 0 then begin
                        ctx.current^.fname := newname;
                        ctx.current^.sfname := mk_short_name(newname);
                end;
        end;
        hk_save_as := SCRU_CLINE;
end;

function hk_dos_screen(var ctx:TEditorContext; event:PEvent):integer;
begin
        scr.pop;
        scr.show;
        kbd.reset;
        kbd.getkey;
        scr.push;
        hk_dos_screen := SCRU_FULL;
end;

function hk_bs(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
        s : string;
begin
        r := SCRU_NONE;
        if ctx.current^.editor.selection then begin
                commit(ctx);
                delete_selected(ctx);
                ctx.current^.total := strs.renum(ctx.current^.rline);
                r := SCRU_FULL;
        end else begin
                if ctx.current^.editor.x = 1 then begin
                        if not strs.is_first(ctx.current^.cline) then begin
                                commit(ctx);
                                ctx.current^.cline := strs.go_prev(ctx.current^.cline);
                                strs.get(ctx.current^.cline, s);
                                with ctx.current^ do begin
                                        cline := strs.merge(cline);
                                        if scry = 0 then scrline := cline
                                        else dec(scry);
                                        total := strs.renum(rline);
                                        chg := true;
                                end;
                                ctx.current^.editor.x := length(s) + 1;
                                load_ed(ctx);
                                r := SCRU_FULL;
                        end;
                end else begin
                        with ctx.current^ do begin
                                System.delete(editor.line, editor.x - 1, 1);
                                dec(editor.x);
                                editor.chg := true;
                        end;
                        r := SCRU_CLINE;
                end;
        end;
        hk_bs := r;
end;

function hk_del(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
begin
        r := SCRU_NONE;
        if ctx.current^.editor.selection then begin
                commit(ctx);
                delete_selected(ctx);
                ctx.current^.total := strs.renum(ctx.current^.rline);
                r := SCRU_FULL;
        end else begin
                if ctx.current^.editor.x > length(ctx.current^.editor.line) then begin
                        commit(ctx);
                        with ctx.current^ do begin
                                cline := strs.merge(cline);
                                if strs.is_first(cline) then rline := cline;
                                if scry = 0 then scrline := cline;
                                total := strs.renum(rline);
                                chg := true;
                        end;
                        load_ed(ctx);
                        r := SCRU_FULL;
                end else begin
                        with ctx.current^ do begin
                                System.delete(editor.line, editor.x, 1);
                                editor.chg := true;
                        end;
                        r := SCRU_CLINE;
                end;
        end;
        hk_del := r;
end;

function hk_cb_cut(var ctx:TEditorContext; event:PEvent):integer;
begin
        if ctx.current^.editor.selection then begin
                copy_selected(ctx);
                delete_selected(ctx);
                with ctx.current^ do total := strs.renum(rline);
                hk_cb_cut := SCRU_FULL;
        end else hk_cb_cut := SCRU_NONE;
end;

function hk_cb_cutline(var ctx:TEditorContext; event:PEvent):integer;
var clinenum : longint;
        r, x    : integer;
begin
        if (not ctx.current^.editor.selection) and (not strs.is_last(ctx.current^.cline)) then begin
                commit(ctx);
                clinenum := strs.get_num(ctx.current^.cline);
                x := ctx.current^.editor.x;
                go_line_begin(ctx);
                go_line_down(ctx);
                with ctx.current^.editor do begin
                        selection := true;
                        sel_x := 1;
                end;
                ctx.current^.editor.sel_row := clinenum;
                r := hk_cb_cut(ctx, event);
                ctx.current^.editor.x := x;
        end else r := SCRU_NONE;
        hk_cb_cutline := r;
end;

function hk_cb_copy(var ctx:TEditorContext; event:PEvent):integer;
begin
        if ctx.current^.editor.selection then copy_selected(ctx);
        hk_cb_copy := SCRU_NONE;
end;

function hk_cb_paste(var ctx:TEditorContext; event:PEvent):integer;
begin
        commit(ctx);
        if ctx.current^.editor.selection then begin
                delete_selected(ctx);
                ctx.current^.total := strs.renum(ctx.current^.rline);
                ctx.current^.editor.selection := false;
        end;
        ctx.current^.cline := strs.append(ctx.current^.cline, ctx.current^.editor.x, ctx.clipboard);
        with ctx.current^ do begin
                if scry = 0 then scrline := cline;
                if strs.is_first(cline) then rline := cline else rline := strs.go_first(cline);
                total := strs.renum(rline);
                chg := true;
        end;
        load_ed(ctx);
        kbd.reset;
        hk_cb_paste := SCRU_FULL;
end;

function hk_goto_line(var ctx:TEditorContext; event:PEvent):integer;
var r          : integer;
    lNumStr    : string;
    msg        : string;
    lnum       : longint;
    newLine    : EditorStr;
    key        : word;
    start_find : boolean;
begin
        r := SCRU_CLINE;
        lnum := 0;
        lNumStr := '';
        msg := ' Goto line (1-'+ltoa(ctx.current^.total)+') :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                key := scrui.editstr(length(msg) + 1, 0, ctx.current^.config^.color.top, lNumStr, 12, 12);
                if key = K_ESC then begin start_find := false; break; end;
                if key = K_ENTER then begin start_find := true; break; end;
        end;
        if start_find then begin
                lnum := atol(lNumStr, -1);
                if (lnum < 1) or (lnum > ctx.current^.total) then start_find := false;
        end;
        if start_find then begin
                newLine := strs.find_num(ctx.current^.rline, lnum);
                if newLine <> nil then begin
                        commit(ctx);
                        ctx.current^.cline := newLine;
                        load_ed(ctx);
                        r := SCRU_FULL;
                end;
        end;
        hk_goto_line := r;
end;

function hk_word_left(var ctx:TEditorContext; event:PEvent):integer;
begin
        hk_word_left := go_word_left(ctx);
end;

function hk_word_right(var ctx:TEditorContext; event:PEvent):integer;
begin
        hk_word_right := go_word_right(ctx);
end;

function hk_word_sleft(var ctx:TEditorContext; event:PEvent):integer;
begin
        check_begin_selection(ctx);
        hk_word_sleft := go_word_left(ctx);
end;

function hk_word_sright(var ctx:TEditorContext; event:PEvent):integer;
begin
        check_begin_selection(ctx);
        hk_word_sright := go_word_right(ctx);
end;

function hk_tab(var ctx:TEditorContext; event:PEvent):integer;
var i, r : integer;
        sb_y, se_y, clinenum : longint;
        sb_x, se_x : integer;
        line       : EditorStr;
        content    : string;
begin
        r := SCRU_NONE;
        if ctx.current^.editor.selection then begin
                get_sel_coord(ctx, sb_x, sb_y, se_x, se_y);
                if se_x = 1 then dec(se_y);
                commit(ctx);
                clinenum := strs.get_num(ctx.current^.cline);
                while sb_y <= se_y do begin
                        line := strs.find_num(ctx.current^.rline, sb_y);
                        if line <> nil then begin
                                strs.get(line, content);
                                i := 1;
                                while (i <= ctx.current^.config^.tab_size) and (length(content) <> 255) do begin
                                        content := ' ' + content;
                                        ctx.current^.chg := true;
                                        inc(i);
                                end;
                                line := strs.put(line, content);
                                if strs.is_first(line) then ctx.current^.rline := line;
                                if sb_y = clinenum then ctx.current^.cline := line;
                        end;
                        inc(sb_y);
                end;
                load_ed(ctx);
                r := SCRU_FULL;
        end else begin
                with event^ do begin
                        key := $20;
                        is_shift := false;
                        is_ctrl := false;
                        is_alt := false;
                end;
                for i := 1 to ctx.current^.config^.tab_size do hk_default(ctx, event);
                ctx.current^.editor.chg := true;
                r := SCRU_CLINE;
        end;
        hk_tab := r;
end;

function hk_shift_tab(var ctx:TEditorContext; event:PEvent):integer;
var i, r : integer;
        sb_y, se_y, clinenum : longint;
        sb_x, se_x : integer;
        line       : EditorStr;
        content    : string;
begin
        r := SCRU_NONE;
        if ctx.current^.editor.selection then begin
                get_sel_coord(ctx, sb_x, sb_y, se_x, se_y);
                if se_x = 1 then dec(se_y);
                commit(ctx);
                clinenum := strs.get_num(ctx.current^.cline);
                while sb_y <= se_y do begin
                        line := strs.find_num(ctx.current^.rline, sb_y);
                        if line <> nil then begin
                                strs.get(line, content);
                                i := 1;
                                while (i <= ctx.current^.config^.tab_size) and (length(content) <> 0) do begin
                                        if content[1] <> ' ' then break;
                                        System.delete(content, 1, 1);
                                        ctx.current^.chg := true;
                                        inc(i);
                                end;
                                line := strs.put(line, content);
                                if strs.is_first(line) then ctx.current^.rline := line;
                                if sb_y = clinenum then ctx.current^.cline := line;
                        end;
                        inc(sb_y);
                end;
                load_ed(ctx);
                r := SCRU_FULL;
        end else begin
                i := ctx.current^.config^.tab_size;
                while (i > 0)
                 and (ctx.current^.editor.line[1] = ' ')
                 and (length(ctx.current^.editor.line) > 0) do begin
                        System.delete(ctx.current^.editor.line, 1, 1);
                        ctx.current^.editor.chg := true;
                        if ctx.current^.editor.x <> 1 then dec(ctx.current^.editor.x);
                        dec(i);
                end;
                r := SCRU_CLINE;
        end;
        hk_shift_tab := r;
end;

function hk_default(var ctx:TEditorContext; event:PEvent):integer;
var r, len      : integer;
        c       : char;
        changed : boolean;
begin
        r := SCRU_NONE;
        c := chr(lo(event^.key));
        changed := false;
        len := length(ctx.current^.editor.line);

        if event^.is_ctrl then c:=#0;
        if event^.is_alt then c:=#0;

        if (c >= ' ') then begin
                r := SCRU_CLINE;
                if ctx.current^.editor.selection then begin
                        delete_selected(ctx);
                        with ctx.current^ do total := strs.renum(rline);
                        r := SCRU_FULL;
                end;
                if (len + 1 = ctx.current^.editor.x) and (len <> 255) then begin
                               ctx.current^.editor.line := ctx.current^.editor.line + c;
                        changed := true;
                end else if ctx.ins and (len < 255) then begin
                        insert('' + c, ctx.current^.editor.line, ctx.current^.editor.x);
                        changed := true;
                end else if (ctx.current^.editor.x <= length(ctx.current^.editor.line)) and (not ctx.ins) then begin
                        ctx.current^.editor.line[ctx.current^.editor.x] := c;
                        changed := true;
                end;
        end;
        if changed then with ctx.current^ do begin
                       editor.chg := true;
                       inc(editor.x);
        end else r := SCRU_NONE;
        hk_default := r;
end;

function hk_find_again(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
        start_col   : integer;
        line        : EditorStr;
        lineStr     : string;
        position    : integer;
        searchText  : string;
        is_replace  : boolean;
        msg         : string;
begin
        r := SCRU_CLINE;
        commit(ctx);
        ctx.search := trim(ctx.search);
        line := ctx.current^.cline;
        start_col := ctx.current^.editor.x;
        searchText := ctx.search;
        is_replace := length(ctx.replace) <> 0;
        if not ctx.searchCaseSens then searchText := upstr(searchText);
        while line <> nil do begin
                strs.get(line, lineStr);
                if not ctx.searchCaseSens then lineStr := upstr(lineStr);
                position := pos(searchText, copy(lineStr, start_col, length(lineStr) - start_col + 1));
                if position <>0 then begin
                        ctx.current^.cline := line;
                        ctx.current^.scrx := 0;
                        ctx.current^.editor.x := start_col + position - 1;
                        if not is_replace then inc(ctx.current^.editor.x, length(searchText));
                        load_ed(ctx);
                        r := SCRU_FULL;
                        break;
                end;
                start_col := 1;
                line := strs.go_next(line);
        end;
        if line = nil then begin
                scr.push;
                scrui.msg_box(ctx.current^.config^.color.top, 'Search / Replace', 'Substring not found.', '[ OK ]');
                scr.show;
                kbd.reset;
                kbd.getkey;
                scr.pop;
                r := SCRU_FULL;
        end else if is_replace then begin
                norm_xy(ctx, SCRU_FULL);
                load_ed(ctx);
                ctx.current^.editor.selection := true;
                ctx.current^.editor.sel_row := strs.get_num(ctx.current^.cline);
                ctx.current^.editor.sel_x := ctx.current^.editor.x + length(searchText);
                dwedscru.update(ctx, SCRU_FULL);
                msg := ' Replace it? (~Y~/~N~)';
                scr.cln(0, 0, ctx.current^.config^.color.top);
                scr.printhl(0, 0, ctx.current^.config^.color.top,
                         ctx.current^.config^.color.top_hl,
                         msg);
                scr.show;
                case scrui.yes_no of
                YES: begin
                                System.delete(ctx.current^.editor.line
                                        , ctx.current^.editor.x
                                        , length(searchText));
                                System.insert(ctx.replace
                                        , ctx.current^.editor.line
                                        , ctx.current^.editor.x);
                                ctx.current^.editor.chg := true;
                                inc(ctx.current^.editor.x, length(ctx.replace));
                        end;
                NO: begin
                                inc(ctx.current^.editor.x, length(searchText));
                        end;
                end;
                r := SCRU_FULL;
                ctx.current^.editor.selection := false;
        end;
        hk_find_again := r;
end;

function hk_start_find(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
        sb_y, se_y, clinenum : longint;
        sb_x, se_x     : integer;
        msg            : string;
        searchStr      : string;
        replaceStr     : string;
        start_find     : boolean;
        key            : word;
        searchCaseSens : boolean;
begin
        searchCaseSens := event^.is_shift;
        if ctx.current^.editor.selection then begin
                get_sel_coord(ctx, sb_x, sb_y, se_x, se_y);
                clinenum := strs.get_num(ctx.current^.cline);
                if (clinenum = sb_y) and (clinenum = se_y) then begin
                        ctx.search := trim(copy(ctx.current^.editor.line, sb_x, se_x - sb_x));
                end;
        end;
        r := SCRU_CLINE;
        searchStr := ctx.search;
        replaceStr := ctx.replace;
        if searchCaseSens then msg := ' Search (case-sens) :'
        else msg := ' Search (case-insens) :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0,ctx.current^.config^.color.top, msg); 
        scr.show;
        while true do begin
                key := scrui.editstr(length(msg) + 1, 0, ctx.current^.config^.color.top, searchStr, 32, 64);
                if key = K_ESC then begin start_find := false; break; end;
                if key = K_ENTER then begin start_find := true; break; end;
        end;
        searchStr := trim(searchStr);
        if length(searchStr) = 0 then start_find := false;
        if start_find then begin
                msg := ' Replace with :';
                scr.cln(0, 0, ctx.current^.config^.color.top);
                scr.print(0, 0, ctx.current^.config^.color.top, msg);
                while true do begin
                        key := scrui.editstr(length(msg) + 1, 0, ctx.current^.config^.color.top, replaceStr, 32, 64);
                        if key = K_ESC then begin start_find := false; break; end;
                        if key = K_ENTER then begin break; end;
                end;
        end;
        if start_find then begin
                ctx.search := searchStr;
                ctx.searchCaseSens := searchCaseSens;
                ctx.replace := trim(replaceStr);
                r := hk_find_again(ctx, event);
        end;
        hk_start_find := r;
end;

function hk_help(var ctx:TEditorContext; event:PEvent):integer;
begin
        with ctx do dwed_help(help_topic_id, 
                        config.color.help_menu,
                        config.color.help_menu_sel,
                        config.color.help,
                        config.color.help_hl);
        kbd.reset;
        hk_help := SCRU_FULL;
end;

function hk_nextwin(var ctx:TEditorContext; event:PEvent):integer;
begin
        commit(ctx);
        with ctx do begin
                current := current^.next;
                if current = nil then current := all;
        end;
        hk_nextwin := SCRU_FULL;
end;

function hk_winlist(var ctx:TEditorContext; event:PEvent):integer;
begin
        commit(ctx);
        go_win_list(ctx);
        hk_winlist := SCRU_FULL;
end;

function hk_cb_save(var ctx:TEditorContext; event:PEvent):integer;
var fname : string;
        msg        : string;
        start_save : boolean;
        key        : word;
        errCode    : integer;
begin
        commit(ctx);
        fname := '';
        msg := ' Save clipboard to file :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scr.show;
                key := scrui.editstr(length(msg) + 1, 0, ctx.current^.config^.color.top, fname, 32, 255);
                if key = K_ESC then begin start_save := false; break; end;
                if key = K_ENTER then begin start_save := true; break; end;
        end;
        if start_save then begin
                errCode := save_clipboard(ctx, fname);
                if errCode <> 0 then handle_error(ctx, errCode);
        end;
        hk_cb_save := SCRU_CLINE;
end;

function hk_cb_load(var ctx:TEditorContext; event:PEvent):integer;
var fname : string;
        msg        : string;
        start_load : boolean;
        key        : word;
        errCode    : integer;
begin
        commit(ctx);
        fname := '';
        msg := ' Load clipboard from file :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scr.show;
                key := scrui.editstr(length(msg) + 1, 0, ctx.current^.config^.color.top, fname, 32, 255);
                if key = K_ESC then begin start_load := false; break; end;
                if key = K_ENTER then begin start_load := true; break; end;
        end;
        errCode := 0;
        if start_load then load_clipboard(ctx, fname);
        if errCode <> 0 then handle_error(ctx, errCode);
        hk_cb_load := SCRU_CLINE;
end;

function hk_change_hl(var ctx:TEditorContext; event:PEvent):integer;
begin
        dwedhl.change_hl(ctx.current^.st, ctx.config.color.menu, ctx.config.color.menu_sel);
        hk_change_hl := SCRU_FULL;
end;

function hk_addons(var ctx:TEditorContext; event:PEvent):integer;
begin
        commit(ctx);
        addons_window(ctx);
        hk_addons := SCRU_FULL;
end;


function hk_close(var ctx:TEditorContext; event:PEvent):integer;
var canclose:boolean;
        r, next, prev : PFileContext;
        msg     : string;
        res     : integer;
        errCode : integer;
begin
        res := SCRU_FULL;
        commit(ctx);
        canclose := false;
        if ctx.current^.chg then msg := 'Do you want save and close "' + ctx.current^.sfname + '" ? (~Y~/~N~)' 
        else msg := 'Do you want close "' + ctx.current^.sfname + '" ? (~Y~/~N~)';

        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.printhl(1, 0, ctx.current^.config^.color.top,
                ctx.current^.config^.color.top_hl, msg); 
        scr.show;
        case scrui.yes_no of
        YES: begin
                if ctx.current^.chg then begin
                        with ctx.current^ do begin
                                scr.cln(0, 0, config^.color.top);
                                scr.print(1, 0, config^.color.top, 'Save "' + sfname + '"');
                                scr.show;
                                strs.to_file(fname, rline, errCode, @file_progress);
                                if errCode <> 0 then begin
                                        handle_error(ctx, errCode);
                                        canclose := false;
                                end else begin chg := false; canclose := true; end;
                        end;
                end else canclose := true;
            end;
        NO: begin canclose := false; end
        end;

        if canclose then begin
                next := ctx.current^.next;
                prev := nil;
                r := ctx.all;
                while r <> nil do begin
                        if r^.next = ctx.current then begin
                                prev := r;
                                break;
                        end;
                        r := r^.next;
                end;
                r := ctx.current;
                strs.free(r^.rline);
                freemem(r, sizeof(TFileContext));
                if prev <> nil then prev^.next := next else ctx.all := next;
                if next = nil then next := ctx.all;
                ctx.current := next;
                if ctx.all = nil then res := SCRU_QUIT else load_ed(ctx);
        end;
        hk_close := res;
end;

function hk_load(var ctx:TEditorContext; event:PEvent):integer;
var r : integer;
        msg        : string;
        fname      : string;
        key        : word;
        start_load : boolean;
        errCode    : integer;
begin
        commit(ctx);
        r := SCRU_CLINE;
        fname := '';
        msg := ' Load file :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scr.show;
                key := scrui.editstr(length(msg) + 1, 0, ctx.current^.config^.color.top, fname, 32, 255);
                if key = K_ESC then begin start_load := false; break; end;
                if key = K_ENTER then begin start_load := true; break; end;
        end;
        if start_load then begin
                load_file(ctx, fname, errCode, @file_progress);
                if errCode <> 0 then handle_error(ctx, errCode);
                r := SCRU_FULL;
        end;
        hk_load := r;
end;

function hk_asciitbl(var ctx:TEditorContext; event:PEvent):integer;
begin
        ascii_table(ctx);
        hk_asciitbl := SCRU_FULL;
end;

function hk_calc(var ctx:TEditorContext; event:PEvent):integer;
begin
        calculator(ctx);
        hk_calc := SCRU_FULL;
end;

procedure serialize_fctx(var t:text; current:PFileContext);
begin
        if current = nil then exit;
        if current^.next <> nil then serialize_fctx(t, current^.next);
        writeln(t, current^.editor.x,
        ',', current^.scrx, 
        ',', current^.scry, 
        ',', strs.get_num(current^.cline),
        ',', current^.fname 
        );
end;

function hk_userdef(var ctx:TEditorContext; event:PEvent):integer;
var     cmd       : string;
        r         : integer;
        f         : file;
        t         : text;
        writed    : word;
        can_run   : boolean;
        srcctx    : PFileContext;
        errCode   : integer;
begin
        cmd := '';
        r := SCRU_NONE;
        can_run := true;
        case event^.key of
        K_F5: cmd := ctx.config.udef_f5;
        K_F8: cmd := ctx.config.udef_f8;
        K_F9: cmd := ctx.config.udef_f9;
        end;
        cmd := trim(cmd);
        if length(cmd) = 0 then can_run := false;

        if can_run then begin
                srcctx := ctx.current;
                ctx.current := ctx.all;
                while (ctx.current <> nil) do begin
                        commit(ctx);
                        if ctx.current^.chg then begin
                                scr.cln(0, 0, ctx.config.color.top);
                                scr.printhl(1, 0,
                                        ctx.config.color.top,
                                        ctx.config.color.top_hl,
                                        'You have ~unsaved~ file "~' + ctx.current^.sfname + '~"'
                                        );
                                scr.show;
                                can_run := false;
                                break;
                        end;
                        ctx.current := ctx.current^.next;
                end;
                ctx.current := srcctx;
        end;

        if can_run then begin
                lfn.assign_text(t, ctx.temp);
                rewrite(t);
                errCode := ioresult;
                if errCode <> 0 then begin handle_error(ctx, errCode); can_run := false; end else begin
                        serialize_fctx(t, ctx.all);
                        close(t);
                end;
        end;

        if can_run then begin
                while (ctx.all <> nil) do begin
                        strs.free(ctx.all^.rline);
                        ctx.all^.rline := nil;
                        ctx.all^.cline := nil;
                        srcctx := ctx.all;
                        ctx.all := ctx.all^.next;
                        freemem(srcctx, sizeof(TFileContext));
                end;
        end;

        if can_run then begin 
                System.assign(f, dwedlnch.DEVFILE);
                rewrite(f, 1);
                errCode := ioresult;
                if errCode <> 0 then begin handle_error(ctx, errCode); can_run := false; end else begin
                        blockwrite(f, cmd[0], length(cmd) + 1, writed);
                        close(f);
                        ctx.exit_code := 254;
                end;
        end;
        if can_run then r := SCRU_QUIT;
        hk_userdef := r;
end;

begin
        reg_handler(K_ESC, false, false, false, false, @hk_esc);
        reg_handler(K_ALT_F10, false, false, true, false, @hk_addons);
        reg_handler(K_CTRL_ALT_A, true, false, true, false, @hk_asciitbl);
        reg_handler(K_CTRL_ALT_C, true, false, true, false, @hk_calc);
        reg_handler(K_CTRL_ALT_H, true, false, true, false, @hk_change_hl);
        reg_handler(K_SHIFT_F2, false, true, false, false, @hk_save_as);

        reg_handler(K_F1, false, false, false, false, @hk_help);
        reg_handler(K_F2, false, false, false, false, @hk_save);
        reg_handler(K_F3, false, false, false, false, @hk_load);
        reg_handler(K_F5, false, false, false, false, @hk_userdef);
        reg_handler(K_F6, false, false, false, false, @hk_nextwin);
        reg_handler(K_F7, false, false, false, true, @hk_start_find);
        reg_handler(K_F8, false, false, false, false, @hk_userdef);
        reg_handler(K_F9, false, false, false, false, @hk_userdef);

        reg_handler(K_ALT_F2, false, false, true, false, @hk_cb_save);
        reg_handler(K_ALT_F3, false, false, true, false, @hk_cb_load);
        reg_handler(K_ALT_F4, false, false, true, false, @hk_close);
        reg_handler(K_ALT_F5, false, false, true, false, @hk_dos_screen);
        reg_handler(K_ALT_F6, false, false, true, false, @hk_winlist);

        reg_handler(K_CTRL_LEFT, true, false, false, true, @hk_word_left);
        reg_handler(K_CTRL_RIGHT, true, false, false, true, @hk_word_right);

        reg_handler(K_CTRL_LEFT, true, true, false, false, @hk_word_sleft);
        reg_handler(K_CTRL_RIGHT, true, true, false, false, @hk_word_sright);

        reg_handler(K_TAB, false, false, false, false, @hk_tab);
        reg_handler(K_SHIFT_TAB, false, true, false, false, @hk_shift_tab);

        reg_handler(K_SHIFT_UP, false, true, false, false, @hk_sup);
        reg_handler(K_SHIFT_DOWN, false, true, false, false, @hk_sdown);
        reg_handler(K_SHIFT_LEFT, false, true, false, false, @hk_sleft);
        reg_handler(K_SHIFT_RIGHT, false, true, false, false, @hk_sright);
        reg_handler(K_SHIFT_PGUP, false, true, false, false, @hk_spgup);
        reg_handler(K_SHIFT_PGDN, false, true, false, false, @hk_spgdown);
        reg_handler(K_SHIFT_HOME, false, true, false, false, @hk_shome);
        reg_handler(K_SHIFT_END, false, true, false, false, @hk_send);

        reg_handler(K_UP, false, false, false, true, @hk_up);
        reg_handler(K_DOWN, false, false, false, true, @hk_down);
        reg_handler(K_LEFT, false, false, false, true, @hk_left);
        reg_handler(K_RIGHT, false, false, false, true, @hk_right);
        reg_handler(K_PGUP, false, false, false, true, @hk_pgup);
        reg_handler(K_PGDN, false, false, false, true, @hk_pgdown);
        reg_handler(K_HOME, false, false, false, true, @hk_home);
        reg_handler(K_END, false, false, false, true, @hk_end);
        reg_handler(K_CTRL_HOME, true, false, false, true, @hk_file_begin);
        reg_handler(K_CTRL_END, true, false, false, true, @hk_file_end);

        reg_handler(K_DEL, false, false, false, false, @hk_del);
        reg_handler(K_BS, false, false, false, false, @hk_bs);
        reg_handler(K_ENTER, false, false, false, false, @hk_enter);

        reg_handler(K_CTRL_S, true, false, false, true, @hk_save);
        reg_handler(K_CTRL_S, true, true, false, true, @hk_save);
        reg_handler(K_INS, false, false, false, false, @hk_ins);

        reg_handler(K_CTRL_X, true, false, false, false, @hk_cb_cut);
        reg_handler(K_CTRL_C, true, false, false, false, @hk_cb_copy);
        reg_handler(K_CTRL_V, true, false, false, false, @hk_cb_paste);

        reg_handler(K_CTRL_Y, true, false, false, false, @hk_cb_cutline);
        reg_handler(K_CTRL_U, true, false, false, false, @hk_cb_paste);

        reg_handler(K_CTRL_L, true, false, false, true, @hk_goto_line);
        reg_handler(K_CTRL_F, true, false, false, true, @hk_start_find);
        reg_handler(K_CTRL_F, true, true, false, true, @hk_start_find);
        reg_handler(K_CTRL_K, true, false, false, true, @hk_find_again);

        reg_handler(K_INS, false, true, false, false, @hk_cb_paste);
        reg_handler(K_DEL, false, true, false, false, @hk_cb_cut);
end.

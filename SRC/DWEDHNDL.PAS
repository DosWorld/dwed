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
unit dwedhndl;

interface

uses dwedtype, dwedhelp, event;

function process_event(var ctx : TEditorContext; var e : TEvent) : integer;

implementation

uses scr, kbd, scrui, strs, strutil, dwedscru, dwedutil, dwedaddo, dwedhl, dwedlnch, system2, wincb, dwedtbl;

{$F+}const handlers : PEventHandler = nil;{$F+}

procedure reg_handler(scancode : byte; is_ctrl, is_shift, is_alt, reset_selection : boolean; proc : pointer);
var h : PEventHandler;
begin
        getmem(h, sizeof(TEventHandler));
        h^.next := handlers;
        h^.proc := proc;
        h^.reset_selection := reset_selection;
        h^.event.scancode := scancode;
        h^.event.is_ctrl := is_ctrl;
        h^.event.is_alt := is_alt;
        h^.event.is_shift := is_shift;
        handlers := h;
end;

function hk_default(var ctx : TEditorContext; event : PEvent) : integer;forward;
function handle_mouse(var ctx : TEditorContext; event : PEvent) : integer;forward;
procedure check_begin_selection(var ctx:TEditorContext);forward;
function hk_cb_paste(var ctx:TEditorContext; event:PEvent):integer;forward;
function hk_cb_copy(var ctx:TEditorContext; event:PEvent):integer;forward;
function hk_cb_cut(var ctx:TEditorContext; event:PEvent):integer;forward;

{$F-}
function compare_event(var e1, e2 : TEvent) : boolean;
begin
        compare_event := (e1.scancode = e2.scancode)
                        and (e1.is_shift = e2.is_shift)
                        and (e1.is_alt = e2.is_alt)
                        and (e1.is_ctrl = e2.is_ctrl);
end;
{$F+}

function process_event(var ctx : TEditorContext; var e : TEvent) : integer;
var     h    : PEventHandler;
        r    : integer;
        xofs : integer;
        proc : TEventProc;
begin
        r := SCRU_NONE;
        if (e.etype = KEYBOARD) then begin
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
                if xofs <> ctx.current^.scrx then r := SCRU_FULL;
        end else if e.etype in [MOUSE_MOVE,
                MOUSE_PRESS_B1, MOUSE_PRESS_B2,
                MOUSE_RELEASE_B1, MOUSE_RELEASE_B2 ] then begin
                r := handle_mouse(ctx, @e);
        end;
        if r <> SCRU_NONE then r := norm_xy(ctx, r);
        process_event := r;
end;

{$F+}
function goto_mouse(var ctx : TEditorContext; event : PEvent) : integer;
var  r, step, steps : integer;
     line           : EditorStr;
begin
        commit(ctx);
        dec(event^.mouse_y);
        if ctx.current^.scry > event^.mouse_y then step := -1 else step := 1;
        steps := 0;
        while ctx.current^.scry <> event^.mouse_y do begin
                if step < 1 then line := strs.go_prev(ctx.current^.cline)
                else line := strs.go_next(ctx.current^.cline);
                if line = nil then break;
                inc(steps);
                ctx.current^.cline := line;
                inc(ctx.current^.scry, step);
        end;
        ctx.current^.editor.x := event^.mouse_x + ctx.current^.scrx + 1;
        if steps = 0 then r := SCRU_CLINE else begin
                load_ed(ctx);
                r := SCRU_FULL;
        end;
        goto_mouse := r;
end;

const
MM_T1 : string[8] = ' Paste ' + #0;
MM_T2 : string[24] = ' Cut '+#$0a+' Copy ' + #0;
MM_T3 : string[24] = ' Cut '+#$0a+' Copy '+#$0a+' Paste ' + #0;

function handle_mouse(var ctx : TEditorContext; event : PEvent) : integer;
var  r, mt, x, y : integer;
     menu        : string;
     have_cb     : boolean;
     key         : word;
     selItem     : integer;
begin
        r := SCRU_NONE;
        if event^.etype = MOUSE_PRESS_B1 then begin
                commit(ctx);
                if (ctx.current^.editor.selection) then begin 
                        r := goto_mouse(ctx, event);
                        ctx.current^.editor.selection := false;
                        r := SCRU_FULL;
                end else begin
                        if event^.is_shift then begin
                                check_begin_selection(ctx);
                                r := goto_mouse(ctx, event);
                                r := SCRU_FULL;
                        end else begin
                                r := goto_mouse(ctx, event);
                        end;
                end;
        end else if (event^.etype = MOUSE_MOVE) and event^.mouse_left then begin
                if not ctx.current^.editor.selection then begin
                        check_begin_selection(ctx);
                end else begin
                        r := goto_mouse(ctx, event);
                        r := SCRU_FULL;
                end;
        end else if event^.etype = MOUSE_PRESS_B2 then begin
                mt := -1;
                have_cb := strlen(ctx.clipboard) <> 0;
                if ctx.current^.editor.selection then begin
                        if have_cb then begin
                                menu := MM_T3;
                                mt := 3;
                        end else begin
                                menu := MM_T2;
                                mt := 2;
                        end;
                end else if have_cb then begin
                        menu := MM_T1;
                        mt := 1;
                end;
                if mt > 0 then begin
                        selItem := 0;
                        x := event^.mouse_x; y := event^.mouse_y;
                        if y + 5 > ctx.config.height then y := ctx.config.height - 5;
                        if x + 10 > ctx.config.width then x := ctx.config.width - 10;
                        while true do begin
                                vmenu(event^, x, y, 10, mt + 2,
                                        ctx.config.color.menu,
                                        ctx.config.color.menu_sel,
                                        '', @menu[1], selItem);
                                with event^ do begin
                                        if etype in [MOUSE_PRESS_B1, MOUSE_PRESS_B2] then begin selItem := -1; break; end;
                                        if etype <> KEYBOARD then continue;
                                        if scancode = SCAN_ESC then break;
                                        if scancode = SCAN_ENTER then break;
                                end;
                        end;
                        if event^.scancode = SCAN_ENTER then begin
                                if ((mt = 1) and (selItem = 0))
                                or ((mt = 3) and (selItem = 2))
                                then begin
                                        hk_cb_paste(ctx, event)
                                end else if ((mt = 2) and (selItem = 0))
                                or ((mt = 3) and (selItem = 0))
                                then begin
                                        hk_cb_cut(ctx, event)
                                end else if ((mt = 2) and (selItem = 1))
                                or ((mt = 3) and (selItem = 1))
                                then begin
                                        hk_cb_copy(ctx, event)
                                end;
                        end;
                        r := SCRU_FULL;
                end;
        end;
        handle_mouse := r;
end;

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
                scrx := 0;
                scry := config^.height - 2;
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
var     s    : string;
        i, r : integer;
begin
        r := SCRU_FULL;
        commit(ctx);
        if is_in_table(ctx, event) then r := tbl_append_row(ctx, event) else begin
                if ctx.current^.editor.selection then begin
                        delete_selected(ctx);
                        with ctx.current^ do total := strs.renum(rline);
                end;
                s := '';
                with ctx.current^ do begin
                        for i := 1 to length(editor.line) do begin
                                if editor.line[i] = ' ' then s := s + ' ' else break;
                        end;
                        cline := strs.split(cline, editor.x);
                        if strs.is_first(cline) then rline := cline;
                        if scry <> config^.height - 2 then inc(scry);
                        editor.x := 1;
                        cline := strs.go_next(cline);
                        total := strs.renum(rline);
                        load_ed(ctx);
                        if length(s) <> 0 then editor.line := s + ltrim(editor.line);
                        chg := true;
                        editor.chg := length(s) <> 0;
                        editor.x := length(s) + 1;
                        scrx := 0;
                end;
        end;
        hk_enter := r;
end;

function hk_esc(var ctx:TEditorContext; event:PEvent):integer;
var    r, errCode : integer;
       c, srcctx  : PFileContext;
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
var    errCode      : integer;
       newname, msg : string;
       start_save   : boolean;
begin
        commit(ctx);

        newname := ctx.current^.fname;
        msg := ' Save file to :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scr.show;
                scrui.editstr(event^, length(msg) + 1, 0, ctx.current^.config^.color.top, newname, 32, 255);
                if event^.etype = KEYBOARD then begin
                        if event^.scancode = SCAN_ESC then begin start_save := false; break; end;
                        if event^.scancode = SCAN_ENTER then begin start_save := true; break; end;
                end else if event^.etype <> MOUSE_MOVE then begin start_save := false; break; end;
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
var     r : integer;
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
                                with ctx.current^ do begin
                                        cline := strs.go_prev(cline);
                                        strs.get(cline, s);
                                        cline := strs.merge(cline);
                                        rline := strs.go_first(cline);
                                        if scry <> 0 then dec(scry);
                                        total := strs.renum(rline);
                                        chg := true;
                                        editor.x := length(s) + 1;
                                end;
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
var     clinenum : longint;
        r, x     : integer;
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
var lnum    : word;
    isfist  : boolean;
    cbsize  : dword;
begin
        commit(ctx);
        if ctx.current^.editor.selection then begin
                delete_selected(ctx);
                ctx.current^.total := strs.renum(ctx.current^.rline);
                ctx.current^.editor.selection := false;
        end;
        with ctx.current^ do begin
                if ctx.has_wincb then WCB_Paste(ctx.clipboard[0], CB_SIZE);
                isfist := strs.is_first(cline);
                cline := strs.append(cline, editor.x, ctx.clipboard, lnum);
                if isfist then rline := strs.go_first(cline);
                while (lnum <> 0) and (scry <> config^.height - 2) do begin
                        dec(lnum);
                        inc(scry);
                end;
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
    start_find : boolean;
begin
        r := SCRU_CLINE;
        lnum := 0;
        lNumStr := '';
        msg := ' Goto line (1-'+ltoa(ctx.current^.total)+') :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scrui.editstr(event^, length(msg) + 1, 0, ctx.current^.config^.color.top, lNumStr, 12, 12);
                if event^.etype = KEYBOARD then begin
                        if event^.scancode = SCAN_ESC then begin start_find := false; break; end;
                        if event^.scancode = SCAN_ENTER then begin start_find := true; break; end;
                end else if event^.etype <> MOUSE_MOVE then begin start_find := false; break; end;
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
var     i, r       : integer;
        sb_y, se_y, clinenum : longint;
        sb_x, se_x : integer;
        line       : EditorStr;
        content    : string;
begin
        r := SCRU_NONE;
        if is_in_table(ctx, event) then r := tbl_next_column(ctx, event)
        else if ctx.current^.editor.selection then begin
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
                        ascii := ' ';
                        scancode := SCAN_SPACE;
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
var     i, r       : integer;
        sb_y, se_y, clinenum : longint;
        sb_x, se_x : integer;
        line       : EditorStr;
        content    : string;
begin
        r := SCRU_NONE;
        if is_in_table(ctx, event) then r := tbl_prev_column(ctx, event)
        else if ctx.current^.editor.selection then begin
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
                with ctx.current^ do begin
                i := config^.tab_size;
                while (i > 0)
                         and (editor.line[1] = ' ')
                         and (length(editor.line) > 0) do begin
                                System.delete(editor.line, 1, 1);
                                editor.chg := true;
                                if editor.x <> 1 then dec(editor.x);
                                dec(i);
                        end;
                end;
                r := SCRU_CLINE;
        end;
        hk_shift_tab := r;
end;

function hk_default(var ctx:TEditorContext; event:PEvent):integer;
var     r, len  : integer;
        c       : char;
        changed : boolean;
begin
        r := SCRU_NONE;
        c := event^.ascii;
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

function search(var ctx:TEditorContext; is_replace : boolean):EditorStr;
var     line        : EditorStr;
        searchText  : string;
        lineStr     : string;
        start_col   : integer;
        position    : integer;
begin
        searchText := ctx.search;
        if not ctx.searchCaseSens then upstr(searchText);
        start_col := ctx.current^.editor.x;
        line := ctx.current^.cline;
        while line <> nil do begin
                strs.get(line, lineStr);
                if not ctx.searchCaseSens then upstr(lineStr);
                position := pos(searchText, copy(lineStr, start_col, length(lineStr) - start_col + 1));
                if position <>0 then begin
                        ctx.current^.cline := line;
                        ctx.current^.scrx := 0;
                        ctx.current^.editor.x := start_col + position - 1;
                        if not is_replace then inc(ctx.current^.editor.x, length(searchText));
                        load_ed(ctx);
                        break;
                end;
                start_col := 1;
                line := strs.go_next(line);
        end;
        search := line;
end;

procedure search_not_found(var ctx:TEditorContext);
begin
        scr.push;
        scrui.msg_box(ctx.current^.config^.color.top, 'Search / Replace', 'Substring not found.', '[ OK ]');
        scr.show;
        kbd.reset;
        kbd.getkey;
        scr.pop;
end;

function hk_find_again(var ctx:TEditorContext; event:PEvent):integer;
var     r           : integer;
        line        : EditorStr;
        lineStr     : string;
        searchText  : string;
        is_replace  : boolean;
        msg         : string;
        ans         : Answer;
        count       : longint;
begin
        r := SCRU_CLINE;
        commit(ctx);
        ctx.search := trim(ctx.search);
        line := ctx.current^.cline;
        searchText := ctx.search;
        is_replace := length(ctx.replace) <> 0;

        line := search(ctx, is_replace);

        if is_replace then begin
                ans := YES;
                count := 0;
                if line = nil then begin
                        search_not_found(ctx);
                end else while (line <> nil) and (ans in [YES, ALL]) do begin
                        norm_xy(ctx, SCRU_FULL);
                        load_ed(ctx);
                        ctx.current^.editor.selection := true;
                        ctx.current^.editor.sel_row := strs.get_num(ctx.current^.cline);
                        ctx.current^.editor.sel_x := ctx.current^.editor.x + length(searchText);
                        if ans = YES then begin
                                dwedscru.update(ctx, SCRU_FULL);
                                msg := ' Replace it? (~Y~/~N~/~A~)';
                                scr.cln(0, 0, ctx.current^.config^.color.top);
                                scr.printhl(0, 0, ctx.current^.config^.color.top,
                                         ctx.current^.config^.color.top_hl,
                                         msg);
                                scr.show;
                                ans := scrui.yes_no_all;
                        end;
                        if ans = NO then begin
                                inc(ctx.current^.editor.x, length(searchText));
                        end else begin
                                System.delete(ctx.current^.editor.line
                                        , ctx.current^.editor.x
                                        , length(searchText));
                                System.insert(ctx.replace
                                        , ctx.current^.editor.line
                                        , ctx.current^.editor.x);
                                ctx.current^.editor.chg := true;
                                inc(ctx.current^.editor.x, length(ctx.replace));
                                inc(count);
                        end;
                        ctx.current^.editor.selection := false;
                        commit(ctx);
                        line := search(ctx, is_replace);
                end;
                if (ans = ALL) and (count <> 0) then begin
                        scr.push;
                        scrui.msg_box(ctx.current^.config^.color.top, 'Search / Replace', 'Replaced ' +
                                ltoa(count) +
                                ' string(s).', '[ OK ]');
                        scr.show;
                        kbd.reset;
                        kbd.getkey;
                        scr.pop;
                end;
                r := SCRU_FULL;
        end else begin
                if line = nil then begin
                        search_not_found(ctx);
                end;
                r := SCRU_FULL;
        end;
        hk_find_again := r;
end;

function hk_start_find(var ctx:TEditorContext; event:PEvent):integer;
var     r              : integer;
        sb_y, se_y, clinenum : longint;
        sb_x, se_x     : integer;
        msg            : string;
        searchStr      : string;
        replaceStr     : string;
        start_find     : boolean;
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
                scrui.editstr(event^, length(msg) + 1, 0, ctx.current^.config^.color.top, searchStr, 32, 64);
                if event^.etype = KEYBOARD then begin
                        if event^.scancode = SCAN_ESC then begin start_find := false; break; end;
                        if event^.scancode = SCAN_ENTER then begin start_find := true; break; end;
                end else if event^.etype <> MOUSE_MOVE then begin start_find := false; break; end;
        end;
        searchStr := trim(searchStr);
        if length(searchStr) = 0 then start_find := false;
        if start_find then begin
                msg := ' Replace with :';
                scr.cln(0, 0, ctx.current^.config^.color.top);
                scr.print(0, 0, ctx.current^.config^.color.top, msg);
                while true do begin
                        scrui.editstr(event^, length(msg) + 1, 0, ctx.current^.config^.color.top, replaceStr, 32, 64);
                        if event^.etype = KEYBOARD then begin
                                if event^.scancode = SCAN_ESC then begin start_find := false; break; end;
                                if event^.scancode = SCAN_ENTER then begin break; end;
                        end else if event^.etype <> MOUSE_MOVE then begin start_find := false; break; end;
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
var     fname      : string;
        msg        : string;
        start_save : boolean;
        errCode    : integer;
begin
        commit(ctx);
        fname := '';
        msg := ' Save clipboard to file :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scr.show;
                scrui.editstr(event^, length(msg) + 1, 0, ctx.current^.config^.color.top, fname, 32, 255);
                if event^.etype = KEYBOARD then begin
                if event^.scancode = SCAN_ESC then begin start_save := false; break; end;
                if event^.scancode = SCAN_ENTER then begin start_save := true; break; end;
                end else if event^.etype <> MOUSE_MOVE then begin start_save := false; break; end;
        end;
        if start_save then begin
                errCode := save_clipboard(ctx, fname);
                if errCode <> 0 then handle_error(ctx, errCode);
        end;
        hk_cb_save := SCRU_CLINE;
end;

function hk_cb_load(var ctx:TEditorContext; event:PEvent):integer;
var     fname      : string;
        msg        : string;
        start_load : boolean;
        errCode    : integer;
begin
        commit(ctx);
        fname := '';
        msg := ' Load clipboard from file :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scr.show;
                scrui.editstr(event^, length(msg) + 1, 0, ctx.current^.config^.color.top, fname, 32, 255);
                if event^.etype = KEYBOARD then begin
                        if event^.scancode = SCAN_ESC then begin start_load := false; break; end;
                        if event^.scancode = SCAN_ENTER then begin start_load := true; break; end;
                end else if event^.etype <> MOUSE_MOVE then begin start_load := false; break; end;
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
var     canclose : boolean;
        r, next, prev : PFileContext;
        msg      : string;
        res      : integer;
        errCode  : integer;
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
var     r, errCode : integer;
        msg        : string;
        fname      : string;
        start_load : boolean;
begin
        commit(ctx);
        r := SCRU_CLINE;
        fname := '';
        msg := ' Load file :';
        scr.cln(0, 0, ctx.current^.config^.color.top);
        scr.print(0, 0, ctx.current^.config^.color.top, msg);
        while true do begin
                scr.show;
                scrui.editstr(event^, length(msg) + 1, 0, ctx.current^.config^.color.top, fname, 32, 255);
                with event^ do begin
                        if etype = KEYBOARD then begin
                                if scancode = SCAN_ESC then begin start_load := false; break; end;
                                if scancode = SCAN_ENTER then begin start_load := true; break; end;
                        end else if etype <> MOUSE_MOVE then begin start_load := false; break; end;
                end;
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

procedure serialize_fctx(var t : bfile; current : PFileContext);
begin
        if current = nil then exit;
        if current^.next <> nil then serialize_fctx(t, current^.next);
        writeln(t, System.concat(itoa(current^.editor.x),
        ',', itoa(current^.scrx),
        ',', itoa(current^.scry),
        ',', ltoa(strs.get_num(current^.cline)),
        ',', current^.fname) 
        );
end;

function hk_userdef(var ctx:TEditorContext; event:PEvent):integer;
var     cmd        : string;
        r, errCode : integer;
        writed     : word;
        t          : bfile;
        can_run    : boolean;
        srcctx     : PFileContext;
begin
        cmd := '';
        r := SCRU_NONE;
        can_run := true;
        case event^.scancode of
        SCAN_F5: cmd := ctx.config.udef_f5;
        SCAN_F8: cmd := ctx.config.udef_f8;
        SCAN_F9: cmd := ctx.config.udef_f9;
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
                assign(t, ctx.temp);
                rewrite(t);
                if not isopen(t) then begin handle_error(ctx, 105); can_run := false; end else begin
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
                assign(t, dwedlnch.DEVFILE);
                rewrite(t);
                if not isopen(t) then begin handle_error(ctx, 105); can_run := false; end else begin
                        blockwrite(t, cmd[0], length(cmd) + 1);
                        close(t);
                        ctx.exit_code := 254;
                end;
        end;
        if can_run then r := SCRU_QUIT;
        hk_userdef := r;
end;

function hk_move_line_up(var ctx:TEditorContext; event:PEvent):integer;
var     r       : integer;
        s1, s2  : string;
begin
        r := SCRU_NONE;
        if not strs.is_first(ctx.current^.cline) then begin
                commit(ctx);
                strs.get(strs.go_prev(ctx.current^.cline), s1);
                strs.get(ctx.current^.cline, s2);
                ctx.current^.cline := strs.put(ctx.current^.cline, s1);
                ctx.current^.cline := strs.go_prev(ctx.current^.cline);
                ctx.current^.cline := strs.put(ctx.current^.cline, s2);
                if strs.is_first(ctx.current^.cline) then ctx.current^.rline := ctx.current^.cline;
                if ctx.current^.scry <> 0 then dec(ctx.current^.scry);
                ctx.current^.chg := true;
                r := SCRU_FULL;
                load_ed(ctx);
        end;
        hk_move_line_up := r;
end;

function hk_move_line_down(var ctx:TEditorContext; event:PEvent):integer;
var     r      : integer;
        s1, s2 : string;
begin
        r := SCRU_NONE;
        if not strs.is_last(ctx.current^.cline) then begin
                commit(ctx);
                strs.get(ctx.current^.cline, s1);
                strs.get(strs.go_next(ctx.current^.cline), s2);
                ctx.current^.cline := strs.put(ctx.current^.cline, s2);
                if strs.is_first(ctx.current^.cline) then ctx.current^.rline := ctx.current^.cline;
                ctx.current^.cline := strs.go_next(ctx.current^.cline);
                ctx.current^.cline := strs.put(ctx.current^.cline, s1);
                if ctx.current^.scry <> ctx.config.height - 1 then inc(ctx.current^.scry);
                ctx.current^.chg := true;
                load_ed(ctx);
                r := SCRU_FULL;
        end;
        hk_move_line_down := r;
end;

begin
        reg_handler(SCAN_ESC, false, false, false, false, @hk_esc);
        reg_handler(SCAN_A, true, false, true, false, @hk_asciitbl);
        reg_handler(SCAN_C, true, false, true, false, @hk_calc);
        reg_handler(SCAN_H, true, false, true, false, @hk_change_hl);
        reg_handler(SCAN_SHIFT_F2, false, true, false, false, @hk_save_as);

        reg_handler(SCAN_CTRL_PGUP, true, true, false, true, @hk_move_line_up);
        reg_handler(SCAN_CTRL_PGDN, true, true, false, true, @hk_move_line_down);
        reg_handler(SCAN_CTRL_UP, true, true, false, true, @hk_move_line_up);
        reg_handler(SCAN_CTRL_DOWN, true, true, false, true, @hk_move_line_down);

        reg_handler(SCAN_F1, false, false, false, false, @hk_help);
        reg_handler(SCAN_F2, false, false, false, false, @hk_save);
        reg_handler(SCAN_F3, false, false, false, false, @hk_load);
        reg_handler(SCAN_F5, false, false, false, false, @hk_userdef);
        reg_handler(SCAN_F6, false, false, false, false, @hk_nextwin);
        reg_handler(SCAN_F7, false, false, false, true, @hk_start_find);
        reg_handler(SCAN_F8, false, false, false, false, @hk_userdef);
        reg_handler(SCAN_F9, false, false, false, false, @hk_userdef);
        reg_handler(SCAN_F12, false, false, false, false, @hk_addons);

        reg_handler(SCAN_ALT_F2, false, false, true, false, @hk_cb_save);
        reg_handler(SCAN_ALT_F3, false, false, true, false, @hk_cb_load);
        reg_handler(SCAN_ALT_F4, false, false, true, false, @hk_close);
        reg_handler(SCAN_ALT_F5, false, false, true, false, @hk_dos_screen);
        reg_handler(SCAN_ALT_F6, false, false, true, false, @hk_winlist);
        reg_handler(SCAN_ALT_F10, false, false, true, false, @hk_addons);

        reg_handler(SCAN_CTRL_LEFT, true, false, false, true, @hk_word_left);
        reg_handler(SCAN_CTRL_RIGHT, true, false, false, true, @hk_word_right);

        reg_handler(SCAN_CTRL_LEFT, true, true, false, false, @hk_word_sleft);
        reg_handler(SCAN_CTRL_RIGHT, true, true, false, false, @hk_word_sright);

        reg_handler(SCAN_TAB, false, false, false, false, @hk_tab);
        reg_handler(SCAN_TAB, false, true, false, false, @hk_shift_tab);

        reg_handler(SCAN_UP, false, true, false, false, @hk_sup);
        reg_handler(SCAN_DOWN, false, true, false, false, @hk_sdown);
        reg_handler(SCAN_LEFT, false, true, false, false, @hk_sleft);
        reg_handler(SCAN_RIGHT, false, true, false, false, @hk_sright);
        reg_handler(SCAN_PGUP, false, true, false, false, @hk_spgup);
        reg_handler(SCAN_PGDN, false, true, false, false, @hk_spgdown);
        reg_handler(SCAN_HOME, false, true, false, false, @hk_shome);
        reg_handler(SCAN_END, false, true, false, false, @hk_send);

        reg_handler(SCAN_UP, false, false, false, true, @hk_up);
        reg_handler(SCAN_DOWN, false, false, false, true, @hk_down);
        reg_handler(SCAN_LEFT, false, false, false, true, @hk_left);
        reg_handler(SCAN_RIGHT, false, false, false, true, @hk_right);
        reg_handler(SCAN_PGUP, false, false, false, true, @hk_pgup);
        reg_handler(SCAN_PGDN, false, false, false, true, @hk_pgdown);
        reg_handler(SCAN_HOME, false, false, false, true, @hk_home);
        reg_handler(SCAN_END, false, false, false, true, @hk_end);
        reg_handler(SCAN_CTRL_HOME, true, false, false, true, @hk_file_begin);
        reg_handler(SCAN_CTRL_END, true, false, false, true, @hk_file_end);

        reg_handler(SCAN_DEL, false, false, false, false, @hk_del);
        reg_handler(SCAN_BS, false, false, false, false, @hk_bs);
        reg_handler(SCAN_ENTER, false, false, false, false, @hk_enter);

        reg_handler(SCAN_S, true, false, false, true, @hk_save);
        reg_handler(SCAN_S, true, true, false, true, @hk_save);
        reg_handler(SCAN_INS, false, false, false, false, @hk_ins);

        reg_handler(SCAN_X, true, false, false, false, @hk_cb_cut);
        reg_handler(SCAN_C, true, false, false, false, @hk_cb_copy);
        reg_handler(SCAN_V, true, false, false, false, @hk_cb_paste);

        reg_handler(SCAN_Y, true, false, false, false, @hk_cb_cutline);
        reg_handler(SCAN_U, true, false, false, false, @hk_cb_paste);

        reg_handler(SCAN_L, true, false, false, true, @hk_goto_line);
        reg_handler(SCAN_F, true, false, false, true, @hk_start_find);
        reg_handler(SCAN_F, true, true, false, true, @hk_start_find);
        reg_handler(SCAN_K, true, false, false, true, @hk_find_again);

        reg_handler(SCAN_INS, false, true, false, false, @hk_cb_paste);
        reg_handler(SCAN_DEL, false, true, false, false, @hk_cb_cut);
end.
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
unit dwedutil;

interface

uses dwedtype;

procedure get_sel_coord(
        var ctx : TEditorContext;
        var sb_x : integer;
        var sb_y : longint;
        var se_x : integer;
        var se_y : longint);

function norm_xy(var ctx : TEditorContext; r : integer) : integer;

procedure commit(var ctx : TEditorContext);
procedure load_ed(var ctx : TEditorContext);

function go_line_begin(var ctx : TEditorContext) : integer;
function go_line_end(var ctx : TEditorContext) : integer;
function go_line_up(var ctx : TEditorContext) : integer;
function go_line_down(var ctx : TEditorContext) : integer;
function go_char_left(var ctx : TEditorContext) : integer;
function go_char_right(var ctx : TEditorContext) : integer;
function go_word_left(var ctx : TEditorContext) : integer;
function go_word_right(var ctx : TEditorContext) : integer;
function go_page_up(var ctx : TEditorContext) : integer;
function go_page_down(var ctx : TEditorContext) : integer;

procedure copy_selected(var ctx : TEditorContext);
procedure delete_selected(var ctx : TEditorContext);
function save_clipboard(var ctx : TEditorContext; fname:string) : integer;
function load_clipboard(var ctx : TEditorContext; fname:string) : integer;
procedure go_win_list(var ctx:TEditorContext);

function mk_short_name(fname : string) : string;

procedure new_file(var ctx : TEditorContext; fname : string);
function load_file(var ctx : TEditorContext; fname : string; var errCode : integer) : integer;

procedure handle_error(var ctx : TEditorContext; errCode:integer);

implementation

uses kbd, scr, scrui, strs, strutil, lfn, dwedhl;

procedure commit(var ctx : TEditorContext);
begin
        with ctx.current^ do begin
                if not editor.chg then exit;
                cline := strs.put(cline, editor.line);
                if strs.is_first(cline) then rline := cline;
                if scry = 0 then scrline := cline;
                chg := true;
                editor.chg := false;
        end;
end;

procedure load_ed(var ctx : TEditorContext);
begin
        with ctx.current^ do begin
                strs.get(cline, editor.line);
                if scrx > length(editor.line) then scrx := 0;
        end;
end;

function norm_xy(var ctx : TEditorContext; r : integer) : integer;
var i, x, old_scrx: integer;
begin
        old_scrx := ctx.current^.scrx;
        with ctx.current^ do begin
                scrline := cline;
                if scrx < 0 then scrx := 0;
                if scry < 0 then scry := 0;
                if editor.x < 1 then editor.x := 1;
                if editor.x > length(editor.line) + 1 then editor.x := length(editor.line) + 1;
        end;
        if ctx.current^.scry <> 0 then begin
                i := ctx.current^.scry;
                x := 0;
                while i <> 0 do begin
                        if strs.is_first(ctx.current^.scrline) then begin
                                ctx.current^.scry := x;
                                break;
                        end;
                        with ctx.current^ do scrline := strs.go_prev(scrline);
                        inc(x);
                        dec(i);
                end;
        end;
        with ctx.current^ do begin
                if scrx >= editor.x then scrx := editor.x - 1;
                if config^.width <= (editor.x - scrx - 1) then scrx := editor.x - config^.width;
        end;
        if old_scrx <> ctx.current^.scrx then r := SCRU_FULL;
        norm_xy := r;
end;

function go_line_begin(var ctx : TEditorContext) : integer;
var r : integer;
begin
        r := SCRU_CLINE;
        ctx.current^.editor.x := 1;
        if ctx.current^.scrx <> 0 then begin
                ctx.current^.scrx := 0;
                r := SCRU_FULL;
        end;
        go_line_begin := r;
end;

function go_line_end(var ctx : TEditorContext) : integer;
begin
        with ctx.current^ do begin
                editor.x := length(editor.line) + 1;
                go_line_end := SCRU_CLINE;
        end;
end;

function go_line_up(var ctx : TEditorContext) : integer;
var r : integer;
begin
        r := SCRU_NONE;
        if ctx.current^.scry <> 0 then begin
                commit(ctx);
                with ctx.current^ do begin
                        cline := strs.go_prev(cline);
                        dec(scry);
                end;
                load_ed(ctx);
                r := SCRU_FULL;
        end else if not strs.is_first(ctx.current^.scrline) then begin
                commit(ctx);
                with ctx.current^ do begin
                        cline := strs.go_prev(cline);
                        scrline := strs.go_prev(scrline);
                end;
                load_ed(ctx);
                r := SCRU_FULL;
        end;
        go_line_up := r;
end;

function go_line_down(var ctx : TEditorContext) : integer;
var r : integer;
begin
        r := SCRU_NONE;
        if not strs.is_last(ctx.current^.cline) then begin
                commit(ctx);
                with ctx.current^ do begin
                        if config^.height - 2 <> scry then begin
                                inc(scry);
                                cline := strs.go_next(cline);
                        end else begin
                                scrline := strs.go_next(scrline);
                                cline := strs.go_next(cline);
                        end;
                end;
                load_ed(ctx);
                if length(ctx.current^.editor.line) + 1 < ctx.current^.editor.x then begin
                        go_line_end(ctx);
                end;
                r := SCRU_FULL;
        end else r := SCRU_NONE;
        go_line_down := r;
end;

function go_char_left(var ctx : TEditorContext) : integer;
var r, i : integer;
begin
        r := SCRU_NONE;
        if ctx.current^.editor.x <> 1 then begin
                r := SCRU_CLINE;
                dec(ctx.current^.editor.x);
        end else if not strs.is_first(ctx.current^.cline) then begin
                commit(ctx);
                r := go_line_up(ctx);
                i := go_line_end(ctx);
                load_ed(ctx);
                if r < i then r := i;
        end;
        go_char_left := r;
end;

function go_char_right(var ctx : TEditorContext) : integer;
var r, i : integer;
begin
        r := SCRU_NONE;
        if ctx.current^.editor.x <= length(ctx.current^.editor.line) then begin
                r := SCRU_CLINE;
                inc(ctx.current^.editor.x);
        end else if not strs.is_last(ctx.current^.cline) then begin
                commit(ctx);
                if ctx.current^.scrx <> 0 then r := SCRU_FULL;
                with ctx.current^ do begin
                        editor.x := 1;
                        scrx := 0;
                end;
                i := go_line_down(ctx);
                load_ed(ctx);
                if r < i then r := i;
        end;
        go_char_right := r;
end;

function is_space_skip(c : char) : boolean;
begin
        is_space_skip := not ((c in ['a'..'z', 'A'..'Z', '0'..'9', '_']) or (c > #$7f));
end;

function go_word_left(var ctx : TEditorContext) : integer;
var r : integer;
        state : boolean;
begin
        r := SCRU_NONE;
        if ctx.current^.editor.x = 1 then begin
                if not strs.is_first(ctx.current^.cline) then begin
                        commit(ctx);
                        ctx.current^.cline := strs.go_prev(ctx.current^.cline);
                        load_ed(ctx);
                        with ctx.current^ do begin
                                editor.x := length(editor.line) + 1;
                                if scry <> 0 then dec(scry);
                        end;
                        r := SCRU_FULL;
                end;
        end else begin
                if ctx.current^.editor.x > length(ctx.current^.editor.line)
                        then ctx.current^.editor.x := length(ctx.current^.editor.line);
                state := is_space_skip(ctx.current^.editor.line[ctx.current^.editor.x]);
                while ctx.current^.editor.x > 1 do begin
                        if state <> is_space_skip(ctx.current^.editor.line[ctx.current^.editor.x]) then break;
                        dec(ctx.current^.editor.x);
                end;
                r := SCRU_CLINE;
        end;
        go_word_left := r;
end;

function go_word_right(var ctx : TEditorContext) : integer;
var r : integer;
        state : boolean;
begin
        r := SCRU_NONE;
        if ctx.current^.editor.x = length(ctx.current^.editor.line) + 1 then begin
                if not strs.is_last(ctx.current^.cline) then begin
                        commit(ctx);
                        ctx.current^.cline := strs.go_next(ctx.current^.cline);
                        load_ed(ctx);
                        with ctx.current^ do begin
                                editor.x := 1;
                                if scry <> config^.height-2 then inc(scry);
                        end;
                        r := SCRU_FULL;
                end;
        end else begin
                if ctx.current^.editor.x > length(ctx.current^.editor.line)
                        then ctx.current^.editor.x := length(ctx.current^.editor.line);
                state := is_space_skip(ctx.current^.editor.line[ctx.current^.editor.x]);
                while ctx.current^.editor.x < length(ctx.current^.editor.line) + 1 do begin
                        if state <> is_space_skip(ctx.current^.editor.line[ctx.current^.editor.x]) then break;
                        inc(ctx.current^.editor.x);
                end;
                r := SCRU_CLINE;
        end;
        go_word_right := r;
end;

function go_page_up(var ctx : TEditorContext) : integer;
var r, i : integer;
begin
        r := SCRU_NONE;
        if (ctx.current^.scrx <> 0) or (ctx.current^.scry <> 0) or (ctx.current^.editor.x <> 1) then begin
                commit(ctx);
                with ctx.current^ do begin
                        while scry <> 0 do begin
                                cline := strs.go_prev(cline);
                                dec(scry);
                        end;
                        scrx := 0;
                        editor.x := 1;
                end;
                load_ed(ctx);
                r := SCRU_FULL;
        end else begin
                i := ctx.current^.config^.height - 2;
                commit(ctx);
                while (i <> 0) and (not strs.is_first(ctx.current^.scrline)) do begin
                        with ctx.current^ do scrline := strs.go_prev(scrline);
                        dec(i);
                end;
                with ctx.current^ do begin
                        scry := 0;
                        cline := scrline;
                end;
                load_ed(ctx);
                r := SCRU_FULL;
        end;
        go_page_up := r;
end;

function go_page_down(var ctx : TEditorContext) : integer;
var r, i : integer;
begin
        r := SCRU_NONE;
        if (ctx.current^.scrx <> 0)
         or (ctx.current^.scry <> ctx.current^.config^.height-2)
         or (ctx.current^.editor.x <> 1) then begin
                commit(ctx);
                with ctx.current^ do begin
                        while (scry <> config^.height-2) and (not strs.is_last(cline)) do begin
                                cline := strs.go_next(cline);
                                inc(scry);
                        end;
                        scrx := 0;
                        editor.x := 1;
                end;
                load_ed(ctx);
                r := SCRU_FULL;
        end else begin
                commit(ctx);
                i := ctx.current^.config^.height - 2;
                while (i <> 0) and (not strs.is_last(ctx.current^.cline)) do begin
                        with ctx.current^ do begin
                                scrline := strs.go_next(scrline);
                                cline := strs.go_next(cline);
                        end;
                        dec(i);
                end;
                load_ed(ctx);
                r := SCRU_FULL;
        end;
        go_page_down := r;
end;

procedure get_sel_coord(
        var ctx : TEditorContext;
        var sb_x : integer;
        var sb_y : longint;
        var se_x : integer;
        var se_y : longint);
var x, y : integer;
begin
        commit(ctx);
        if not ctx.current^.editor.selection then exit;

        sb_y := ctx.current^.editor.sel_row;
        sb_x := ctx.current^.editor.sel_x;
        se_y := strs.get_num(ctx.current^.cline);
        se_x := ctx.current^.editor.x;
        if (sb_y > se_y) or ((sb_y = se_y) and (sb_x > se_x)) then begin
                x := sb_x;
                y := sb_y;
                sb_x := se_x;
                sb_y := se_y;
                se_x := x;
                se_y := y;
        end;
end;

function save_clipboard(var ctx : TEditorContext; fname:string) : integer;
var f : file;
        r        : integer;
begin
        assign(f, lfn2dos(fname));
        {$I-}
        rewrite(f, 1);
        r := ioresult;
        {$I+}
        if r = 0 then begin
                blockwrite(f, ctx.clipboard, strlen(ctx.clipboard));
                truncate(f);
                close(f);
        end;
        save_clipboard := r;
end;

function load_clipboard(var ctx : TEditorContext; fname:string) : integer;
var f : file;
        r        : integer;
        readed   : word;
begin
        assign(f, lfn2dos(fname));
        {$I-}
        System.reset(f, 1);
        r := ioresult;
        {$I+}
        if r = 0 then begin
                blockread(f, ctx.clipboard, CB_SIZE - 1, readed);
                ctx.clipboard[readed] := #0;
                close(f);
        end;
        load_clipboard := r;
end;

procedure copy_selected(var ctx : TEditorContext);
var
        sb_y, se_y, clinenum : longint;
        sb_x, se_x : integer;
        pos        : word;
        line       : EditorStr;
        lineStr    : string;
        len        : integer;
begin
        if not ctx.current^.editor.selection then exit;
        get_sel_coord(ctx, sb_x, sb_y, se_x, se_y);
        line := strs.find_num(ctx.current^.rline, sb_y);
        pos := 0;
        if sb_y = se_y then begin
                strs.get(line, lineStr);
                lineStr := copy(lineStr, sb_x, se_x - sb_x);
                pos := length(lineStr);
                move(lineStr[1], ctx.clipboard[0], pos);
        end else while line <> nil do begin
                strs.get(line, lineStr);
                clinenum := strs.get_num(line);
                len := length(lineStr);
                if clinenum = sb_y then begin
                        if pos > (CB_SIZE - (len + 3)) then break;
                        dec(len, sb_x);
                        move(lineStr[sb_x], ctx.clipboard[pos], len + 1);
                        inc(pos, len + 1);
                        ctx.clipboard[pos] := #$0D;
                        inc(pos);
                        ctx.clipboard[pos] := #$0A;
                        inc(pos);
                end else if clinenum = se_y then begin
                        len := se_x - 1;
                        if pos > (CB_SIZE - (len + 1)) then break;
                        if se_x > 0 then begin
                                move(lineStr[1], ctx.clipboard[pos], len);
                                inc(pos, len);
                        end;
                        break;
                end else begin
                        if pos > (CB_SIZE - (len + 3)) then break;
                        move(lineStr[1], ctx.clipboard[pos], len);
                        inc(pos, len);
                        ctx.clipboard[pos] := #$0D;
                        inc(pos);
                        ctx.clipboard[pos] := #$0A;
                        inc(pos);
                end;
                line := strs.go_next(line);
        end;
        ctx.clipboard[pos] := #0;
{$IFDEF TEST}
        save_clipboard(ctx, 'cb.txt');
{$ENDIF}
end;

procedure delete_selected(var ctx : TEditorContext);
var
        sb_y, se_y, clinenum : longint;
        sb_x, se_x           : integer;
        bline, eline         : EditorStr;
        lineStr  : string;
        len      : integer;
        is_last  : boolean;
begin
        if not ctx.current^.editor.selection then exit;
        get_sel_coord(ctx, sb_x, sb_y, se_x, se_y);
        if sb_y = se_y then begin
                bline := strs.find_num(ctx.current^.rline, sb_y);
                strs.get(bline, lineStr);
                lineStr := copy(lineStr, 1, sb_x - 1) + copy(lineStr, se_x, length(lineStr) - se_x + 1);
                bline := strs.put(bline, lineStr);
                ctx.current^.cline := bline;
                if ctx.current^.scry = 0 then ctx.current^.scrline := bline;
                ctx.current^.editor.x := sb_x;
        end else begin
                if (sb_y + 1 <> se_y) then ctx.current^.rline := strs.delete(ctx.current^.rline, sb_y + 1, se_y - 1);
                bline := strs.find_num(ctx.current^.rline, sb_y);
                is_last := strs.is_last(bline);
                strs.get(bline, lineStr);
                if length(lineStr) <> 0 then begin
                        lineStr := copy(lineStr, 1, sb_x - 1);
                        bline := strs.put(bline, lineStr);
                end;
                ctx.current^.editor.x :=length(lineStr) + 1;
                if not is_last then begin
                        eline := strs.go_next(bline);
                        strs.get(eline, lineStr);
                        if length(lineStr) <> 0 then begin
                                lineStr := copy(lineStr, se_x, length(lineStr) - se_x + 1);
                                eline := strs.put(eline, lineStr);
                        end;
                        bline := strs.merge(bline);
                end;
                ctx.current^.cline := bline;
        end;
        with ctx.current^ do begin
                if strs.is_first(cline) then rline := cline;
                chg := true;
                editor.selection := false;
        end;
        load_ed(ctx);
end;

procedure go_win_list(var ctx:TEditorContext);
var r : PFileContext;
        i, sitem, cctx  : integer;
        memlen          : integer;
        p               : pchar;
        w               : word;
begin
        scr.cursor_off;        
        i := 0;
        memlen := 0;
        r := ctx.all;
        while r <> nil do begin
                if r = ctx.current then begin sitem := i; cctx := i; end;
                inc(memlen, length(r^.sfname) + 3);
                inc(i);
                r := r^.next;
        end;
        getmem(p, memlen);
        i := 0;
        r := ctx.all;
        while r <> nil do begin
                if i <> 0 then begin p[i] := #$0A; inc(i); end;
                p[i] := ' '; inc(i);
                if r^.chg or r^.editor.chg then p[i] := #$03 else p[i] := ' ';
                inc(i);
                move(r^.sfname[1], p[i], length(r^.sfname));
                inc(i, length(r^.sfname));
                r := r^.next;
        end;
        p[i] := #0;

        while true do begin
                w := scrui.vmenu(1, 2, 32, 16,
                        ctx.config.color.menu,
                        ctx.config.color.menu_sel,
                        p, sitem);
                if w = K_ESC then break;
                if (w = K_ENTER) or (lo(w) = 32) then begin
                        if (sitem <> cctx) then begin
                                i := 0;
                                r := ctx.all;
                                while r <> nil do begin
                                        if i = sitem then begin ctx.current := r; break; end;
                                        inc(i);
                                        r := r^.next;
                                end;
                        end;
                        break;
                end;
        end;

        freemem(p, memlen);
end;

function mk_short_name(fname : string) : string;
begin
        mk_short_name := basename(fname);
end;

procedure reset_file(p : PFileContext);
begin
        with p^ do begin
                sfname := mk_short_name(fname);
                st := find_SourceType_by_ext(get_filename_ext(sfname));
                chg := false;
                cline := rline;
                scrline := rline;
                editor.chg := false;
                editor.x := 1;
                editor.selection := false;
                scrline := rline;
                scrx := 0;
                scry := 0;
                total := strs.renum(rline);
                next := nil;
        end;
end;

procedure new_file(var ctx : TEditorContext; fname : string);
var p : PFileContext;
begin
        getmem(p, sizeof(TFileContext));
        p^.fname := fname;
        p^.rline := strs.new;
        reset_file(p);
        p^.next := ctx.all;
        p^.config := @ctx.config;
        ctx.all := p;
        ctx.current := p;
        load_ed(ctx);
end;

function load_file(var ctx : TEditorContext; fname : string; var errCode : integer) : integer;
var p : PFileContext;
        r : integer;
begin
        getmem(p, sizeof(TFileContext));
        p^.fname := fname;
        p^.rline := strs.from_file(fname, ctx.config.tab_size, errCode);
        reset_file(p);
        p^.next := ctx.all;
        p^.config := @ctx.config;
        ctx.all := p;
        ctx.current := p;
        load_ed(ctx);
        load_file := r;
end;

procedure handle_error(var ctx : TEditorContext; errCode:integer);
var errMsg : string;
begin
        case errCode of
        1: errMsg := 'Invalid function number';
        2: errMsg := 'File not found';
        3: errMsg := 'Path not found';
        4: errMsg := 'Too many open files';
        5: errMsg := 'File access denied';
        6: errMsg := 'Invalid file handle';
        12: errMsg := 'Invalid file access code';
        15: errMsg := 'Invalid drive number';
        16: errMsg := 'Cannot remove current directory';
        17: errMsg := 'Cannot rename across drives';
        18: errMsg := 'No more files';
        100: errMsg := 'Disk read error';
        101: errMsg := 'Disk write error';
        102: errMsg := 'File not assigned';
        103: errMsg := 'File not open';
        104: errMsg := 'File not open for input';
        105: errMsg := 'File not open for output';
        106: errMsg := 'Invalid numeric format';
        150: errMsg := 'Disk is write-protected';
        151: errMsg := 'Bad drive request struct length';
        152: errMsg := 'Drive not ready';
        154: errMsg := 'CRC error in data';
        156: errMsg := 'Disk seek error';
        157: errMsg := 'Unknown media type';
        158: errMsg := 'Sector Not Found';
        159: errMsg := 'Printer out of paper';
        160: errMsg := 'Device write fault';
        161: errMsg := 'Device read fault';
        162: errMsg := 'Hardware failure';
        200: errMsg := 'Division by zero';
        201: errMsg := 'Range check error';
        202: errMsg := 'Stack overflow error';
        203: errMsg := 'Heap overflow error';
        204: errMsg := 'Invalid pointer operation';
        205: errMsg := 'Floating point overflow';
        206: errMsg := 'Floating point underflow';
        207: errMsg := 'Invalid floating point operation';
        208: errMsg := 'Overlay manager not installed';
        209: errMsg := 'Overlay file read error';
        210: errMsg := 'Object not initialized';
        211: errMsg := 'Call to abstract method';
        212: errMsg := 'Stream registration error';
        213: errMsg := 'Collection index out of range';
        214: errMsg := 'Collection overflow error';
        215: errMsg := 'Arithmetic overflow error';
        216: errMsg := 'General Protection fault';
        else errMsg := 'Unknown error code';
        end;
        scr.push;
        scrui.msg_box(ctx.current^.config^.color.top_hl, 'Error', '#' + itoa(errCode) + ': ' + errMsg, '[ OK ]');
        scr.show;
        kbd.reset;
        while true do begin
                case kbd.getkey of
                K_ESC: break;
                K_ENTER: break;
                end;
        end;
        scr.pop;
end;

end.

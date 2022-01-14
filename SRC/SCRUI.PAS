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
unit scrui;

interface

uses event;

type
ANSWER = (YES, NO, CANCEL, RETRY, IGNORE, ALL, MAYBE, IDONTKNOWN, ASKMETOMORROW);

procedure box(x, y, w, h :integer; clr:byte);
procedure vmenu(var e : TEvent;x, y, w, h :integer; mclr, sclr:byte; title : string; mtext:pchar; var selItem:integer);
procedure editstr(var e : TEvent; x, y : integer; clr:byte; var str : string; vislen, maxlen:integer);

function yes_no : ANSWER;
function yes_no_cancel:ANSWER;
function yes_no_all:ANSWER;

procedure msg_box(color : byte; title, content, bottom : string);
function in_bound(x1, y1, x2, y2 : integer; x, y : integer):boolean;

implementation

uses scr, kbd, strutil, wincb;

procedure box(x, y, w, h :integer; clr:byte);
begin
        scr.hprint(x, y, clr, #$C4, w);
        scr.hprint(x, y + h - 1, clr, #$C4, w);
        scr.vprint(x, y, clr, #$B3, h);
        scr.vprint(x + w - 1, y, clr, #$B3, h);

        scr.hprint(x, y, clr, #$DA, 1);
        scr.hprint(x + w - 1, y, clr, #$BF, 1);

        scr.hprint(x, y + h - 1, clr, #$C0, 1);
        scr.hprint(x + w - 1, y + h - 1, clr, #$D9, 1);
end;

function in_bound(x1, y1, x2, y2 : integer; x, y : integer):boolean;
begin
        in_bound := (x1 <= x) and (x <= x2)
                        and (y1 <= y) and (y <= y2);
end;

procedure vmenu(var e : TEvent;x, y, w, h :integer; mclr, sclr:byte; title : string; mtext:pchar; var selItem:integer);
var     i, total : integer;
        scr_ofs  : integer;
        scr_y    : integer;
        tmp      : pchar;
        s        : string;
        c        : byte;
        hi_key   : byte;
begin
        scr.cursor_off;
        scr.push;
        scrui.box(x, y, w, h, mclr);
        if length(title) <> 0 then scr.print(x + 1, y, mclr, '['+#$FE+'] ' + title + ' ');
        inc(x);
        inc(y);
        dec(w, 2);
        dec(h, 2);

        total := 0;
        tmp := mtext;
        while tmp[0] <> #0 do begin
                if tmp[0] = #$0a then inc(total);
                inc(tmp);
        end;
        while true do begin
                for i := 1 to h do scr.hprint(x, y + i - 1, mclr, ' ', w);
                scr_ofs := selItem div h;
                scr_ofs := scr_ofs * h;
                scr_y := selItem mod h;
                tmp := mtext;
                i := 0;
                while tmp[0] <> #0 do begin
                        if (i >= scr_ofs) and (i < (scr_ofs + h)) then begin
                                s := '';
                                while (tmp[0] <> #0) and (tmp[0] <> #$0a) do begin
                                        if (tmp[0] <> #$0d) then s := s + tmp[0];
                                        inc(tmp);
                                end;
                                if length(s) > w then s := copy(s, 1, w);
                                while length(s) < w do s := s + ' ';
                                if i = scr_ofs + scr_y then c := sclr else c := mclr;
                                scr.print(x, y + i - scr_ofs, c, s);
                        end else begin
                                while (tmp[0] <> #0) and (tmp[0] <> #$0a) do inc(tmp);
                        end;
                        inc(i);
                        if tmp[0] <> #0 then inc(tmp);
                        if i >= (scr_ofs + h) then break;
                end;
                scr.show;
                kbd.reset;
                while true do begin
                        wait_event(e);
                        if e.etype = KEYBOARD then break;
                        if e.etype = MOUSE_PRESS_B1 then begin
                                if in_bound(x, y, x + w, y + h,
                                   e.mouse_x, e.mouse_y)
                                   and (scr_ofs + (e.mouse_y - y) <= total) then begin
                                   e.etype := KEYBOARD;
                                   e.scancode := SCAN_ENTER;
                                   e.ascii := #$0D;
                                   selItem := scr_ofs + (e.mouse_y - y);
                                   break;
                                end else if in_bound(x - 1, y - 1, x + w + 1, y + h - 1,
                                   e.mouse_x, e.mouse_y) then begin
                                   continue;
                                end else break;
                        end;
                end;
                if e.etype <> KEYBOARD then break;
                if e.is_shift or e.is_ctrl or e.is_alt then break;
                case e.scancode of
                SCAN_UP: begin
                        if selItem <> 0 then dec(selItem);
                end;
                SCAN_HOME: begin
                        selItem := 0;
                end;
                SCAN_END: begin
                        selItem := total;
                end;
                SCAN_DOWN: begin
                        if selItem <> total then inc(selItem);
                end;
                SCAN_PGUP: begin
                        if selItem >= h then dec(selItem, h) else selItem := 0;
                end;
                SCAN_PGDN: begin
                        if total - h > selItem then inc(selItem, h) else selItem := total;
                end else break;
                end;
        end;
        scr.pop;
end;

function del_selected(var str : string; pos, selb, sele : integer) : integer;
var     mselb, msele, len : integer;
begin
        len := length(str);
        if (selb <> 0) and (sele <> 0) and (selb <> sele) and (len <> 0) then begin
                if selb <= sele then begin
                        mselb := selb;
                        msele := sele;
                end else begin
                        mselb := sele;
                        msele := selb;
                end;
                if (mselb > 0) and (msele <= len + 1) then begin
                        delete(str, mselb, msele - mselb);
                        pos := mselb;
                end;
        end;
        del_selected := pos;
end;

function copy_selected(var str : string; selb, sele : integer) : boolean;
var     cbdata       : string;
        r            : boolean;
        mselb, msele : integer;
begin
        r := false;
        cbdata := '';
        if (selb <> 0) and (sele <> 0) and (selb <> sele) then begin
                if selb <= sele then begin
                        mselb := selb;
                        msele := sele;
                end else begin
                        mselb := sele;
                        msele := selb;
                end;
                cbdata := Copy(str, mselb, msele - mselb);
        end;
        if not (cbdata[0] in [#0, #255]) then begin
                cbdata := cbdata + #0;
                WCB_Copy(cbdata[1], ORD(cbdata[0]));
                r := true;
        end;
        copy_selected := r;
end;

procedure editstr(var e : TEvent; x, y : integer; clr:byte; var str : string; vislen, maxlen:integer);
var     visstr : string;
        save_cursor  : word;
        pos, i       : integer;
        selb, sele   : integer;
        selsb, selse : integer;
        ofs_x        : integer;
        hi_key       : word;
        has_cb       : boolean;
        cbdata       : string;
        cbsize       : longint;
begin
        has_cb := WCB_Detect;
        save_cursor := scr.get_cursor;
        scr.set_cursor(scr.cursor);
        pos := length(str) + 1;
        ofs_x := 0;
        selb := 0;
        sele := 0;
        while true do begin
                if pos - ofs_x > vislen then ofs_x := pos - vislen - 1;
                if ofs_x + 1 > pos then ofs_x := pos - 1;
                if ofs_x < 0 then ofs_x := 0;
                visstr := copy(str, ofs_x + 1, vislen);
                locate(x + pos - ofs_x - 1, y);
                visstr := rpad(visstr, vislen);
                scr.print(x, y, clr, visstr);
                selsb := 0;
                selse := 0;
                if (selb <> 0) and (sele <> 0) then begin
                        if selb < sele then begin
                                selsb := selb;
                                selse := sele;
                        end else begin
                                selsb := sele;
                                selse := selb;
                        end;
                        dec(selse, selsb);
                        if selse > vislen then selse := vislen;
                        if selsb > ofs_x then dec(selsb, ofs_x);
                        scr.chcolor(x + selsb - 1, y
                                , ((clr shr 4) and $0F) or ((clr shl 4) and $F0)
                                , selse);
                end;
                scr.show;
                kbd.reset;
                wait_event(e);
                if e.etype = KEYBOARD then begin
                        hi_key := e.scancode;
                        if e.is_ctrl and (not e.is_shift) and (not e.is_alt) then begin
                                case e.scancode of
                                SCAN_C: if has_cb then begin
                                        copy_selected(str, selb, sele);
                                end;
                                SCAN_V: if has_cb then if WCB_Paste(cbdata[1], 254) then begin
                                                cbdata[0] := #0;
                                                WHILE cbdata[ORD(cbdata[0]) + 1] <> #0 Do Inc(cbdata[0]);
                                                i := 1;
                                                pos := del_selected(str, pos, selb, sele);
                                                WHILE (Length(str) < 255) AND (i <= Length(cbdata)) DO BEGIN
                                                        IF cbdata[i] >= ' ' THEN BEGIN
                                                                System.insert(cbdata[i], str, pos);
                                                                Inc(pos);
                                                        END ELSE IF cbdata[i] = #9 THEN BEGIN
                                                                System.insert(' ', str, pos);
                                                                Inc(pos);
                                                        END;
                                                        Inc(i);
                                                END;
                                                selb := 0;
                                                sele := 0;
                                end;
                                SCAN_X: if has_cb and copy_selected(str, selb, sele) then begin
                                                pos := del_selected(str, pos, selb, sele);
                                                selb := 0;
                                                sele := 0;
                                end;
                                SCAN_A: if length(str) > 0 then begin
                                                selb := 1;
                                                sele := length(str) + 1;
                                                pos := sele;
                                end;
                                end;
                                continue;
                        end;
                        if e.is_ctrl or e.is_alt then continue;
                        case e.scancode of
                        SCAN_BS: begin
                                if (selb = 0) and (sele = 0) then begin
                                        if (length(str) <> 0) and (pos > 1) then begin
                                                delete(str, pos - 1, 1);
                                                dec(pos);
                                        end;
                                end else pos := del_selected(str, pos, selb, sele);
                                selb := 0;
                                sele := 0;
                        end;
                        SCAN_DEL: begin
                                if (selb = 0) and (sele = 0) then begin
                                        if (length(str) + 1 <> pos) then begin
                                                delete(str, pos, 1);
                                        end;
                                end else pos := del_selected(str, pos, selb, sele);
                                selb := 0;
                                sele := 0;
                        end;
                        SCAN_HOME: begin
                                if e.is_shift and (selb = 0) then selb := pos;
                                pos := 1;
                                ofs_x := 0;
                                if e.is_shift then sele := pos;
                                if not e.is_shift then begin selb := 0; sele := 0; end;
                        end;
                        SCAN_END: begin
                                if e.is_shift and (selb = 0) then selb := pos;
                                pos := length(str) + 1;
                                ofs_x := 0;
                                if e.is_shift then sele := pos;
                                if not e.is_shift then begin selb := 0; sele := 0; end;
                        end;
                        SCAN_LEFT: begin
                                if e.is_shift and (selb = 0) then selb := pos;
                                if pos > 1 then dec(pos);
                                if e.is_shift then sele := pos;
                                if not e.is_shift then begin selb := 0; sele := 0; end;
                        end;
                        SCAN_RIGHT: begin
                                if e.is_shift and (selb = 0) then selb := pos;
                                if pos <= length(str) then inc(pos);
                                if e.is_shift then sele := pos;
                                if not e.is_shift then begin selb := 0; sele := 0; end;
                        end;
                        SCAN_ENTER: break;
                        SCAN_ESC: break;
                        SCAN_TAB: break;
                        0, 2..$39: begin
                                pos := del_selected(str, pos, selb, sele);
                                selb := 0;
                                sele := 0;
                                if length(str) <> maxlen then begin
                                        System.insert(e.ascii, str, pos);
                                        inc(pos);
                                end;
                                selb := 0;
                                sele := 0;
                        end;
                        end;
                end else if (e.etype = MOUSE_PRESS_B1)
                        and (e.mouse_y = y)
                        and (e.mouse_x >= x) and (e.mouse_x < x + vislen)
                        then begin
                                pos := ofs_x + (e.mouse_x - x) + 1;
                                selb := 0;
                                sele := 0;
                end else if (e.etype = MOUSE_RELEASE_B1)
                        and (e.mouse_y = y)
                        and (e.mouse_x >= x) and (e.mouse_x < x + vislen)
                        then begin
                                selb := 0;
                                sele := 0;
                end else if e.etype <> MOUSE_MOVE then break;
        end;
        scr.set_cursor(save_cursor);
end;

function yes_no : ANSWER;
var r : ANSWER;
        w        : word;
begin
        scr.cursor_off;
        r  := MAYBE;
        while r = MAYBE do begin
                kbd.reset;
                case hi(kbd.getkey) of
                SCAN_ESC: r := NO;
                SCAN_N: r := NO;
                SCAN_ENTER: r := YES;
                SCAN_Y: r := YES;
                end;
        end;
        yes_no := r;
end;

function yes_no_cancel:ANSWER;
var r : ANSWER;
        w        : word;
begin
        scr.cursor_off;
        r  := MAYBE;
        while r = MAYBE do begin
                kbd.reset;
                case hi(kbd.getkey) of
                SCAN_ESC: r := CANCEL;
                SCAN_N: r := NO;
                SCAN_ENTER: r := YES;
                SCAN_Y: r := YES;
                SCAN_C: r := CANCEL;
                end;
        end;
        yes_no_cancel := r;
end;

function yes_no_all:ANSWER;
var r : ANSWER;
        w        : word;
begin
        scr.cursor_off;
        r  := MAYBE;
        while r = MAYBE do begin
                kbd.reset;
                case hi(kbd.getkey) of
                SCAN_ESC: r := NO;
                SCAN_N: r := NO;
                SCAN_ENTER: r := YES;
                SCAN_Y: r := YES;
                SCAN_A: r := ALL;
                end;
        end;
        yes_no_all := r;
end;

procedure msg_box(color : byte; title, content, bottom : string);
var
        w : integer;
        h : integer;
        box_h : integer;
        box_w : integer;
        pos_x : integer;
        pos_y : integer;
        needb : boolean;
begin
        w := scr.getwidth;
        h := scr.getheight;
        box_w := 0;
        title := '[' + #$FE+  '] ' + title + ' ';
        content := ' ' + content + ' ';
        if length(content) > w - 4 then content := copy(content, 1, w - 4);
        if length(bottom) > w - 4 then bottom := copy(bottom, 1, w - 4);
        if box_w < length(title) + 1 then box_w := length(title) + 1;
        if box_w < length(content) then box_w := length(content);
        if box_w < length(bottom) then box_w := length(bottom);
        needb := length(bottom) <> 0;
        if box_w > w - 4 then box_w := w - 4;
        box_h := 3;
        if needb then inc(box_h, 2);
        
        pos_x := (w - box_w - 2) shr 1;
        pos_y := (h - box_h - 2) shr 1;
        box(pos_x, pos_y, box_w + 2, box_h + 2, color);
        scr.print(pos_x + 1, pos_y, color, title);
        scr.hprint(pos_x + 1, pos_y + 1, color, ' ', box_w);
        scr.print(pos_x + 1, pos_y + 2, color, content);
        scr.hprint(pos_x + 1, pos_y + 3, color, ' ', box_w);
        if needb then begin
                scr.hprint(pos_x + 1, pos_y + 4, color, ' ', box_w);
                scr.print((w - length(bottom)) shr 1, pos_y + 4, color, bottom);
                scr.hprint(pos_x + 1, pos_y + 5, color, ' ', box_w);
        end;
end;

end.
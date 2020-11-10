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
{$G-,S-,R-,I-}
unit scrui;

interface

type
ANSWER = (YES, NO, CANCEL, RETRY, ALL, MAYBE, IDONTKNOWN, ASKMETOMORROW);

procedure box(x, y, w, h :integer; clr:byte);
function vmenu(x, y, w, h :integer; mclr, sclr:byte; mtext:pchar; var selItem:integer):word;
function hmenu(y : integer;
        mclr, sclr : byte;
        mtext : pchar;
        var selx:integer; var sely:integer;
        var lineId : String):word;

function editstr(x, y : integer; clr:byte; var str : string; vislen, maxlen:integer):word;

function yes_no : ANSWER;
function yes_no_cancel:ANSWER;

implementation

uses scr, kbd, strutil;

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

function vmenu(x, y, w, h :integer; mclr, sclr:byte; mtext:pchar; var selItem:integer):word;
var key : word;
        i, total : integer;
        scr_ofs : integer;
        scr_y : integer;
        tmp : pchar;
        s : string;
        c : byte;
        hi_key : byte;
begin
        scr.cursor_off;
        scr.push_buf;
        scrui.box(x, y, w, h, mclr);
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
                key := getkey;
                if is_shift or is_ctrl or is_alt then break;
                hi_key := hi(key);
                if hi_key = hi(K_UP) then begin
                        if selItem <> 0 then dec(selItem);
                end else if hi_key = hi(K_HOME) then begin
                        selItem := 0;
                end else if hi_key = hi(K_END) then begin
                        selItem := total;
                end else if hi_key = hi(K_DOWN) then begin
                        if selItem <> total then inc(selItem);
                end else if hi_key = hi(K_PGUP) then begin
                        if selItem >= h then dec(selItem, h) else selItem := 0;
                end else if hi_key = hi(K_PGDN) then begin
                        if total - h > selItem then inc(selItem, h) else selItem := total;
                end else break;
        end;
        scr.pop_buf;
        vmenu := key;
end;

function hmenu(y : integer;
        mclr, sclr : byte;
        mtext : pchar;
        var selx:integer; var sely:integer;
        var lineId : String):word;
var key : word;
        hi_key : byte;
begin
        lineId := '';
        scr.push_buf;
        while true do begin
                scr.pick_buf;
                scr.show;
                key := getkey;
                if is_shift or is_ctrl or is_alt then break;
                hi_key := hi(key);
                if hi_key = hi(K_UP) then begin
                end else if hi_key = hi(K_DOWN) then begin
                end else if hi_key = hi(K_LEFT) then begin
                end else if hi_key = hi(K_RIGHT) then begin
                end else break;
        end;
        scr.pop_buf;
        hmenu := key;
end;

function editstr(x, y : integer; clr:byte; var str : string; vislen, maxlen:integer):word;
var key : word;
    visstr : string;
    save_cursor_start : byte;
    save_cursor_end   : byte;
begin
        save_cursor_start := scr.get_cursor_start;
        save_cursor_end := scr.get_cursor_end;
        scr.set_cursor(scr.cursor_start, scr.cursor_end);
        while true do begin
                visstr := str;
                if length(visstr) > vislen then visstr := copy(visstr, length(visstr) - vislen, vislen);
                locate(x + length(visstr), y);
                visstr := rpad(visstr, vislen);
                scr.print(x, y, clr, visstr);
                scr.show;
                kbd.reset;
                key := getkey;
                if (key = K_BS) then begin
                        if  length(str)<>0 then str := copy(str, 1, length(str) - 1);
                end else if lo(key) >= 32 then begin
                        if length(str) <> maxlen then begin
                                str := str + chr(lo(key));
                        end;
                end else break;
        end;
        scr.set_cursor(save_cursor_start, save_cursor_end);
        editstr := key;
end;

function yes_no : ANSWER;
var r : ANSWER;
        w        : word;
begin
        scr.cursor_off;
        r  := MAYBE;
        while r = MAYBE do begin
                kbd.reset;
                w := kbd.getkey;
                if hi(w) = hi(K_ESC) then r := NO;
                if hi(w) = $31 then r := NO;
                if hi(w) = hi(K_ENTER) then r := YES;
                if hi(w) = $15 then r := YES;
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
                w := kbd.getkey;
                if hi(w) = hi(K_ESC) then r := CANCEL;
                if hi(w) = $31 then r := NO;
                if hi(w) = hi(K_ENTER) then r := YES;
                if hi(w) = $15 then r := YES;
                if hi(w) = $2E then r := CANCEL;
        end;
        yes_no_cancel := r;
end;

end.

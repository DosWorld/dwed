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
unit dwedaddo;

interface

uses scr, scrui, kbd, strs, strutil, lfn, dwedtype, event;

procedure addons_window(var ctx : TEditorContext);
procedure ascii_table(var ctx : TEditorContext);
procedure calculator(var ctx : TEditorContext);

implementation
type
RadixType = (RADIX2, RADIX10, RADIX16);

const addons_menu : pchar =
' ASCII-Table        Ctrl+Alt+A ' + #$0A +
' Calculator         Ctrl+Alt+C '
;

procedure addons_window(var ctx : TEditorContext);
var sitem : integer;
    e     : TEvent;
begin
        scr.push;
        sitem := 0;
        while true do begin
                scrui.vmenu(e, 1, 2, 33, scr.getheight - 3,
                        ctx.config.color.menu,
                        ctx.config.color.menu_sel,
                        'Addons',
                        addons_menu, sitem);
                if e.etype in [MOUSE_PRESS_B1, MOUSE_PRESS_B2] then begin sitem := -1; break; end;
                if e.etype <> KEYBOARD then continue;
                if e.scancode = SCAN_ESC then begin sitem := -1; break; end;
                if (e.scancode = SCAN_ENTER) or (e.ascii = ' ') then break;
        end;
        scr.pop;
        if sitem = -1 then exit;
        case sitem of
        0 : ascii_table(ctx);
        1 : calculator(ctx);
        end;
end;

procedure insert_str(var ctx : TEditorContext; str : string);
var     line_len : integer;
        str_len  : integer;
begin
        line_len := length(ctx.current^.editor.line);
        str_len := length(str);
        if line_len + str_len > 255 then str_len := 255 - line_len;
        str := copy(str, 1, str_len);

        System.insert(str, ctx.current^.editor.line, ctx.current^.editor.x);
        ctx.current^.editor.chg := true;
        ctx.current^.chg := true;
        inc(ctx.current^.editor.x, str_len);
end;

const ascii_tbl_sel : byte = 0;

procedure ascii_table(var ctx : TEditorContext);
var        x, y, i, j : integer;
        b       : boolean;
        color   : byte;
        cb      : byte;
        ch      : char;
        e       : TEvent;
begin
        x := (scr.getwidth - 50) shr 1; y := (scr.getheight - 22) shr 1;
        scrui.box(x, y, 50, 22, $1b);
        while true do begin
                for i := 1 to 20 do scr.hprint(x + 1, y + i, $1b, ' ', 48);
                for i := 0 to 15 do begin
                        b := (i and 1) = 0;
                        for j := 0 to 15 do begin
                                if b then color := $17 else color := $1e;
                                cb := j or (i shl 4);
                                scr.hprint(x + 2 + j * 3, y + 3 + i, color, chr(cb) , 1);
                                if cb = ascii_tbl_sel then scr.chcolor(x + 1 + j * 3, y + 3 + i, $31, 3);
                                b := not b;
                        end;
                end;
                scr.hprint(x + 1, y + 2, $1b, #$C4 , 48);
                scr.hprint(x + 1, y + 19, $1b, #$C4 , 48);
                printhl(x + 2, y + 1, $1b, $1e, concat(
                        'Hex: ~',
                        hexb(ascii_tbl_sel),
                        '~ Dec: ~',
                        lpad(itoa(ascii_tbl_sel), 3),
                        '~ Bin: ~',
                        binb(ascii_tbl_sel),
                        '~ Oct: ~',
                        octb(ascii_tbl_sel),
                        '~  Color'
                        ));
                scr.chcolor(x + 43, y + 1, ascii_tbl_sel, 5);
                scr.printhl(x + 2, y + 20, $1b, $1e, 
                        '~'+#$11+#$D9+'~ Enter symbol     ' + #$B3 +
                        '  ~Shift~+~'+#$11+#$D9+'~ Enter hex code'
                        );
                scr.show;
                while true do begin
                        wait_event(e);
                        if e.etype = KEYBOARD then break;
                end;
                case e.scancode of
                SCAN_UP: dec(ascii_tbl_sel, 16);
                SCAN_DOWN: inc(ascii_tbl_sel, 16);
                SCAN_LEFT: ascii_tbl_sel := (ascii_tbl_sel and $F0) or ((ascii_tbl_sel - 1) and $0F);
                SCAN_RIGHT: ascii_tbl_sel := (ascii_tbl_sel and $F0) or ((ascii_tbl_sel + 1) and $0F);
                SCAN_ENTER: begin
                        if e.is_shift then begin
                                insert_str(ctx, '' + hexb(ascii_tbl_sel));
                                break;
                        end else begin
                                if (ascii_tbl_sel = 9)
                                  or (ascii_tbl_sel = 0)
                                  or (ascii_tbl_sel = $0a)
                                  or (ascii_tbl_sel = $0d) then continue;
                                insert_str(ctx, '' + chr(ascii_tbl_sel));
                                break;
                        end;
                end;
                SCAN_ESC: break;
                else begin
                        ch := upcase(e.ascii);
                        if ch in ['0'..'9'] then
                                ascii_tbl_sel := (ascii_tbl_sel shl 4)
                                        or ((ord(ch) - ord('0')) and $0F)
                        else if ch in ['A'..'F'] then
                                ascii_tbl_sel := (ascii_tbl_sel shl 4)
                                        or ((ord(ch) - ord('A') + 10) and $0F);
                end;
                end;
        end;
end;

const
calc_op1 : longint = 0;
calc_op2 : longint = 0;
calc_op  : char = ' ';
radix    : RadixType = RADIX10;

procedure calculator(var ctx : TEditorContext);
var x, y, i : integer;
        key        : word;
        ch         : char;
        insertStr  : string;
        e          : TEvent;
begin
        scr.set_cursor(scr.cursor);
        x := (scr.getwidth - 41) shr 1;
        y := (scr.getheight - 10) shr 1;
        insertStr := '';
        scrui.box(x, y, 41, 10, $1b);
        for i := 1 to 8 do scr.hprint(x + 1, y + i, $1b, ' ', 39);
        scr.printhl(x + 2, y + 1, $1b, $1e, 'Dec~:');
        scr.printhl(x + 2, y + 2, $1b, $1e, 'Hex~:');
        scr.printhl(x + 2, y + 3, $1b, $1e, 'Bin~:');
        scr.hprint(x + 1, y + 4, $1b, #$C4 , 39);
        scr.printhl(x + 2, y + 5, $1b, $1e, '~+~ Add   ~-~ Sub   ~*~ Mul   ~/~ Div   ~M~ Mod');
        scr.printhl(x + 2, y + 6, $1b, $1e, '~&~ And   ~|~ Or    ~^~ Xor   ~!~ Not   ~N~ Neg');
        scr.hprint(x + 1, y + 7, $1b, #$C4 , 39);
        scr.printhl(x + 2, y + 8, $1b, $1e, '~C~ Clr   ~'+#$1D+'~ Rdx    ~Shift~+~'+#$11+#$D9+'~ Enter value');
        while true do begin
                scr.vprint(x + 6, y + 1,  $1b, ' ', 3);
                if radix = RADIX10 then begin scr.print(x + 6, y + 1, $1e, '' + #$10); locate(x + 39, y + 1); end
                else if radix = RADIX16 then begin scr.print(x + 6, y + 2, $1e, '' + #$10); locate(x + 39, y + 2); end
                else if radix = RADIX2  then begin scr.print(x + 6, y + 3, $1e, '' + #$10); locate(x + 39, y + 3); end;
                scr.print(x + 7, y + 1, $1b, lpad(ltoa(calc_op1), 32));
                scr.print(x + 7, y + 2, $1b, lpad(hexdw(calc_op1), 32));
                scr.print(x + 7, y + 3, $1b, lpad(bindw(calc_op1), 32));

                scr.chcolor(x + 7 + 20, y + 1, $1A, 3);
                scr.chcolor(x + 7 + 26, y + 1, $1A, 3);

                scr.chcolor(x + 7 + 24, y + 2, $1E, 2);
                scr.chcolor(x + 7 + 28, y + 2, $1E, 2);
                scr.chcolor(x + 7, y + 3, $1E, 8);
                scr.chcolor(x + 7 + 16, y + 3, $1E, 8);
                scr.show;
                while true do begin
                        wait_event(e);
                        if e.etype = KEYBOARD then break;
                end;
                case e.scancode of
                SCAN_ESC: begin insertStr := ''; break; end;
                SCAN_ENTER: begin
                        if not e.is_shift then begin
                                case calc_op of
                                '+': calc_op1 := calc_op2 + calc_op1;
                                '-': calc_op1 := calc_op2 - calc_op1;
                                '*': calc_op1 := calc_op2 * calc_op1;
                                '/': calc_op1 := calc_op2 div calc_op1;
                                'M': calc_op1 := calc_op2 mod calc_op1;
                                '&': calc_op1 := calc_op2 and calc_op1;
                                '|': calc_op1 := calc_op2 or calc_op1;
                                '^': calc_op1 := calc_op2 xor calc_op1;
                                end;
                        end else begin
                                if radix = RADIX10 then insert_str(ctx, ltoa(calc_op1))
                                else if radix = RADIX16 then insert_str(ctx, hexdw(calc_op1))
                                else if radix = RADIX2 then insert_str(ctx, bindw(calc_op1));
                                break;
                        end;
                end;
                SCAN_TAB: begin
                        if radix = RADIX10 then radix := RADIX16
                        else if radix = RADIX16 then radix := RADIX2
                        else if radix = RADIX2 then radix := RADIX10;
                end;
                SCAN_BS: begin
                        if radix = RADIX2 then calc_op1 := calc_op1 shr 1
                        else if radix = RADIX10 then calc_op1 := calc_op1 div 10
                        else if radix = RADIX16 then calc_op1 := calc_op1 shr 8;
                end;
                end;
                ch := upcase(e.ascii);
                case ch of
                'C': begin calc_op1 := 0; continue; end;
                '+','-','*','/','M','&','|','^': begin calc_op := ch; calc_op2 := calc_op1; calc_op1 := 0; continue; end;
                'N': calc_op1 := -calc_op1;
                '!': calc_op1 := calc_op1 xor $FFFFFFFF;
                end;
                case radix of
                RADIX2 : begin
                                if ch in ['0'..'1'] then calc_op1 := (calc_op1 shl 1) or (ord(ch) - ord('0'));
                end;
                RADIX10 : begin
                                if ch in ['0'..'9'] then begin
                                        if calc_op1 >= 0 then calc_op1 := (calc_op1 * 10) + (ord(ch) - ord('0'))
                                        else calc_op1 := (calc_op1 * 10) - (ord(ch) - ord('0'));
                                end;
                        end;
                RADIX16: begin
                                if ch in ['0'..'9'] then calc_op1 := (calc_op1 shl 4) or (ord(ch) - ord('0'));
                                if ch in ['A'..'F'] then calc_op1 := (calc_op1 shl 4) or (ord(ch) - ord('A'));
                        end;
                end;
        end;
        if length(insertStr) <> 0 then begin
        end;

end;

end.

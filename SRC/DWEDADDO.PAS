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
unit dwedaddo;

interface

uses scr, scrui, kbd, strs, strutil, lfn, dwedtype;

procedure addons_window(var ctx : TEditorContext);
procedure ascii_table(var ctx : TEditorContext);
procedure calculator(var ctx : TEditorContext);

implementation

const addons_menu : pchar =
' ASCII-Table        Ctrl+Alt+A ' {+#$0A+
' Calculator         Ctrl+Alt+C ' };

procedure addons_window(var ctx : TEditorContext);
var sitem : integer;
    key : word;
begin
        scr.push;
        sitem := 0;
        while true do begin
                key := scrui.vmenu(1, 2, 33, scr.getheight - 3,
                        ctx.config.color.menu,
                        ctx.config.color.menu_sel,
                        'Addons',
                        addons_menu, sitem);
                if key = K_ESC then begin sitem := -1; break; end;
                if (key = K_ENTER) or (lo(key) = 32) then break;
        end;
        scr.pop;
        if sitem = -1 then exit;
        case sitem of
        0 : ascii_table(ctx);
        0 : calculator(ctx);
        end;
end;

const ascii_tbl_sel : byte = 0;

procedure ascii_table(var ctx : TEditorContext);
var        x, y, i, j : integer;
        b       : boolean;
        color   : byte;
        key     : word;
        cb      : byte;
        hval    : string[3];
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
                case kbd.getkey of
                K_UP: dec(ascii_tbl_sel, 16);
                K_DOWN: inc(ascii_tbl_sel, 16);
                K_LEFT: dec(ascii_tbl_sel);
                K_RIGHT: inc(ascii_tbl_sel);
                K_ENTER: begin
                        if kbd.is_shift then begin
                                if ctx.ins then begin
                                        if length(ctx.current^.editor.line) +2 >= 255 then continue;
                                        System.insert(hexb(ascii_tbl_sel), ctx.current^.editor.line, ctx.current^.editor.x);
                                        ctx.current^.editor.chg := true;
                                        ctx.current^.chg := true;
                                end else begin
                                        if length(ctx.current^.editor.line) < ctx.current^.editor.x + 1 then continue;
                                        hval := hexb(ascii_tbl_sel);
                                        ctx.current^.editor.line[ctx.current^.editor.x] := hval[1];
                                        ctx.current^.editor.line[ctx.current^.editor.x + 1] := hval[2];
                                        ctx.current^.editor.chg := true;
                                        ctx.current^.chg := true;
                                end;
                                inc(ctx.current^.editor.x, 2);
                                break;
                        end else begin
                                if (ascii_tbl_sel = 9)
                                  or (ascii_tbl_sel = 0)
                                  or (ascii_tbl_sel = $0a)
                                  or (ascii_tbl_sel = $0d) then continue;
                                if ctx.ins then begin
                                        if length(ctx.current^.editor.line) = 255 then continue;
                                        System.insert('' + chr(ascii_tbl_sel),
                                             ctx.current^.editor.line,
                                             ctx.current^.editor.x);
                                        ctx.current^.editor.chg := true;
                                        ctx.current^.chg := true;
                                end else begin
                                        if length(ctx.current^.editor.line) < ctx.current^.editor.x then continue;
                                        ctx.current^.editor.line[ctx.current^.editor.x] := chr(ascii_tbl_sel);
                                        ctx.current^.editor.chg := true;
                                        ctx.current^.chg := true;
                                end;
                                inc(ctx.current^.editor.x);
                                break;
                        end;
                end;
                K_ESC: break;
                end;
        end;
end;

const
calc_op1 : longint = 0;
calc_op2 : longint = 0;

procedure calculator(var ctx : TEditorContext);
var x, y, i : integer;
begin
        x := 1; y := 2;
        scrui.box(x, y, 50, 22, $1b);
        for i := 1 to 20 do scr.hprint(x + 1, y + i, $1b, ' ', 48);
        scr.printhl(x + 1, y + 1, $1b, $1e, '   Dec~:~ ' + ltoa(calc_op1));
        scr.printhl(x + 1, y + 2, $1b, $1e, ' ~'+#$10+'~ Hex~:~ ' + hexdw(calc_op1));
        scr.printhl(x + 1, y + 3, $1b, $1e, '   Bin~:~ ' + hexdw(calc_op1));
        scr.hprint(x + 1, y + 4, $1b, #$C4 , 48);
        scr.printhl(x + 2, y + 5, $1b, $1e, '~+~ Add ' + #$B3 + ' ~-~ Sub ' + #$B3 + ' ~*~ Mul ' + #$B3 + ' ~/~: Div');
        scr.printhl(x + 2, y + 6, $1b, $1e, '~&~ And ' + #$B3 + ' ~|~ Or  ' + #$B3 + ' ~^~ Xor ' + #$B3 + ' ~!~: Not');
        scr.printhl(x + 2, y + 7, $1b, $1e, '~M~ Mod ' + #$B3 + ' ~=~ Evl ' + #$B3 + ' ~C~ Clr ' + #$B3 + ' ');
        scr.hprint(x + 1, y + 8, $1b, #$C4 , 48);
        scr.printhl(x + 2, y + 9, $1b, $1e, '~TAB~ Chg radix '+#$B3+' ~Shift~+~'+#$11+#$D9+'~ Enter value');
        scr.show;
        kbd.getkey;
end;

end.

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
{$M 16000, 128000, 655360}
{$G-,B-,S-,R-,I-}

uses scr, kbd, strs, strutil, lfn, dwedtype, dwedhndl, dwedutil, dwedhl, dwedscru;

procedure read_event(var event : TEvent);
begin
        with event do begin
                key := kbd.getkey;
                is_shift := kbd.is_shift;
                is_alt := kbd.is_alt;
                is_ctrl := kbd.is_ctrl;
        end;
end;

procedure edit(var ctx : TEditorContext);
var k, i, scru  :integer;
        event   : TEvent;
begin
        scr.push;
        scru := SCRU_FULL;
        while scru <> SCRU_QUIT do begin
                dwedscru.update(ctx, scru);
                scru := SCRU_NONE;

                if not kbd.haskey then begin
                        read_event(event);
                        scru := process_event(ctx, event);
                end else begin
                        i := 0;
                        while kbd.haskey and (i < 8) do begin
                                read_event(event);
                                k := process_event(ctx, event);
                                if k > scru then scru := k;
                                inc(i);
                        end;
                end;
        end;
        scr.pop;
end;

procedure reset_context(var ctx : TEditorContext);
begin
        with ctx do begin
                all := nil;
                current := nil;
                ins := true;
                config.width := scr.getwidth;
                config.height := scr.getheight;
                config.tab_size := 8;
                config.color.top    := $70;
                config.color.top_hl := $74;
                config.color.text := $87;
                config.color.text_hl := $83;
                config.color.text_sel := $17;
                config.color.menu := $70;
                config.color.menu_sel := $0F;
                config.color.help_menu := $87;
                config.color.help_menu_sel := $07;
                config.color.help := $87;
                config.color.help_hl := $83;
                clipboard[0] := #0;
                search := '';
                replace := '';
                help_topic_id := 0;
        end;
end;

procedure process_param(var ctx : TEditorContext; key, value : string);
begin
        writeln('Key = [', key, ']');
        writeln('Value = [', value, ']');
end;

procedure split(var param, key, value : string);
var        i : integer;
begin
        key := '';
        value := '';
        for i := 1 to length(param) do begin
                if param[i] = '=' then begin
                        key := copy(param, 1, i - 1);
                        value := copy(param, i + 1, length(param) - i);
                        break;
                end;
        end;
        if (length(key) = 0) and (length(value) = 0) then key := param;
        key := upstr(key);
end;

function has_switch(var s : string) : boolean;
begin
        has_switch := (length(s) > 0) and (s[1] in ['-', '/']);
end;

var     ctx        : TEditorContext;
        i, pCount  : integer;
        param      : string;
        key, value : string;
        errCode    : integer;
begin
        strs.init(DOS);
        reset_context(ctx);
        pCount := ParamCount;
        for i := 1 to pCount do begin
                param := ParamStr(i);
                if has_switch(param) then begin
                        System.delete(param, 1, 1);
                        split(param, key, value);
                        process_param(ctx, key, value);
                end;
        end;
        for i := 1 to pCount do begin
                param := ParamStr(i);
                if not has_switch(param) then begin
                        load_file(ctx, param, errCode);
                        if errCode <> 0 then handle_error(ctx, errCode);
                end;
        end;
        if ctx.all = nil then new_file(ctx, 'NONAME.TXT');
        edit(ctx);
        scr.set_cursor(scr.cursor_start, scr.cursor_end);
        halt(0);
end.

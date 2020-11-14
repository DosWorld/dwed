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
unit dwedmain;

interface

procedure dwed_main(exe_path : string);

implementation

uses scr, kbd, strs, strutil, lfn, dwedtype, dwedhndl, dwedutil, dwedhl, dwedscru, dwedlnch;

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
                config.color.text := $07;
                config.color.text_hl := $03;
                config.color.text_sel := $17;
                config.color.menu := $1b;
                config.color.menu_sel := $30;
                config.color.help_menu := $07;
                config.color.help_menu_sel := $70;
                config.color.help := $07;
                config.color.help_hl := $03;
                config.udef_f5 := '';
                config.udef_f8 := '';
                config.udef_f9 := '';
                getmem(clipboard, CB_SIZE);
                clipboard[0] := #0;
                search := '';
                replace := '';
                help_topic_id := 0;
        end;
end;

procedure process_param(var ctx : TEditorContext; key, value : string);
begin
        if length(key) = 0 then exit;
        if key = 'TAB_SIZE' then ctx.config.tab_size := ahtob(value)
        else if key = 'COLOR.TOP' then ctx.config.color.top := ahtob(value)
        else if key = 'COLOR.TOP_HL' then ctx.config.color.top_hl := ahtob(value)
        else if key = 'COLOR.TEXT' then ctx.config.color.text := ahtob(value)
        else if key = 'COLOR.TEXT_HL' then ctx.config.color.text_hl := ahtob(value)
        else if key = 'COLOR.TEXT_SEL' then ctx.config.color.text_sel := ahtob(value)
        else if key = 'COLOR.MENU' then ctx.config.color.menu := ahtob(value)
        else if key = 'COLOR.MENU_SEL' then ctx.config.color.menu_sel := ahtob(value)
        else if key = 'COLOR.HELP_MENU' then ctx.config.color.help_menu := ahtob(value)
        else if key = 'COLOR.HELP_MENU_SEL' then ctx.config.color.help_menu_sel := ahtob(value)
        else if key = 'COLOR.HELP' then ctx.config.color.help := ahtob(value)
        else if key = 'COLOR.HELP_HL' then ctx.config.color.help_hl := ahtob(value)
        else if key = 'USR.DEF.F5' then ctx.config.udef_f5 := value
        else if key = 'USR.DEF.F8' then ctx.config.udef_f8 := value
        else if key = 'USR.DEF.F9' then ctx.config.udef_f9 := value
        else begin writeln('Unknown parameter ', key, '. Press Enter...'); readln; end;
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
        key := upstr(trim(key));
        value := trim(value);
end;

function has_switch(var s : string) : boolean;
begin
        has_switch := (length(s) > 0) and (s[1] in ['-', '/']);
end;

function load_config(var ctx : TEditorContext; fname : string):boolean;
var f : text;
        i          : integer;
        str        : string;
        key, value : string;
begin
        assign(f, lfn.lfn2dos(fname));
        {$I-}
        System.reset(f);
        i := ioresult;
        {$I+}
        if i = 0 then begin
                while not eof(f) do begin
                        readln(f, str);
                        split(str, key, value);
                        process_param(ctx, key, value);
                end;
                close(f);
        end;
        load_config := i = 0;
end;

procedure dwed_main(exe_path : string);
var     ctx        : TEditorContext;
        i, pCount  : integer;
        param      : string;
        key, value : string;
        errCode    : integer;
begin
        if not dwedlnch.is_installed then begin
                writeln('This program cannot be run in DOS mode.');
                halt(1);
        end;
        strs.init(DOS);
        reset_context(ctx);
        if not load_config(ctx, 'DWED.CFG') then load_config(ctx, exe_path + 'DWED.CFG');
        pCount := ParamCount;
        for i := 1 to pCount do begin
                param := ParamStr(i);
                if has_switch(param) then begin
                        System.delete(param, 1, 1);
                        split(param, key, value);
                        process_param(ctx, key, value);
                end;
        end;
        scr.push;
        scr.cls(7);
        for i := 1 to pCount do begin
                param := ParamStr(i);
                if not has_switch(param) then begin
                        load_file(ctx, param, errCode);
                        if errCode <> 0 then handle_error(ctx, errCode);
                end;
        end;
        if ctx.all = nil then new_file(ctx, 'NONAME.TXT');
        edit(ctx);
        scr.pop;
        scr.show;
        scr.set_cursor(scr.cursor_start, scr.cursor_end);
        halt(0);
end;

end.

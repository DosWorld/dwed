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
unit dwedmain;

interface

procedure dwed_main(exe_path : string);

implementation

uses dos, scr, kbd, strs, strutil, lfn, dwedtype, dwedhndl, dwedutil, dwedhl, dwedscru, dwedlnch, dwedpar, event;

procedure edit(var ctx : TEditorContext; welcome_msg : boolean);
var     scru, prev_scru, i : integer;
        event              : TEvent;
begin
        scru := SCRU_FULL;
        while scru <> SCRU_QUIT do begin
                if scru <> SCRU_NONE then begin
                        dwedscru.update(ctx, scru);
                        if welcome_msg then begin
                                with ctx.current^.config^.color do begin
                                        scr.cln(0, 0, top);
                                        scr.printhl(2, 0, top, top_hl, 'Welcome!  Press ~F1~ for help');
                                end;
                                scr.show;
                                welcome_msg := false;
                        end;
                        scru := SCRU_NONE;
                end;
                if not haskey then begin
                        wait_event(event);
                        scru := process_event(ctx, event);
                end else begin
                        i := 0;
                        prev_scru := 0;
                        while (i < 8) and haskey do begin
                                wait_event(event);
                                scru := process_event(ctx, event);
                                if prev_scru < scru then prev_scru := scru;
                                if (scru <> SCRU_NONE) and (scru <> SCRU_FULL) then begin scru := prev_scru; break; end;
                                inc(i);
                        end;
                end;
        end;
end;

procedure reset_context(var ctx : TEditorContext);
var     f      : file;
        readed : integer;
        path   : string;
begin
        with ctx do begin
                all := nil;
                current := nil;
                ins := true;
                exit_code := 0;
                config.width := scr.getwidth;
                config.height := scr.getheight;
                config.tab_size := 8;
                config.color.top    := $70;
                config.color.top_hl := $74;
                config.color.text_dl := $08;
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
                temp := '';
        end;
        System.assign(f, dwedlnch.DEVFILE);
        System.reset(f, 1);
        if ioresult = 0 then begin
                blockread(f, ctx.temp[0], 256, readed);
                close(f);
        end;
        path := '';
        if length(path) = 0 then path := getenv('TEMP');
        if length(path) = 0 then path := getenv('TMP');
        if (length(path) <> 0) and (path[length(path)] <> '\') then path := path + '\';
        ctx.temp := path + ctx.temp;
        
end;

procedure process_param(var ctx : TEditorContext; key, value : string);
begin
        if length(key) = 0 then exit;
        if key = 'TAB_SIZE' then ctx.config.tab_size := ahtob(value)
        else if key = 'COLOR.TOP' then ctx.config.color.top := ahtob(value)
        else if key = 'COLOR.TOP_HL' then ctx.config.color.top_hl := ahtob(value)
        else if key = 'COLOR.TEXT' then ctx.config.color.text := ahtob(value)
        else if key = 'COLOR.TEXT_HL' then ctx.config.color.text_hl := ahtob(value)
        else if key = 'COLOR.TEXT_DL' then ctx.config.color.text_dl := ahtob(value)
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
        key := trim(key);
        upstr(key);
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
        lfn.assign_text(f, fname);
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

procedure parse_temp(var ctx : TEditorContext);
var   f : text;
      s, ss   : string;
      i, p    : integer;
      errCode : integer;
      x, scrx, scry   : integer;
      cline_num       : longint;
      fname   : string;
begin
        assign_text(f, ctx.temp);
        System.reset(f);
        if ioresult = 0 then while not eof(f) do begin
                readln(f, s);
                i := 1;
                p := 1;
                while (s[p] <> ',') and (p < length(s)) do inc(p);
                ss := copy(s, i, p - i);
                x := atoi(ss, 1);
                inc(p); i := p;

                while (s[p] <> ',') and (p < length(s)) do inc(p);
                ss := copy(s, i, p - i);
                scrx := atoi(ss, 0);
                inc(p); i := p;

                while (s[p] <> ',') and (p < length(s)) do inc(p);
                ss := copy(s, i, p - i);
                scry := atoi(ss, 0);
                inc(p); i := p;

                while (s[p] <> ',') and (p < length(s)) do inc(p);
                ss := copy(s, i, p - i);
                cline_num := atol(ss, 1);
                inc(p);
                fname := copy(s, p, length(s) - p + 1);
                load_file(ctx, fname, errCode, @file_progress);
                if errCode <> 0 then handle_error(ctx, errCode) else begin
                        ctx.current^.editor.x := x;
                        ctx.current^.scrx := scrx;
                        ctx.current^.scry := scry;
                        ctx.current^.cline := strs.find_num(ctx.current^.rline, cline_num);
                        load_ed(ctx);
                        norm_xy(ctx, 0);
                end;
        end;
        close(f);
end;

procedure dwed_main(exe_path : string);
var     ctx         : TEditorContext;
        i, pCount   : integer;
        param       : string;
        key, value  : string;
        errCode     : integer;
        welcome_msg : boolean;
        params      : ParamsContext;
begin
        if not dwedlnch.is_installed then begin
                writeln('This is overlay. Run DWED.EXE or join to the Dark Side.');
                halt(1);
        end;
        strs.init(strs.DOS);
        dwedpar.pinit(params, trim(PString(ptr(PrefixSeg, $80))^));
        reset_context(ctx);
        if not load_config(ctx, 'DWED.CFG') then load_config(ctx, exe_path + 'DWED.CFG');
        dwedpar.preset(params);
        while phas_next(params) do begin
                param := pnext(params);
                if has_switch(param) then begin
                        System.delete(param, 1, 1);
                        split(param, key, value);
                        process_param(ctx, key, value);
                end;
        end;
        scr.push;
        scr.cls(7);
        if lfn.file_exists(ctx.temp) then begin
                welcome_msg := false;
                parse_temp(ctx);
                lfn.file_delete(ctx.temp);
        end else begin
                welcome_msg := true;
                dwedpar.preset(params);
                while phas_next(params) do begin
                        param := pnext(params);
                        if not has_switch(param) then begin
                                load_file(ctx, param, errCode, @file_progress);
                                if errCode <> 0 then handle_error(ctx, errCode);
                        end;
                end;
        end;
        if ctx.all = nil then new_file(ctx, 'NONAME.TXT');
        edit(ctx, welcome_msg);
        scr.pop;
        scr.show;
        scr.set_cursor(scr.cursor);
        halt(ctx.exit_code);
end;

end.

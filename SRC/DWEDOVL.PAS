{ MIT License

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
SOFTWARE. }
{$IFDEF DEBUG}
{$M 16000, 128000, 256000}
{$ENDIF}
{$IFNDEF DEBUG}
{$M 16000, 128000, 655360}
{$ENDIF}

uses system2, dos, str, strutil, wincb, kminput, event,
strs, unredo, dwedtype, dwedhndl, dwedutil, dwedhl, dwedscru, dwedlnch,
scr, ansi;
        
procedure edit(var ctx : TEditorContext; show_welcome_msg : boolean);
var     scru, prev_scru, i : integer;
        event              : TEvent;
begin
        scru := SCRU_FULL;
        while scru <> SCRU_QUIT do begin
                if scru <> SCRU_NONE then begin
                        dwedscru.update(ctx, scru);
                        if show_welcome_msg then begin
                                with ctx.current^.config^.color do begin
                                        scr.cln(0, 0, top);
                                        scr.printhl(2, 0, top, top_hl, WELCOME_MSG);
                                end;
                                scr.show;
                                show_welcome_msg := false;
                        end;
                        scru := SCRU_NONE;
                end;
                if not kbd_haskey then begin
                        wait_event(event);
                        scru := process_event(ctx, event);
                end else begin
                        i := 0;
                        prev_scru := 0;
                        while (i < 8) and kbd_haskey do begin
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
        path   : string;
        i      : integer;
begin
        fillchar(ctx, sizeof(TEditorContext), #0);
        with ctx do begin
                all := nil;
                current := nil;
                ins := true;
                exit_code := 0;
                config.width := scr.getwidth;
                config.height := scr.getheight;
                config.tab_size := 8;
                config.hl_enable := false;
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
                config.memory := MEM_DOS;
                getmem(clipboard, CB_SIZE);
                clipboard[0] := #0;
                has_wincb := WCB_Detect;
                search := '';
                replace := '';
                help_topic_id := 0;
                temp := '';
        end;
{$IFDEF DEBUG}
        ctx.temp := 'TEMP.CFG';
{$ENDIF}
{$IFNDEF DEBUG}
        ctx.temp := get_temp_name;
{$ENDIF}
        path := '';
        if length(path) = 0 then path := getenv(ENV_TEMP);
        if length(path) = 0 then path := getenv(ENV_TMP);
        if (length(path) <> 0) and (path[length(path)] <> '\') then path := path + '\';
        ctx.temp := path + ctx.temp;
end;

procedure process_param(var ctx : TEditorContext; key, value : string);
begin
        if length(key) = 0 then exit;
        if key = CFG_TAB_SIZE then ctx.config.tab_size := ahtob(value)
        else if key = CFG_COLOR_TOP then ctx.config.color.top := ahtob(value)
        else if key = CFG_COLOR_TOP_HL then ctx.config.color.top_hl := ahtob(value)
        else if key = CFG_COLOR_TEXT then ctx.config.color.text := ahtob(value)
        else if key = CFG_COLOR_TEXT_HL then ctx.config.color.text_hl := ahtob(value)
        else if key = CFG_COLOR_TEXT_DL then ctx.config.color.text_dl := ahtob(value)
        else if key = CFG_COLOR_TEXT_SEL then ctx.config.color.text_sel := ahtob(value)
        else if key = CFG_COLOR_MENU then ctx.config.color.menu := ahtob(value)
        else if key = CFG_COLOR_MENU_SEL then ctx.config.color.menu_sel := ahtob(value)
        else if key = CFG_COLOR_HELP_MENU then ctx.config.color.help_menu := ahtob(value)
        else if key = CFG_COLOR_HELP_MENU_SEL then ctx.config.color.help_menu_sel := ahtob(value)
        else if key = CFG_COLOR_HELP then ctx.config.color.help := ahtob(value)
        else if key = CFG_COLOR_HELP_HL then ctx.config.color.help_hl := ahtob(value)
        else if key = CFG_USR_DEF_F5 then ctx.config.udef_f5 := value
        else if key = CFG_USR_DEF_F8 then ctx.config.udef_f8 := value
        else if key = CFG_USR_DEF_F9 then ctx.config.udef_f9 := value
        else if key = CFG_HL_ENABLE then ctx.config.hl_enable := (ahtob(value) <> 0)
        else if key = CFG_MEMORY then ctx.config.memory := value
        else begin writelnerr('Unknown parameter ' + key + '. Press Enter...'); system.readln; end;
        if ctx.config.tab_size > 32 then ctx.config.tab_size := 8;
end;

procedure split(var param, key, value : string);
var i : integer;
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

procedure load_config(var ctx : TEditorContext; fname : string);
var     f          : bfile;
        str        : string;
        key, value : string;
begin
        if not FileExists(fname) then exit;
        assign(f, fname);
        system2.reset(f);
        if not isopen(f) then exit;
        while not eof(f) do begin
                readln(f, str);
                split(str, key, value);
                process_param(ctx, key, value);
        end;
        close(f);
end;

procedure parse_temp(var ctx : TEditorContext);
var   f : bfile;
      s, ss   : string;
      i, p    : integer;
      errCode : integer;
      x, scrx, scry   : integer;
      cline_num       : longint;
      fname   : string;
begin
        assign(f, ctx.temp);
        system2.reset(f);
        if not isopen(f) then exit;
        while not eof(f) do begin
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
                load_file(ctx, fname, errCode, @load_file_progress);
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

{$F+}
var prevExitProc : pointer;
procedure err_handler;
begin
        spinner_stop;
        IF (ErrorAddr <> NIL) AND (ExitCode <> 0) THEN BEGIN
                scr.pop;
                scr.show;
                System.Writeln(bg(red), ' ', get_err_msg(ExitCode), ' at '
                        , fg(cyan), hexw(seg(pchar(errorAddr)[0]))
                        , ':'
                        , hexw(ofs(pchar(errorAddr)[0]))
                        , fg(white), ' ', bg(black));
                if ExitCode = 203 then begin
                   System.Writeln(fg(green), 'Largest free block: ', maxavail, fg(white));
                   System.Writeln(fg(green), 'Total free memory:  ', memavail, fg(white));
                end;
                errorAddr := nil;
        END;
        exitProc := prevExitProc;
        strs.done;
        unredo.done;
end;
{$F-}

var     ctx                : TEditorContext;
        i, pCount, errCode : integer;
        param, key, value  : string;
        show_welcome_msg   : boolean;
        pc                 : integer;
        exe_path           : string;
begin
        exe_path := getpathname(paramstr(0));
{$IFNDEF DEBUG}
        if not dwedlnch.is_installed then begin
                writelnerr(OVERLAY_MSG);
                halt(1);
        end;
{$ENDIF}
        prevExitProc := exitProc;
        exitProc := @err_handler;
        pc := paramcount;
        reset_context(ctx);
        load_config(ctx, exe_path + CONFIG_FILE_NAME);
        load_config(ctx, CONFIG_FILE_NAME);
        for i := 1 to pc do begin
                param := paramstr(i);
                if has_switch(param) then begin
                        System.delete(param, 1, 1);
                        split(param, key, value);
                        process_param(ctx, key, value);
                end;
        end;

        upstr(ctx.config.memory);
        if ctx.config.memory = MEM_SXMS then strs.init(strs.MT_SXMS)
        else if ctx.config.memory = MEM_SWAP then strs.init(strs.MT_SWAP)
        else strs.init(strs.MT_DOS);
        unredo.init;
        scr.push;
        scr.cls(7);
        if FileExists(ctx.temp) then begin
                show_welcome_msg := false;
                parse_temp(ctx);
                FileDelete(ctx.temp);
        end else begin
                show_welcome_msg := true;
                for i := 1 to pc do begin
                        param := paramstr(i);
                        if not has_switch(param) then begin
                                load_file(ctx, param, errCode, @load_file_progress);
                                if errCode <> 0 then handle_error(ctx, errCode);
                        end;
                end;
        end;
        if ctx.all = nil then new_file(ctx, DEFAULT_FILE_NAME);
        edit(ctx, show_welcome_msg);
        scr.pop;
        scr.show;
        scr.set_cursor(scr.cursor);
        halt(ctx.exit_code);
end.

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
{$A-}
unit dwedtype;

interface

uses strs, dwedhl, event;

const
SCRU_QUIT   = 1;
SCRU_NONE   = 2;
SCRU_TOP    = 3;
SCRU_CLINE  = 4;
SCRU_SD     = 5;
SCRU_SU     = 6;
SCRU_FULL   = 7;

CB_SIZE         = 1024 * 32;
PROGRESS_UPDATE = 1024 * 4;

MEM_DOS  = 'DOS';
MEM_SWAP = 'SWAP';

ENV_TEMP = 'TEMP';
ENV_TMP  = 'TMP';

OVERLAY_MSG             = 'This is overlay. Run DWED.EXE';
WELCOME_MSG             = 'Welcome!  Press ~F1~ for help';
DEFAULT_FILE_NAME       = 'NONAME.TXT';

CONFIG_FILE_NAME        = 'DWED.CFG';

CFG_TAB_SIZE            = 'TAB_SIZE';
CFG_COLOR_TOP           = 'COLOR.TOP';
CFG_COLOR_TOP_HL        = 'COLOR.TOP_HL';
CFG_COLOR_TEXT          = 'COLOR.TEXT';
CFG_COLOR_TEXT_HL       = 'COLOR.TEXT_HL';
CFG_COLOR_TEXT_DL       = 'COLOR.TEXT_DL';
CFG_COLOR_TEXT_SEL      = 'COLOR.TEXT_SEL';
CFG_COLOR_MENU          = 'COLOR.MENU';
CFG_COLOR_MENU_SEL      = 'COLOR.MENU_SEL';
CFG_COLOR_HELP_MENU     = 'COLOR.HELP_MENU';
CFG_COLOR_HELP_MENU_SEL = 'COLOR.HELP_MENU_SEL';
CFG_COLOR_HELP          = 'COLOR.HELP';
CFG_COLOR_HELP_HL       = 'COLOR.HELP_HL';
CFG_USR_DEF_F5          = 'USR.DEF.F5';
CFG_USR_DEF_F8          = 'USR.DEF.F8';
CFG_USR_DEF_F9          = 'USR.DEF.F9';
CFG_HL_ENABLE           = 'HL.ENABLE';
CFG_MEMORY              = 'MEMORY';

type
PString  = ^String;
PWord    = ^Word;
PLongint = ^Longint;
DWord    = Longint;

PColorConfig =^ TColorConfig;
TColorConfig = record
        top           : byte;
        top_hl        : byte;
        text          : byte;
        text_hl       : byte;
        text_dl       : byte;
        text_sel      : byte;
        menu          : byte;
        menu_sel      : byte;
        help_menu     : byte;
        help_menu_sel : byte;
        help          : byte;
        help_hl       : byte;
end;

PConfig =^ TConfig;
TConfig = record
        width           : integer;
        height          : integer;
        color           : TColorConfig;
        hl_enable       : boolean;
        tab_size        : integer;
        udef_f5         : string;
        udef_f8         : string;
        udef_f9         : string;
        memory          : string;
end;

TLineEditorContext = record
        x         : integer;
        line      : string;
        chg       : boolean;
        selection : boolean;
        sel_row   : DWord;
        sel_x     : integer;
end;

PFileContext =^ TFileContext;
TFileContext = record
        fname        : string;
        sfname       : string;
        st           : SourceType;
        chg          : boolean;
        total        : DWord;
        scrx, scry   : integer;
        next         : PFileContext;
        rline        : EditorStr;
        cline        : EditorStr;
        scrline      : EditorStr;
        editor       : TLineEditorContext;
        config       : PConfig;
end;

PEditorContext =^ TEditorContext;
TEditorContext = record
        ins            : boolean;
        exit_code      : byte;
        current        : PFileContext;
        all            : PFileContext;
        clipboard      : pchar;
        has_wincb      : boolean;
        search         : string[64];
        searchCaseSens : boolean;
        replace        : string[64];
        config         : TConfig;
        help_topic_id  : integer;
        temp           : string;
end;

{$F+}
TEventProc = function(var ctx : TEditorContext; e : PEvent) : integer;
TPercentUpdateProc = procedure(value, total, start_date : DWord);
{$F-}

PEventHandler =^ TEventHandler;
TEventHandler = record
        event           : TEvent;
        reset_selection : boolean;
        proc            : pointer;
        next            : PEventHandler;
end;

implementation

end.

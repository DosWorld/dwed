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
unit dwedhl;

interface

type
SourceType = (SRC_C, SRC_CMM, SRC_PAS, SRC_MOD, SRC_OB, SRC_BAS, SRC_ASM, SRC_BAT, SRC_MD,
                SRC_XML, SRC_HTML, SRC_FORTH, SRC_NONE,
                SRC_DISABLE);

function find_SourceType_by_ext(ext : string): SourceType;
procedure high_light(st: SourceType; width : integer; hlclr, tclr : byte; scr:pchar);
procedure change_hl(var st : SourceType; color, color_sel : byte);

implementation

uses kminput, event, scr, scrui, str;

type
PVocabEntry = ^TVocabEntry;
TVocabEntry = record
        hash        : word;
        next        : PVocabEntry;
        keyword     : string[16];
end;

PLangDesc = ^TLangDesc;
TLangDesc = record
        st        : SourceType;
        hlchars   : string;
        caseSens  : boolean;
        ext       : string[64];
        vocab     : PVocabEntry;
        title     : string[48];
        next      : PLangDesc;
end;

const langs : PLangDesc = nil;
var hl_menu : pchar;

procedure change_hl(var st : SourceType; color, color_sel : byte);
var
        i, sitem   : integer;
        r          : PLangDesc;
        e          : TEvent;
begin

        r := langs;
        sitem := 0;
        while r <> nil do begin
                if st = r^.st then break;
                inc(sitem);
                r := r^.next;
        end;

        scr.cursor_off;        
        while true do begin
                scrui.vmenu(e, 1, 2, 40, scr.getheight - 3,
                        color, color_sel,
                        'Syntax highlight scheme', hl_menu, sitem);
                if e.etype <> KEYBOARD then continue;
                if e.scancode = SCAN_ESC then break;
                if (e.scancode = SCAN_ENTER) or (e.scancode = SCAN_SPACE) then begin
                        i := 0;
                        r := langs;
                        while r <> nil do begin
                                if i = sitem then begin
                                        st := r^.st;
                                        break;
                                end;
                                inc(i);
                                r := r^.next;
                        end;
                        break;
                end;
        end;
end;

procedure add_lang(st : SourceType; ext : string; caseSens : boolean; hlchars : pchar; title : string);
var lng : PLangDesc;
begin
        upstr(ext);
        getmem(lng, sizeof(TLangDesc));
        lng^.st := st;
        lng^.title := title;
        lng^.caseSens := caseSens;
        lng^.vocab := nil;
        lng^.ext := ext;
        lng^.next := langs;
        fillchar(lng^.hlchars[1], 255, #0);
        lng^.hlchars[0] := #255;
        while hlchars^ <> #0 do begin
                lng^.hlchars[ord(hlchars^) + 1] := #1;
                inc(hlchars);
        end;
        langs := lng;
end;

function find_SourceType_by_ext(ext : string): SourceType;
var lng : PLangDesc;
begin
        upstr(ext);
        ext := '|' + ext + '|';
        lng := langs;
        while lng <> nil do begin
                if System.pos(ext, lng^.ext) <> 0 then begin
                        find_SourceType_by_ext := lng^.st;
                        exit;
                end;
                lng := lng^.next;
        end;
        find_SourceType_by_ext := SRC_NONE;
end;

procedure add_keyword(st : SourceType; keyword : string);
var     lng   : PLangDesc;
        entry : PVocabEntry;
begin
        lng := langs;
        while lng <> nil do begin
                if lng^.st = st then begin
                        getmem(entry, sizeof(TVocabEntry));
                        if not lng^.caseSens then upstr(keyword);
                        entry^.next := lng^.vocab;
                        entry^.keyword := keyword;
                        entry^.hash := hcode(keyword);
                        lng^.vocab := entry;
                        break;
                end;
                lng := lng^.next;
        end;
end;

function find_keyword(vocab : PVocabEntry; var str:string):boolean;
var     hash : word;
begin
        hash := hcode(str);
        while vocab <> nil do begin
                if hash = vocab^.hash then begin
                        if vocab^.keyword = str then begin
                                find_keyword := true;
                                exit;
                        end;
                end;
                vocab := vocab^.next;
        end;
        find_keyword := false;
end;

procedure hl(scr:pchar; width:integer; hlclr, tclr:byte; lng : PLangDesc);
var
        str         : string;
        ch          : char;
        pos         : integer;
        wordStarted : boolean;
        wordStart   : pchar;
        syschars    : ^string;
begin
        syschars := @lng^.hlchars;
        wordStarted := false;
        pos := 0;
        while width >= 0 do begin
                ch := scr^;
                if ord(scr[1]) = tclr then begin
                        if is_id(ch) then begin
                                if (not wordStarted) and (lng^.vocab <> nil) then begin
                                        wordStart := scr + 1;
                                        wordStarted := true;
                                        pos := 0;
                                end;
                                inc(pos);
                                str[pos] := ch;
                        end else begin
                                if wordStarted and (pos > 1) then begin
                                        str[0] := chr(pos);
                                        if not lng^.caseSens then upstr(str);
                                        if find_keyword(lng^.vocab, str) then
                                        asm
                                                push       ds
                                                mov        al, byte ptr [hlclr]
                                                mov        bx, word ptr [scr]
                                                lds        si, wordStart
                                        @cont:  cmp        si, bx
                                                jnl        @stop
                                                mov        byte ptr[si], al
                                                add        si, 2
                                                jmp        @cont
                                        @stop:
                                                pop        ds
                                        end;
{
                                        while wordStart < scr do begin
                                                wordStart^ := chr(hlclr);
                                                inc(wordStart, 2);
                                        end;
}                                       
                                end;
                                wordStarted := false;
                                if syschars^[ord(ch) + 1] <> #0 then scr[1] := chr(hlclr);
                        end;
                end else begin
                        wordStarted := false;
                end;
                asm
                        add        word ptr [scr], 2
                        dec        width
                end;
{
                inc(scr, 2);
                dec(width);
}
        end;
end;

procedure high_light(st: SourceType; width:integer; hlclr, tclr:byte; scr:pchar);
var lng : PLangDesc;
begin
        if st = SRC_DISABLE then exit;
        lng := langs;
        while lng <> nil do begin
                if lng^.st = st then begin
                        hl(scr, width, hlclr, tclr, lng);
                        exit;
                end;
                lng := lng^.next;
        end;
end;

procedure create_menu;
var
        r         : PLangDesc;
        menu_len  : integer;
        item_len  : integer;
        max_width : integer;
        pos       : integer;
begin
        menu_len := 0; max_width := 0;
        r := langs;
        while r <> nil do begin
                item_len := length(r^.title) + 2;
                if max_width < item_len then max_width := item_len;
                inc(menu_len, item_len + 1);
                r := r^.next;
        end;
        pos := 0;
        getmem(hl_menu, menu_len);
        r := langs;
        while r <> nil do begin
                if pos <> 0 then begin hl_menu[pos] := #$0A; inc(pos); end;
                hl_menu[pos] := ' '; inc(pos);
                item_len := length(r^.title);
                move(r^.title[1], hl_menu[pos], item_len);
                inc(pos, item_len);
                hl_menu[pos] := ' '; inc(pos);
                r := r^.next;
        end;
        hl_menu[pos] := #$0;
end;

procedure init;
var i : integer; s : string;
begin
        dwedhl.add_lang(SRC_DISABLE, '|%?%|', false, '', '     DISABLE (Use this, if too slow)');
        dwedhl.add_lang(SRC_FORTH, '|f|4th|', false, '+-/*[]():;,.!@?','.4th Forth Source');
        dwedhl.add_keyword(SRC_FORTH, 'immediate');
        dwedhl.add_keyword(SRC_FORTH, 'dup');
        dwedhl.add_keyword(SRC_FORTH, 'drop');
        dwedhl.add_keyword(SRC_FORTH, 'swap');
        dwedhl.add_keyword(SRC_FORTH, 'over');
        dwedhl.add_keyword(SRC_FORTH, 'pick');
        dwedhl.add_keyword(SRC_FORTH, 'does');
        dwedhl.add_keyword(SRC_FORTH, 'mark');
        dwedhl.add_keyword(SRC_FORTH, 'resolve');
        dwedhl.add_keyword(SRC_FORTH, 'and');
        dwedhl.add_keyword(SRC_FORTH, 'or');
        dwedhl.add_keyword(SRC_FORTH, 'xor');
        dwedhl.add_keyword(SRC_FORTH, 'not');
        dwedhl.add_keyword(SRC_FORTH, 'do');
        dwedhl.add_keyword(SRC_FORTH, 'loop');
        dwedhl.add_keyword(SRC_FORTH, 'while');
        dwedhl.add_keyword(SRC_FORTH, 'repeat');
        dwedhl.add_keyword(SRC_FORTH, 'until');
        dwedhl.add_keyword(SRC_FORTH, 'if');
        dwedhl.add_keyword(SRC_FORTH, 'else');
        dwedhl.add_keyword(SRC_FORTH, 'then');

        dwedhl.add_lang(SRC_C, '|C|H|CPP|HPP|', true, ',.()+*-:=<>#$@^%?;!~&|\{}[]"/'+#$27
                             , '.c   C-Family Source');

        dwedhl.add_keyword(SRC_C, 'static');
        dwedhl.add_keyword(SRC_C, 'pragma');
        dwedhl.add_keyword(SRC_C, 'inline');
        dwedhl.add_keyword(SRC_C, 'pascal');
        dwedhl.add_keyword(SRC_C, 'far');
        dwedhl.add_keyword(SRC_C, 'cdecl');
        dwedhl.add_keyword(SRC_C, 'define');
        dwedhl.add_keyword(SRC_C, 'undef');
        dwedhl.add_keyword(SRC_C, 'ifdef');
        dwedhl.add_keyword(SRC_C, 'ifndef');
        dwedhl.add_keyword(SRC_C, 'include');
        dwedhl.add_keyword(SRC_C, 'endif');
        dwedhl.add_keyword(SRC_C, 'NULL');
        dwedhl.add_keyword(SRC_C, 'size_t');

        dwedhl.add_keyword(SRC_C, 'auto');
        dwedhl.add_keyword(SRC_C, 'break');
        dwedhl.add_keyword(SRC_C, 'case');
        dwedhl.add_keyword(SRC_C, 'char');
        dwedhl.add_keyword(SRC_C, 'continue');
        dwedhl.add_keyword(SRC_C, 'do');
        dwedhl.add_keyword(SRC_C, 'default');
        dwedhl.add_keyword(SRC_C, 'const');
        dwedhl.add_keyword(SRC_C, 'double');
        dwedhl.add_keyword(SRC_C, 'else');
        dwedhl.add_keyword(SRC_C, 'enum');
        dwedhl.add_keyword(SRC_C, 'extern');
        dwedhl.add_keyword(SRC_C, 'for');
        dwedhl.add_keyword(SRC_C, 'if');
        dwedhl.add_keyword(SRC_C, 'goto');
        dwedhl.add_keyword(SRC_C, 'float');
        dwedhl.add_keyword(SRC_C, 'int');
        dwedhl.add_keyword(SRC_C, 'long');
        dwedhl.add_keyword(SRC_C, 'register');
        dwedhl.add_keyword(SRC_C, 'return');
        dwedhl.add_keyword(SRC_C, 'signed');
        dwedhl.add_keyword(SRC_C, 'sizeof');
        dwedhl.add_keyword(SRC_C, 'short');
        dwedhl.add_keyword(SRC_C, 'struct');
        dwedhl.add_keyword(SRC_C, 'switch');
        dwedhl.add_keyword(SRC_C, 'typedef');
        dwedhl.add_keyword(SRC_C, 'union');
        dwedhl.add_keyword(SRC_C, 'void');
        dwedhl.add_keyword(SRC_C, 'while');
        dwedhl.add_keyword(SRC_C, 'volatile');
        dwedhl.add_keyword(SRC_C, 'unsigned');

        dwedhl.add_lang(SRC_CMM, '|C--|H--|CMM|HMM|', false, ',.()+*-:=<>#$@^%?;!~&|\{}[]"/'+#$27
                             , '.c-- SPHINX C-- Source');

        dwedhl.add_keyword(SRC_CMM, 'TRUE');
        dwedhl.add_keyword(SRC_CMM, 'FALSE');
        dwedhl.add_keyword(SRC_CMM, 'static');
        dwedhl.add_keyword(SRC_CMM, 'pragma');
        dwedhl.add_keyword(SRC_CMM, 'inline');
        dwedhl.add_keyword(SRC_CMM, 'pascal');
        dwedhl.add_keyword(SRC_CMM, 'far');
        dwedhl.add_keyword(SRC_CMM, 'cdecl');
        dwedhl.add_keyword(SRC_CMM, 'stdcall');
        dwedhl.add_keyword(SRC_CMM, 'fastcall');
        dwedhl.add_keyword(SRC_CMM, 'uses');
        dwedhl.add_keyword(SRC_CMM, 'define');
        dwedhl.add_keyword(SRC_CMM, 'undef');
        dwedhl.add_keyword(SRC_CMM, 'ifdef');
        dwedhl.add_keyword(SRC_CMM, 'ifndef');
        dwedhl.add_keyword(SRC_CMM, 'include');
        dwedhl.add_keyword(SRC_CMM, 'endif');
        dwedhl.add_keyword(SRC_CMM, 'NULL');
        dwedhl.add_keyword(SRC_CMM, 'interrupt');

        dwedhl.add_keyword(SRC_CMM, 'CS');
        dwedhl.add_keyword(SRC_CMM, 'ES');
        dwedhl.add_keyword(SRC_CMM, 'DS');
        dwedhl.add_keyword(SRC_CMM, 'SS');
        dwedhl.add_keyword(SRC_CMM, 'AX');
        dwedhl.add_keyword(SRC_CMM, 'BX');
        dwedhl.add_keyword(SRC_CMM, 'CX');
        dwedhl.add_keyword(SRC_CMM, 'DX');
        dwedhl.add_keyword(SRC_CMM, 'DI');
        dwedhl.add_keyword(SRC_CMM, 'SI');
        dwedhl.add_keyword(SRC_CMM, 'AL');
        dwedhl.add_keyword(SRC_CMM, 'AH');
        dwedhl.add_keyword(SRC_CMM, 'BL');
        dwedhl.add_keyword(SRC_CMM, 'BH');
        dwedhl.add_keyword(SRC_CMM, 'CL');
        dwedhl.add_keyword(SRC_CMM, 'CH');
        dwedhl.add_keyword(SRC_CMM, 'DL');
        dwedhl.add_keyword(SRC_CMM, 'DH');
        dwedhl.add_keyword(SRC_CMM, 'BP');
        dwedhl.add_keyword(SRC_CMM, 'SP');
        dwedhl.add_keyword(SRC_CMM, 'break');
        dwedhl.add_keyword(SRC_CMM, 'qword');
        dwedhl.add_keyword(SRC_CMM, 'dword');
        dwedhl.add_keyword(SRC_CMM, 'word');
        dwedhl.add_keyword(SRC_CMM, 'byte');
        dwedhl.add_keyword(SRC_CMM, 'dsword');
        dwedhl.add_keyword(SRC_CMM, 'dsbyte');
        dwedhl.add_keyword(SRC_CMM, 'esword');
        dwedhl.add_keyword(SRC_CMM, 'esbyte');
        dwedhl.add_keyword(SRC_CMM, 'csword');
        dwedhl.add_keyword(SRC_CMM, 'csbyte');
        dwedhl.add_keyword(SRC_CMM, 'ssword');
        dwedhl.add_keyword(SRC_CMM, 'ssbyte');
        dwedhl.add_keyword(SRC_CMM, 'case');
        dwedhl.add_keyword(SRC_CMM, 'char');
        dwedhl.add_keyword(SRC_CMM, 'continue');
        dwedhl.add_keyword(SRC_CMM, 'do');
        dwedhl.add_keyword(SRC_CMM, 'default');
        dwedhl.add_keyword(SRC_CMM, 'const');
        dwedhl.add_keyword(SRC_CMM, 'double');
        dwedhl.add_keyword(SRC_CMM, 'else');
        dwedhl.add_keyword(SRC_CMM, 'enum');
        dwedhl.add_keyword(SRC_CMM, 'extern');
        dwedhl.add_keyword(SRC_CMM, 'for');
        dwedhl.add_keyword(SRC_CMM, 'if');
        dwedhl.add_keyword(SRC_CMM, 'goto');
        dwedhl.add_keyword(SRC_CMM, 'float');
        dwedhl.add_keyword(SRC_CMM, 'int');
        dwedhl.add_keyword(SRC_CMM, 'long');
        dwedhl.add_keyword(SRC_CMM, 'register');
        dwedhl.add_keyword(SRC_CMM, 'return');
        dwedhl.add_keyword(SRC_CMM, 'signed');
        dwedhl.add_keyword(SRC_CMM, 'sizeof');
        dwedhl.add_keyword(SRC_CMM, 'short');
        dwedhl.add_keyword(SRC_CMM, 'struct');
        dwedhl.add_keyword(SRC_CMM, 'switch');
        dwedhl.add_keyword(SRC_CMM, 'typedef');
        dwedhl.add_keyword(SRC_CMM, 'class');
        dwedhl.add_keyword(SRC_CMM, 'union');
        dwedhl.add_keyword(SRC_CMM, 'void');
        dwedhl.add_keyword(SRC_CMM, 'while');
        dwedhl.add_keyword(SRC_CMM, 'unsigned');

        dwedhl.add_lang(SRC_BAS, '|bas|', false, '`%,.()+*-:=<>#$@^;{}[]"!\/'+#$27, '.bas Basic Source');
        dwedhl.add_keyword(SRC_BAS, 'select');
        dwedhl.add_keyword(SRC_BAS, 'case');
        dwedhl.add_keyword(SRC_BAS, 'data');
        dwedhl.add_keyword(SRC_BAS, 'read');
        dwedhl.add_keyword(SRC_BAS, 'incr');
        dwedhl.add_keyword(SRC_BAS, 'decr');
        dwedhl.add_keyword(SRC_BAS, 'left');
        dwedhl.add_keyword(SRC_BAS, 'right');
        dwedhl.add_keyword(SRC_BAS, 'shift');
        dwedhl.add_keyword(SRC_BAS, 'type');
        dwedhl.add_keyword(SRC_BAS, 'on');
        dwedhl.add_keyword(SRC_BAS, 'byval');
        dwedhl.add_keyword(SRC_BAS, 'shared');
        dwedhl.add_keyword(SRC_BAS, 'until');
        dwedhl.add_keyword(SRC_BAS, 'peek');
        dwedhl.add_keyword(SRC_BAS, 'poke');
        dwedhl.add_keyword(SRC_BAS, 'call');
        dwedhl.add_keyword(SRC_BAS, 'seg');
        dwedhl.add_keyword(SRC_BAS, 'sub');
        dwedhl.add_keyword(SRC_BAS, 'public');
        dwedhl.add_keyword(SRC_BAS, 'local');
        dwedhl.add_keyword(SRC_BAS, 'private');
        dwedhl.add_keyword(SRC_BAS, 'byte');
        dwedhl.add_keyword(SRC_BAS, 'ptr');
        dwedhl.add_keyword(SRC_BAS, 'word');
        dwedhl.add_keyword(SRC_BAS, 'long');
        dwedhl.add_keyword(SRC_BAS, 'mod');
        dwedhl.add_keyword(SRC_BAS, 'not');
        dwedhl.add_keyword(SRC_BAS, 'function');
        dwedhl.add_keyword(SRC_BAS, 'def');
        dwedhl.add_keyword(SRC_BAS, 'if');
        dwedhl.add_keyword(SRC_BAS, 'then');
        dwedhl.add_keyword(SRC_BAS, 'else');
        dwedhl.add_keyword(SRC_BAS, 'elseif');
        dwedhl.add_keyword(SRC_BAS, 'end');
        dwedhl.add_keyword(SRC_BAS, 'wend');
        dwedhl.add_keyword(SRC_BAS, 'resume');
        dwedhl.add_keyword(SRC_BAS, 'next');
        dwedhl.add_keyword(SRC_BAS, 'while');
        dwedhl.add_keyword(SRC_BAS, 'loop');
        dwedhl.add_keyword(SRC_BAS, 'for');
        dwedhl.add_keyword(SRC_BAS, 'to');
        dwedhl.add_keyword(SRC_BAS, 'do');
        dwedhl.add_keyword(SRC_BAS, 'step');
        dwedhl.add_keyword(SRC_BAS, 'goto');
        dwedhl.add_keyword(SRC_BAS, 'gosub');
        dwedhl.add_keyword(SRC_BAS, 'return');
        dwedhl.add_keyword(SRC_BAS, 'exit');
        dwedhl.add_keyword(SRC_BAS, 'rem');
        dwedhl.add_keyword(SRC_BAS, 'dim');
        dwedhl.add_keyword(SRC_BAS, 'as');
        dwedhl.add_keyword(SRC_BAS, 'integer');
        dwedhl.add_keyword(SRC_BAS, 'string');
        dwedhl.add_keyword(SRC_BAS, 'record');

        dwedhl.add_lang(SRC_BAT, '|bat|', false, '%.()+-:=<>#@;"\/'+#$27, '.bat MS-DOS Shell Script');
        dwedhl.add_keyword(SRC_BAT, 'rem');
        dwedhl.add_keyword(SRC_BAT, 'pause');
        dwedhl.add_keyword(SRC_BAT, 'on');
        dwedhl.add_keyword(SRC_BAT, 'off');
        dwedhl.add_keyword(SRC_BAT, 'errorlevel');
        dwedhl.add_keyword(SRC_BAT, 'not');
        dwedhl.add_keyword(SRC_BAT, 'exist');
        dwedhl.add_keyword(SRC_BAT, 'call');
        dwedhl.add_keyword(SRC_BAT, 'if');
        dwedhl.add_keyword(SRC_BAT, 'set');
        dwedhl.add_keyword(SRC_BAT, 'goto');
        dwedhl.add_keyword(SRC_BAT, 'echo');
        dwedhl.add_keyword(SRC_BAT, 'type');
        dwedhl.add_keyword(SRC_BAT, 'dir');
        dwedhl.add_keyword(SRC_BAT, 'cd');
        dwedhl.add_keyword(SRC_BAT, 'del');
        dwedhl.add_keyword(SRC_BAT, 'mkdir');
        dwedhl.add_keyword(SRC_BAT, 'lh');
        dwedhl.add_keyword(SRC_BAT, 'loadhi');
        dwedhl.add_keyword(SRC_BAT, 'path');
        dwedhl.add_keyword(SRC_BAT, 'device');
        dwedhl.add_keyword(SRC_BAT, 'exit');

        dwedhl.add_lang(SRC_ASM, '|asm|', false, ',.()+*-:=<>#$@^;{}[]"/'+#$27, '.asm Assembler Source');
        dwedhl.add_keyword(SRC_ASM, 'INCLUDE');
        dwedhl.add_keyword(SRC_ASM, 'IF');
        dwedhl.add_keyword(SRC_ASM, 'ELSE');
        dwedhl.add_keyword(SRC_ASM, 'ENDIF');
        dwedhl.add_keyword(SRC_ASM, 'LABEL');
        dwedhl.add_keyword(SRC_ASM, 'BYTE');
        dwedhl.add_keyword(SRC_ASM, 'WORD');
        dwedhl.add_keyword(SRC_ASM, 'DWORD');
        dwedhl.add_keyword(SRC_ASM, 'PTR');
        dwedhl.add_keyword(SRC_ASM, 'MACRO');
        dwedhl.add_keyword(SRC_ASM, 'ENDMACRO');
        dwedhl.add_keyword(SRC_ASM, 'ENDM');
        dwedhl.add_keyword(SRC_ASM, 'STACK');
        dwedhl.add_keyword(SRC_ASM, 'CODE');
        dwedhl.add_keyword(SRC_ASM, 'DATA');
        dwedhl.add_keyword(SRC_ASM, 'BSS');
        dwedhl.add_keyword(SRC_ASM, 'EXTRN');
        dwedhl.add_keyword(SRC_ASM, 'PUBLIC');
        dwedhl.add_keyword(SRC_ASM, 'ENDS');
        dwedhl.add_keyword(SRC_ASM, 'DB');
        dwedhl.add_keyword(SRC_ASM, 'DW');
        dwedhl.add_keyword(SRC_ASM, 'DD');
        dwedhl.add_keyword(SRC_ASM, 'EQU');
        dwedhl.add_keyword(SRC_ASM, 'ORG');
        dwedhl.add_keyword(SRC_ASM, 'PROC');
        dwedhl.add_keyword(SRC_ASM, 'ENDP');
        dwedhl.add_keyword(SRC_ASM, 'SEGMENT');
        dwedhl.add_keyword(SRC_ASM, 'ASSUME');
        dwedhl.add_keyword(SRC_ASM, 'END');
        dwedhl.add_keyword(SRC_ASM, 'RET');
        dwedhl.add_keyword(SRC_ASM, 'RETN');
        dwedhl.add_keyword(SRC_ASM, 'RETF');
        dwedhl.add_keyword(SRC_ASM, 'IRET');
        dwedhl.add_keyword(SRC_ASM, 'INT');
        dwedhl.add_keyword(SRC_ASM, 'CALL');
        dwedhl.add_keyword(SRC_ASM, 'JMP');
        dwedhl.add_keyword(SRC_ASM, 'JZ');
        dwedhl.add_keyword(SRC_ASM, 'JNZ');
        dwedhl.add_keyword(SRC_ASM, 'JC');
        dwedhl.add_keyword(SRC_ASM, 'JNC');
        dwedhl.add_keyword(SRC_ASM, 'JE');
        dwedhl.add_keyword(SRC_ASM, 'JAE');
        dwedhl.add_keyword(SRC_ASM, 'JCXZ');
        dwedhl.add_keyword(SRC_ASM, 'JNE');
        dwedhl.add_keyword(SRC_ASM, 'JG');
        dwedhl.add_keyword(SRC_ASM, 'JGE');
        dwedhl.add_keyword(SRC_ASM, 'JNG');
        dwedhl.add_keyword(SRC_ASM, 'JB');
        dwedhl.add_keyword(SRC_ASM, 'JBE');
        dwedhl.add_keyword(SRC_ASM, 'JNB');
        dwedhl.add_keyword(SRC_ASM, 'SHORT');
        dwedhl.add_keyword(SRC_ASM, 'NEAR');
        dwedhl.add_keyword(SRC_ASM, 'FAR');

        dwedhl.add_lang(SRC_MD, '|md|', false, '`^#@*_.,?+*/\-()!:;"=<>(){}[]~|'+#$27, '.md  Markdown file');
        dwedhl.add_lang(SRC_XML, '|xmlxsd|', false, '=<>/"', '.xml XML/XSD Document');

        dwedhl.add_lang(SRC_HTML, '|htm|', false, '=<>/"', '.htm HTML Document');
        dwedhl.add_keyword(SRC_HTML, 'body');
        dwedhl.add_keyword(SRC_HTML, 'script');
        dwedhl.add_keyword(SRC_HTML, 'pre');
        dwedhl.add_keyword(SRC_HTML, 'label');
        dwedhl.add_keyword(SRC_HTML, 'code');
        dwedhl.add_keyword(SRC_HTML, 'id');
        dwedhl.add_keyword(SRC_HTML, 'href');
        dwedhl.add_keyword(SRC_HTML, 'src');
        dwedhl.add_keyword(SRC_HTML, 'input');
        dwedhl.add_keyword(SRC_HTML, 'textarea');
        dwedhl.add_keyword(SRC_HTML, 'img');
        dwedhl.add_keyword(SRC_HTML, 'ul');
        dwedhl.add_keyword(SRC_HTML, 'li');
        dwedhl.add_keyword(SRC_HTML, 'br');
        dwedhl.add_keyword(SRC_HTML, 'span');
        dwedhl.add_keyword(SRC_HTML, 'p');
        dwedhl.add_keyword(SRC_HTML, 'a');
        dwedhl.add_keyword(SRC_HTML, 'div');

        dwedhl.add_lang(SRC_PAS, '|pas|', false, ',.()+*-:=<>#$@^;{}[]'+#$27, '.pas Pascal Source');
        dwedhl.add_keyword(SRC_PAS, 'program');
        dwedhl.add_keyword(SRC_PAS, 'far');
        dwedhl.add_keyword(SRC_PAS, 'near');
        dwedhl.add_keyword(SRC_PAS, 'inline');
        dwedhl.add_keyword(SRC_PAS, 'ifdef');
        dwedhl.add_keyword(SRC_PAS, 'ifndef');
        dwedhl.add_keyword(SRC_PAS, 'endif');
        dwedhl.add_keyword(SRC_PAS, 'unit');
        dwedhl.add_keyword(SRC_PAS, 'uses');
        dwedhl.add_keyword(SRC_PAS, 'interface');
        dwedhl.add_keyword(SRC_PAS, 'implementation');
        dwedhl.add_keyword(SRC_PAS, 'end');
        dwedhl.add_keyword(SRC_PAS, 'set');
        dwedhl.add_keyword(SRC_PAS, 'constructor');
        dwedhl.add_keyword(SRC_PAS, 'destructor');
        dwedhl.add_keyword(SRC_PAS, 'object');
        dwedhl.add_keyword(SRC_PAS, 'const');
        dwedhl.add_keyword(SRC_PAS, 'type');
        dwedhl.add_keyword(SRC_PAS, 'var');
        dwedhl.add_keyword(SRC_PAS, 'record');
        dwedhl.add_keyword(SRC_PAS, 'procedure');
        dwedhl.add_keyword(SRC_PAS, 'function');
        dwedhl.add_keyword(SRC_PAS, 'array');
        dwedhl.add_keyword(SRC_PAS, 'of');
        dwedhl.add_keyword(SRC_PAS, 'in');
        dwedhl.add_keyword(SRC_PAS, 'case');
        dwedhl.add_keyword(SRC_PAS, 'sizeof');
        dwedhl.add_keyword(SRC_PAS, 'ord');
        dwedhl.add_keyword(SRC_PAS, 'chr');
        dwedhl.add_keyword(SRC_PAS, 'char');
        dwedhl.add_keyword(SRC_PAS, 'pchar');
        dwedhl.add_keyword(SRC_PAS, 'string');
        dwedhl.add_keyword(SRC_PAS, 'integer');
        dwedhl.add_keyword(SRC_PAS, 'longint');
        dwedhl.add_keyword(SRC_PAS, 'byte');
        dwedhl.add_keyword(SRC_PAS, 'word');
        dwedhl.add_keyword(SRC_PAS, 'pointer');
        dwedhl.add_keyword(SRC_PAS, 'boolean');
        dwedhl.add_keyword(SRC_PAS, 'asm');
        dwedhl.add_keyword(SRC_PAS, 'assembler');
        dwedhl.add_keyword(SRC_PAS, 'and');
        dwedhl.add_keyword(SRC_PAS, 'or');
        dwedhl.add_keyword(SRC_PAS, 'xor');
        dwedhl.add_keyword(SRC_PAS, 'not');
        dwedhl.add_keyword(SRC_PAS, 'shl');
        dwedhl.add_keyword(SRC_PAS, 'shr');
        dwedhl.add_keyword(SRC_PAS, 'div');
        dwedhl.add_keyword(SRC_PAS, 'begin');
        dwedhl.add_keyword(SRC_PAS, 'exit');
        dwedhl.add_keyword(SRC_PAS, 'while');
        dwedhl.add_keyword(SRC_PAS, 'do');
        dwedhl.add_keyword(SRC_PAS, 'repeat');
        dwedhl.add_keyword(SRC_PAS, 'until');
        dwedhl.add_keyword(SRC_PAS, 'break');
        dwedhl.add_keyword(SRC_PAS, 'continue');
        dwedhl.add_keyword(SRC_PAS, 'if');
        dwedhl.add_keyword(SRC_PAS, 'then');
        dwedhl.add_keyword(SRC_PAS, 'else');
        dwedhl.add_keyword(SRC_PAS, 'for');
        dwedhl.add_keyword(SRC_PAS, 'to');
        dwedhl.add_keyword(SRC_PAS, 'downto');
        dwedhl.add_keyword(SRC_PAS, 'label');
        dwedhl.add_keyword(SRC_PAS, 'goto');
        dwedhl.add_keyword(SRC_PAS, 'with');
        dwedhl.add_keyword(SRC_PAS, 'true');
        dwedhl.add_keyword(SRC_PAS, 'false');
        dwedhl.add_keyword(SRC_PAS, 'nil');

        dwedhl.add_lang(SRC_MOD, '|mod|', true, ',.()+*-:=<>#$@^;{}[]'+#$27, '.mod Modula Source');
        dwedhl.add_keyword(SRC_MOD, 'AND');
        dwedhl.add_keyword(SRC_MOD, 'ARRAY');
        dwedhl.add_keyword(SRC_MOD, 'BEGIN');
        dwedhl.add_keyword(SRC_MOD, 'BY');
        dwedhl.add_keyword(SRC_MOD, 'CASE');
        dwedhl.add_keyword(SRC_MOD, 'CONST');
        dwedhl.add_keyword(SRC_MOD, 'DEFINITION');
        dwedhl.add_keyword(SRC_MOD, 'DIV');
        dwedhl.add_keyword(SRC_MOD, 'DO');
        dwedhl.add_keyword(SRC_MOD, 'ELSE');
        dwedhl.add_keyword(SRC_MOD, 'ELSIF');
        dwedhl.add_keyword(SRC_MOD, 'END');
        dwedhl.add_keyword(SRC_MOD, 'EXIT');
        dwedhl.add_keyword(SRC_MOD, 'EXPORT');
        dwedhl.add_keyword(SRC_MOD, 'FOR');
        dwedhl.add_keyword(SRC_MOD, 'FROM');
        dwedhl.add_keyword(SRC_MOD, 'IF');
        dwedhl.add_keyword(SRC_MOD, 'IMPLEMENTATION');
        dwedhl.add_keyword(SRC_MOD, 'IMPORT');
        dwedhl.add_keyword(SRC_MOD, 'IN');
        dwedhl.add_keyword(SRC_MOD, 'LOOP');
        dwedhl.add_keyword(SRC_MOD, 'MOD');
        dwedhl.add_keyword(SRC_MOD, 'MODULE');
        dwedhl.add_keyword(SRC_MOD, 'NOT');
        dwedhl.add_keyword(SRC_MOD, 'OF');
        dwedhl.add_keyword(SRC_MOD, 'OR');
        dwedhl.add_keyword(SRC_MOD, 'POINTER');
        dwedhl.add_keyword(SRC_MOD, 'PROCEDURE');
        dwedhl.add_keyword(SRC_MOD, 'QUALIFIED');
        dwedhl.add_keyword(SRC_MOD, 'RECORD');
        dwedhl.add_keyword(SRC_MOD, 'REPEAT');
        dwedhl.add_keyword(SRC_MOD, 'RETURN');
        dwedhl.add_keyword(SRC_MOD, 'SET');
        dwedhl.add_keyword(SRC_MOD, 'THEN');
        dwedhl.add_keyword(SRC_MOD, 'TO');
        dwedhl.add_keyword(SRC_MOD, 'TYPE');
        dwedhl.add_keyword(SRC_MOD, 'UNTIL');
        dwedhl.add_keyword(SRC_MOD, 'VAR');
        dwedhl.add_keyword(SRC_MOD, 'WHILE');
        dwedhl.add_keyword(SRC_MOD, 'WITH');

        dwedhl.add_keyword(SRC_MOD, 'BITSET');
        dwedhl.add_keyword(SRC_MOD, 'CARDINAL');
        dwedhl.add_keyword(SRC_MOD, 'TRUE');
        dwedhl.add_keyword(SRC_MOD, 'FALSE');
        dwedhl.add_keyword(SRC_MOD, 'BOOLEAN');
        dwedhl.add_keyword(SRC_MOD, 'CHAR');
        dwedhl.add_keyword(SRC_MOD, 'FLOAT');
        dwedhl.add_keyword(SRC_MOD, 'INTEGER');
        dwedhl.add_keyword(SRC_MOD, 'LONGINT');
        dwedhl.add_keyword(SRC_MOD, 'LONGREAL');
        dwedhl.add_keyword(SRC_MOD, 'NIL');
        dwedhl.add_keyword(SRC_MOD, 'REAL');
        dwedhl.add_keyword(SRC_MOD, 'SIZE');

        s := '';
        for i := $B3 to $DA do s := s + chr(i);
        s := '`^#@*_.,?+*/\-()!:;"=<>(){}[]~|' + s + #$27 + #0;
        dwedhl.add_lang(SRC_NONE, '|txt|doc|diz||', false,  @s[1], 'Default text');
        dwedhl.add_keyword(SRC_NONE, 'http');
        dwedhl.add_keyword(SRC_NONE, 'ftp');
        dwedhl.add_keyword(SRC_NONE, 'sftp');
        dwedhl.add_keyword(SRC_NONE, 'email');
        dwedhl.add_keyword(SRC_NONE, 'mailto');
        dwedhl.add_keyword(SRC_NONE, 'http');
        dwedhl.add_keyword(SRC_NONE, 'https');
        dwedhl.add_keyword(SRC_NONE, 'ftp');
        dwedhl.add_keyword(SRC_NONE, 'sftp');
        dwedhl.add_keyword(SRC_NONE, 'email');
        dwedhl.add_keyword(SRC_NONE, 'mailto');
        dwedhl.add_keyword(SRC_NONE, 'url');
        dwedhl.add_keyword(SRC_NONE, 'note');
        dwedhl.add_keyword(SRC_NONE, 'todo');
        dwedhl.add_keyword(SRC_NONE, 'tbd');
        dwedhl.add_keyword(SRC_NONE, 'asap');
        dwedhl.add_keyword(SRC_NONE, 'bug');
        dwedhl.add_keyword(SRC_NONE, 'bugfix');
        dwedhl.add_keyword(SRC_NONE, 'fix');
        dwedhl.add_keyword(SRC_NONE, 'fixit');
        dwedhl.add_keyword(SRC_NONE, 'note');

        create_menu;
end;

begin
        init;
end.

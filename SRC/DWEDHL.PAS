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
unit dwedhl;

interface

type

SourceType = (SRC_C, SRC_CMM, SRC_PAS, SRC_BAS, SRC_ASM, SRC_BAT, SRC_MD,
                SRC_XML, SRC_HTML, SRC_FORTH, SRC_NONE,
                SRC_DISABLE);

function find_SourceType_by_ext(ext : string): SourceType;
procedure high_light(st: SourceType; width : integer; hlclr, tclr : byte; scr:pchar);
procedure high_light_braket(width, posit : integer; c : char; scr : pchar);
procedure change_hl(var st : SourceType; color, color_sel : byte);

implementation

uses scr, scrui, kbd, strutil, event;

type

PVocabEntry = ^TVocabEntry;
TVocabEntry = record
        hash        : word;
        keyword     : string[16];
        next        : PVocabEntry;
end;

PLangDesc = ^TLangDesc;
TLangDesc = record
        st        : SourceType;
        hlchars   : string[128];
        caseSens  : boolean;
        ext       : string[64];
        vocab     : PVocabEntry;
        title     : string[24];
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
                if e.key = K_ESC then break;
                if (e.key = K_ENTER) or (lo(e.key) = 32) then begin
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

procedure add_lang(st : SourceType; ext : string; caseSens : boolean; hlchars, title : string);
var lng : PLangDesc;
begin
        getmem(lng, sizeof(TLangDesc));
        lng^.st := st;
        lng^.title := title;
        lng^.caseSens := caseSens;
        lng^.vocab := nil;
        lng^.ext := upstr(ext);
        lng^.hlchars := hlchars + #0;
        lng^.next := langs;
        langs := lng;
end;

function find_char(c : char; p : pchar):integer;assembler;
asm
        push       ds
        mov        ah, byte ptr [c]
        lds        si, [p]
        mov        cx, $FFFF
        mov        bx, si
        cld
@cont:
        lodsb
        or         al, al
        jz         @end
        cmp        al, ah
        jnz        @cont
        mov        cx, si
        sub        cx, bx
@end:
        mov        ax, cx
        pop        ds
end;

function find_SourceType_by_ext(ext : string): SourceType;
var lng : PLangDesc;
        r        : SourceType;
begin
        r := SRC_NONE;
        ext := '|' + upstr(ext) + '|';
        lng := langs;
        while lng <> nil do begin
                if System.pos(ext, lng^.ext) <> 0 then begin
                        r := lng^.st;
                        break;
                end;
                lng := lng^.next;
        end;
        find_SourceType_by_ext := r;
end;

procedure add_keyword(st : SourceType; keyword : string);
var lng : PLangDesc;
        entry : PVocabEntry;
begin
        lng := langs;
        while lng <> nil do begin
                if lng^.st = st then begin
                        getmem(entry, sizeof(TVocabEntry));
                        if not lng^.caseSens then keyword := upstr(keyword);
                        entry^.next := lng^.vocab;
                        entry^.keyword := keyword;
                        entry^.hash := hcode(keyword);
                        lng^.vocab := entry;
                        break;
                end;
                lng := lng^.next;
        end;
end;

function is_alpha(ch:char):boolean;
begin
        is_alpha := ch in ['a'..'z', 'A'..'Z', '0'..'9', '_'];
end;

function find_keyword(vocab : PVocabEntry; var str:string):boolean;
var r : boolean;
        hash : word;
begin
        r := false;
        hash := hcode(str);
        while vocab <> nil do begin
                if hash = vocab^.hash then begin
                        if vocab^.keyword = str then begin
                                r := true;
                                break;
                        end;
                end;
                vocab := vocab^.next;
        end;
        find_keyword := r;
end;

procedure hl(scr:pchar; width:integer; hlclr, tclr:byte; lng : PLangDesc; syschars:pchar);
var
        str         : string;
        ch          : char;
        pos         : integer;
        wordStarted : boolean;
        wordStart   : pchar;
begin
        wordStarted := false;
        while width <> 0 do begin
                ch := scr[0];
                if ord(scr[1]) = tclr then begin
                        if is_alpha(ch) then begin
                                if not wordStarted then begin
                                        wordStart := scr + 1;
                                        wordStarted := true;
                                        pos := 0;
                                end;
                                inc(pos);
                                str[pos] := ch;
                        end else begin
                                if wordStarted and (pos > 1) then begin
                                        str[0] := chr(pos);
                                        if not lng^.caseSens then str := upstr(str);
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
                                                wordStart[0] := chr(hlclr);
                                                inc(wordStart, 2);
                                        end;
}                                       
                                end;
                                wordStarted := false;
                                if (ch > ' ') then begin
                                        if find_char(ch, syschars) >= 0 then scr[1] := chr(hlclr);
                                end;
                        end;
                end else begin
                        wordStarted := false;
                end;
                inc(scr, 2);
                dec(width);
        end;
end;

procedure high_light(st: SourceType; width:integer; hlclr, tclr:byte; scr:pchar);
var lng : PLangDesc;
begin
        if st = SRC_DISABLE then exit;
        lng := langs;
        while lng <> nil do begin
                if lng^.st = st then begin
                        hl(scr, width, hlclr, tclr, lng, @lng^.hlchars[1]);
                        break;
                end;
                lng := lng^.next;
        end;
end;

function get_braket_pair(c : char) : char;
begin
        case c of
        '(': c := ')';
        ')': c := '(';
        '{': c := '}';
        '}': c := '{';
        '[': c := ']';
        ']': c := '[';
        else c := ' ';
        end;
        get_braket_pair := c;
end;

function get_direction(c : char) : boolean;
begin
        get_direction := c in ['(', '{', '['];
end;

procedure high_light_braket(width, posit : integer; c : char; scr : pchar);
var fchar    : char;
    pair     : char;
    cchar    : char;
    count, x : integer;
    step     : integer;
begin
        fchar := scr[posit shl 1];
        pair := get_braket_pair(fchar);
        if pair = ' ' then exit;
        if get_direction(fchar) then step := 1 else step := -1;
        x := posit; count := 0;
        while (x >= 0) and (x < width) do begin
                cchar := scr[x shl 1];

                if cchar = fchar then inc(count)
                else if cchar = pair then dec(count);

                if (cchar = pair) and (count = 0) then begin
                        scr[x shl 1] := c;
                        break;
                end;

                inc(x, step);
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

var i : integer; s : string;
begin
        dwedhl.add_lang(SRC_DISABLE, '|%?%|', false, '', '     DISABLE');
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

        s := '';
        for i := $B3 to $DA do s := s + chr(i);
        dwedhl.add_lang(SRC_NONE, '|txt|doc|diz||', false, '`^#@*_.,?+*/\-()!:;"=<>(){}[]~|' + s + #$27, 'Default text');
        dwedhl.add_keyword(SRC_NONE, 'http');
        dwedhl.add_keyword(SRC_NONE, 'ftp');
        dwedhl.add_keyword(SRC_NONE, 'sftp');
        dwedhl.add_keyword(SRC_NONE, 'email');
        dwedhl.add_keyword(SRC_NONE, 'mailto');
        dwedhl.add_keyword(SRC_NONE, 'http');
        dwedhl.add_keyword(SRC_NONE, 'ftp');
        dwedhl.add_keyword(SRC_NONE, 'sftp');
        dwedhl.add_keyword(SRC_NONE, 'email');
        dwedhl.add_keyword(SRC_NONE, 'mailto');
        dwedhl.add_keyword(SRC_NONE, 'url');
        dwedhl.add_keyword(SRC_NONE, 'if');
        dwedhl.add_keyword(SRC_NONE, 'then');
        dwedhl.add_keyword(SRC_NONE, 'else');
        dwedhl.add_keyword(SRC_NONE, 'return');
        dwedhl.add_keyword(SRC_NONE, 'todo');
        dwedhl.add_keyword(SRC_NONE, 'tbd');
        dwedhl.add_keyword(SRC_NONE, 'asap');
        dwedhl.add_keyword(SRC_NONE, 'bug');
        dwedhl.add_keyword(SRC_NONE, 'fix');
        dwedhl.add_keyword(SRC_NONE, 'fixit');
        dwedhl.add_keyword(SRC_NONE, 'note');

        create_menu;
end.

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
unit dwedlnch;

interface

const DEVFILE : string = 'DWED:';

procedure launcher(var exename:string);
function is_installed : boolean;

implementation

uses dos, strutil;

var
        cmd             : string;
        oldInt21        : pointer;
        requested_cmd   : string[255];
        path            : string;
        temp            : string;
        code            : integer;

procedure cmp_name;assembler;
asm
        pushf
        xchg       bx, dx
        xor        al, al
        cmp        ah, $3D { open }
        je         @cmp_names
        cmp        ah, $3C { create}
        je         @cmp_names
        jmp        @no
@cmp_names:
        cmp        byte ptr[BX + 0], 'D'
        je         @ok1
        cmp        byte ptr[BX + 0], 'd'
        je         @ok1
        jmp        @no
@ok1: 
        cmp        byte ptr[BX + 1], 'W'
        je         @ok2
        cmp        byte ptr[BX + 1], 'w'
        je         @ok2
        jmp        @no
@ok2:
        cmp        byte ptr[BX + 2], 'E'
        je         @ok3
        cmp        byte ptr[BX + 2], 'e'
        je         @ok3
        jmp        @no
@ok3:
        cmp        byte ptr[BX + 3], 'D'
        je         @ok4
        cmp        byte ptr[BX + 3], 'd'
        je         @ok4
        jmp        @no
@ok4:
        cmp        byte ptr[BX + 4], ':'
        jne        @no

        cmp        byte ptr[BX + 5], 0
        jne        @no

        inc        al
@no:
        xchg       bx, dx
        popf
end;

procedure write_hook;assembler;
asm
        push       di
        push       si
        push       es
        push       cx
        mov        si, dx
        mov        di, offset requested_cmd
        mov        dx, seg requested_cmd
        mov        es, dx
        xor        ch,ch
        cld
        rep        movsb
        pop        cx
        pop        es
        pop        si
        pop        di
end;

procedure read_hook;assembler;
asm
        push       di
        push       si
        push       es
        push       ds
        push       dx
        push       cx

        push       ds
        pop        es
        mov        di, dx
        mov        si, offset temp
        mov        dx, seg temp
        mov        ds, dx
        xor        ch, ch
        mov        cl, byte ptr [si]
        inc        cx
        push       cx
        cld
        rep        movsb
        pop        ax

        pop        cx
        pop        dx
        pop        ds
        pop        es
        pop        si
        pop        di
end;

procedure newInt21;assembler;
asm
        pushf
        push       ax
        call       cmp_name
        or         al, al
        pop        ax
        jz         @cont3
        popf
        mov        ax, $9915
        jmp        @ret_val
@cont3: cmp        ah, $40 { write file}
        jne        @cont4
        cmp        bx, $9915        
        jne        @cont4
        call       write_hook
        popf
        mov        ax, cx
        jmp        @ret_val
@cont4: cmp        ah, $3F { read file }
        jne        @cont5
        cmp        bx, $9915        
        jne        @cont5
        call       read_hook
        popf
        mov        ax, cx
        jmp        @ret_val
@cont5:
        cmp        ah, $3e { close file }
        jne        @cont6
        cmp        bx, $9915        
        jne        @cont6
        popf
        mov        ax, $0
        jmp        @ret_val
@cont6:
        cmp        ah, $42 { seek file }
        jne        @cont7
        cmp        bx, $9915        
        jne        @cont7
        xor        ax, ax
        xor        dx, dx
@cont7:
        popf
        push       ds
        push       ax
        mov        ax, SEG oldInt21
        mov        ds, ax
        mov        ax, word ptr [oldInt21]
        mov        word ptr cs:[@oInt21], ax
        mov        ax, word ptr [oldInt21 + 2]
        mov        word ptr cs:[@oInt21 + 2], ax
        pop        ax
        pop        ds
        jmp        dword ptr cs:[@oInt21]
@oInt21:
        dd         0
@rval:
        dw         0
@ret_val:
        mov        word ptr cs:[@rval], ax
        pop        ax
        mov        word ptr cs:[@oInt21], ax
        pop        ax
        mov        word ptr cs:[@oInt21 + 2], ax
        popf
        clc
        pushf
        mov        ax, word ptr cs:[@oInt21 + 2]
        push       ax
        mov        ax, word ptr cs:[@oInt21]
        push       ax
        mov        ax, word ptr cs:[@rval]
        iret
end;

procedure init;
begin
        getIntVec($21, oldInt21);
        setIntVec($21, @newInt21);
        cmd := '';
end;

procedure done;
begin
        setIntVec($21, oldInt21);
end;

function is_installed : boolean;
var f : text;
    i : integer;
begin
     assign(f, DEVFILE);
     {$I-}
     rewrite(f);
     i := ioresult;
     {$I+}
     if i = 0 then close(f);
     is_installed := i = 0;
end;

function rchar : char;
const chars : string = '0123456789-_qwertyuiopasdfghjklzxcvbnm';
begin
        rchar := chars[1 + random(length(chars))];
end;

function rfname : string;
var i : integer;
    r : string;
begin
        r := '';
        for i := 1 to 8 do begin
                r := r + rchar;
        end;
        r := r + '.';
        for i := 1 to 3 do begin
                r := r + rchar;
        end;
        rfname := r;
end;

procedure launcher(var exename:string);
var params : string;
        i : integer;
begin
        if is_installed then begin
                writeln('DWED cycle execution detected.');
                halt(1);
        end;
        randomize;
        params := '';
        for i := 1 to paramCount do begin
                if i <> 1 then params := params + ' ';
                params := params + paramStr(i);
        end;
        path := getpathname(paramstr(0));
        temp := getenv('DWED_HOME');
        if length(temp) = 0 then temp := getenv('TEMP');
        if length(temp) = 0 then temp := getenv('TMP');
        if length(temp) = 0 then temp := getenv('HOME');
        temp := rfname;
        while true do begin
                init;
                exec(path + exename, params);
                code := DosError;
                done;
                if (code = 254) and (length(cmd) <> 0) then begin
                        exec(getenv('COMSPEC'), cmd);
                end else break;
        end;
        halt(0);
end;

end.
unit sysext;

interface

procedure movew(var src; var dst; count : word);

function getCurrentDisk:byte;
procedure setCurrentDisk(disk : byte);

function getCurrentDir:string;
procedure setCurrentDir(dir : string);

function checkDriveExist(disk : byte):boolean;
function getAllDrives:string;

implementation

var buf : string;

procedure movew(var src; var dst; count : word);assembler;
asm
        push       es
        push       ds
        mov        cx, count
        lds        si, ss:src
        les        si, ss:dst
        cld
        rep        movsw
        pop        ds
        pop        es
end;

function getCurrentDisk:byte;assembler;
asm
        mov        ah,$19
        int        $21
end;

procedure setCurrentDisk(disk : byte);assembler;
asm
        mov        ah,$0e
        mov        dl, byte ptr [disk]
        int        $21
end;

function getCurrentDir:string;
var i : integer;
begin
        asm
                push       ds
                mov        ah, $47
                xor        dl, dl
                mov        si, offset buf + 1
                int        $21
                pop        ds
        end;
        i := 1;
        while buf[i] <> #0 do inc(i);
        buf[0] := chr(i - 1);
        if length(buf) = 0 then buf := '\';
        if buf[1] <> '\' then buf := '\' + buf;
        if buf[length(buf)] <> '\' then buf := buf + '\';
        getCurrentDir := buf;
end;

procedure setCurrentDir(dir : string);
begin
        buf := dir + #0;
        asm
                mov        dx, offset buf + 1
                mov        ah, $3b
                int        $21
        end;
end;

function checkDriveExist(disk : byte):boolean;assembler;
asm
        mov        dl, byte ptr [disk]
        inc        dl
        mov        ah, $36
        int        $21
        xor        cl, cl
        cmp        ax, $FFFF
        dec        cl
@nodrive:
        mov        al, bl
end;

function getAllDrives:string;
var r : string;
    i : integer;
begin
        r := '';
        for i := ord('A') to ord('Z') do begin
                if checkDriveExist(i - ord('A')) then r := r + chr(i);
        end;
        getAllDrives := r;
end;

end.

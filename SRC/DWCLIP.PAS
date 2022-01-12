USES system2, wincb;

FUNCTION Status : BOOLEAN;
VAR     r : BOOLEAN;
BEGIN
        r := WCB_Detect;
        System.Write('Windows Clipboard support - ');
        IF r THEN System.Write('OK')
        ELSE System.Write('NONE');
        System.WriteLn;
        Status := r;
END;

PROCEDURE Help;
BEGIN
        System.WriteLn('usage: DWCLIP [C filename] [P]');
        System.WriteLn;
        System.WriteLn('C filename - copy file to clipbaord');
        System.WriteLn('P          - paste from clipbaord to STDOUT');
        System.WriteLn;
        System.WriteLn('NOTE: 64kb restictions!');
        Status;
        Halt(1);
END;

PROCEDURE Copy(fname : STRING);
VAR     p    : PCHAR;
        f    : BFile;
        w    : WORD;
BEGIN
        IF NOT Status THEN EXIT;
        GetMem(p, 65001);
        IF p = NIL THEN BEGIN
                WriteLnErr('Error: No memory.');
                Halt(1);
        END;
        Assign(f, fname);
        Reset(f);
        IF IsOpen(f) THEN BEGIN
                w := BlockRead(f, p[0], 65000);
                p[w] := #0;
                WCB_Open;
                WCB_Clear;
                WCB_SetData(p[0], w);
                WCB_Close;
                Close(f);
        END ELSE BEGIN
                WriteLnErr('Error: Could not read ' + fname);
        END;
        FreeMem(p, 65001);
END;

PROCEDURE Paste;
VAR     p    : PCHAR;
        w    : WORD;
        size : DWORD;
BEGIN
        IF NOT WCB_Detect THEN EXIT;
        size := WCB_GetDataSize;
        IF size > 65000 THEN BEGIN
                WriteLnErr('Error: clipboard content has size more 64Kb');
                EXIT;
        END;
        GetMem(p, 65001);
        IF p = NIL THEN BEGIN
                WriteLnErr('Error: No memory.');
                Halt(1);
        END;
        WCB_Open;
        WCB_GetData(p[0]);
        WCB_Close;
        p[w] := #0;
        System.WriteLn(p);
        FreeMem(p, 65001);
END;

VAR     pc  : INTEGER;
        cmd : STRING;
BEGIN
        pc := ParamCount;
        IF pc = 0 THEN Help;
        cmd := ParamStr(1);
        IF (UPCASE(cmd[1]) = 'C') AND (pc = 2) THEN Copy(ParamStr(2))
        ELSE IF UPCASE(cmd[1]) = 'P'THEN Paste
        ELSE Help;
END.
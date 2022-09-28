{  MIT License

Copyright (c) 2022 Viacheslav Komenda

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
{$M 32768,131072,131072}

USES System2, WinCB;

CONST

ERR_NO_MEMORY = 'ERROR: No memory.';
ERR_NO_FILE   = 'ERROR: Could not read ';

ERROR = 1;
OK    = 0;

PROCEDURE Help;
BEGIN
        System.WriteLn('usage: DWCLIP [C fname] [P]');
        System.WriteLn;
        System.WriteLn('C fname - copy text file to clipboard');
        System.WriteLn('P       - paste from clipboard to STDOUT');
        System.WriteLn;
        System.WriteLn('NOTE: 64kb restiction. DOS LFN - supported, use name with quotes.');
        System.WriteLn;
        System.Write('Check Windows Clipboard status: ');
        IF WCB_Detect THEN System.Write('OK')
        ELSE System.Write('NONE');
        System.WriteLn;
END;

PROCEDURE Copy(fname : STRING);
VAR     p    : PCHAR;
        f    : BFile;
        w    : WORD;
BEGIN
        IF NOT WCB_Detect THEN EXIT;
        GetMem(p, 65000);
        IF p = NIL THEN BEGIN
                Help;
                System.WriteLn;
                WriteLnErr(ERR_NO_MEMORY);
                Halt(ERROR);
        END;
        Assign(f, fname);
        Reset(f);
        IF NOT IsOpen(f) THEN BEGIN
                FreeMem(p, 65000);
                Help;
                System.WriteLn;
                WriteLnErr(ERR_NO_FILE + fname);
                Halt(ERROR);
        END;
        w := BlockRead(f, p^, 65000 - 1);
        Close(f);
        p[w] := #0;
        WCB_Copy(p, w + 1);
        FreeMem(p, 65000);
        Halt(OK);
END;

PROCEDURE Paste;
VAR     p    : PCHAR;
BEGIN
        IF NOT WCB_Detect THEN EXIT;
        GetMem(p, 65000);
        IF p = NIL THEN BEGIN
                Help;
                System.WriteLn;
                WriteLnErr(ERR_NO_MEMORY);
                Halt(ERROR);
        END;
        IF WCB_Paste(p^, 65000) THEN System.WriteLn(p);
        FreeMem(p, 65000);
        Halt(OK);
END;

VAR     pc  : INTEGER;
        cmd : STRING;
BEGIN
        pc := ParamCount;
        IF pc > 0 THEN BEGIN
                cmd := ParamStr(1);
                CASE UPCASE(cmd[1]) OF
                'C': IF pc = 2 THEN Copy(ParamStr(2));
                'P': Paste;
                END;
        END;
        Help;
        Halt(ERROR);
END.

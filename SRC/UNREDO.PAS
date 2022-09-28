{
 MIT License

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
{$A-}
unit unredo;

interface

const
ALINE : char = 'a';
RLINE : char = 'r';

procedure init;
procedure done;

implementation

uses system2, str, dbm, dbb;

type
TString = record
        next   : longint;
        prev   : longint;
        utype  : char;
        len    : word;
        num    : longint;
        recno  : longint;
end;

const   MEM_BLK_SIZE = 32;
        IDX_BLK_SIZE = sizeof(TString);

var     dbm_mem : DBMFile;
        dbb_idx : DBBFile;


procedure init;
begin
        FillChar(dbm_mem, SizeOf(DBMFile), #0);
        FillChar(dbb_idx, SizeOf(DBBFile), #0);
        dbm_rewrite_temp(dbm_mem, MEM_BLK_SIZE);
        dbb_rewrite_temp(dbb_idx, IDX_BLK_SIZE);
end;

procedure done;
begin
        dbm_close(dbm_mem);
        dbb_close(dbb_idx);
end;

end.


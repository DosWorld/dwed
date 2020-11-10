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
{$A-,G-,S-,R-,Q-}
unit help;

interface

type

PHelpTopic=^THelpTopic;
THelpTopic=record
        name : array[1..12] of char;
        recno : word;
        ofs : byte;
        lvl : byte;
end;

PHelpTopicList=^THelpTopicList;
THelpTopicList=record
        topic        :THelpTopic;
        htext        :pchar;
        hlen        :word;
        next        :PHelpTopicList;
end;

function from_file(fname : string):PHelpTopicList;
function from_memory(p : pointer):PHelpTopicList;

function find(root : PHelpTopicList; topic_name : string):PHelpTopicList;

procedure free(hlp : PHelpTopicList);

procedure compile(ifname, ofname : string);

implementation

type

PHelpIntTopic=^THelpIntTopic;
THelpIntTopic=record
        name        :string;
        ofs        :longint;
        lvl        :byte;
        next        :PHelpIntTopic;
end;

function is_digit(c:char):boolean;
begin
        is_digit := c in ['0'..'9'];
end;

procedure compile(ifname, ofname : string);
var ifile:text;
        ofile        : file;
        s        : string;
        tcount        : word;
        root, last, cur : PHelpIntTopic;
        ofs        : longint;
        topic        : THelpTopic;
        i, l        : integer;
begin
        tcount := 0; root := nil; last := nil; ofs := 0;
        assign(ifile, ifname);
        {$I-}
        reset(ifile);
        {$I+}
        if ioresult <> 0 then exit;
        while not eof(ifile) do begin
                readln(ifile, s);
                l := length(s);
                if l > 80 then s := copy(s, 1, 80);
                if length(s)>4 then begin
                        if (s[1] = '/') and (s[2] = '/') and (s[3] = '/') and is_digit(s[4]) then begin
                                getmem(cur, sizeof(THelpIntTopic));
                                cur^.lvl := ord(s[4]) - ord('0');
                                cur^.name := copy(s, 5, length(s)-4);
                                cur^.ofs := ofs + length(s);
                                cur^.next := nil;
                                if root = nil then root := cur;
                                if last <> nil then last^.next := cur;
                                last := cur;
                                inc(tcount);
                        end;
                end;
                inc(ofs, length(s) + 2);
        end;
        close(ifile);

        inc(tcount);

        while ((tcount * sizeof(THelpTopic)) and $7f) <> 0 do begin
                inc(tcount);
        end;

        assign(ofile, ofname);
        rewrite(ofile, 1);

        ofs := sizeof(THelpTopic) * tcount;
        cur := root;
        while cur<>nil do begin
                inc(cur^.ofs, ofs);
                topic.recno := cur^.ofs shr 7;
                topic.ofs := cur^.ofs and $7f;
                topic.lvl := cur^.lvl;
                fillchar(topic.name, 12, ' ');
                l := length(cur^.name);
                if l > 12 then l := 12;
                for i:=1 to l do topic.name[i] := upcase(cur^.name[i]);
                blockwrite(ofile, topic, sizeof(THelpTopic));
                dec(tcount);
                cur := cur^.next;
        end;
        topic.recno := 0;
        topic.ofs := 0;
        topic.lvl := 0;
        fillchar(topic.name, 12, ' ');
        topic.name[1] := '$';
        while tcount <> 0 do begin
                blockwrite(ofile, topic, sizeof(THelpTopic));
                dec(tcount);
        end;

        reset(ifile);
        while not eof(ifile) do begin
                readln(ifile, s);
                s := s + #13 + #10;
                blockwrite(ofile, s[1], length(s));
        end;
        l := 128 - (filepos(ofile) and $7f);
        s := '';
        for i := 1 to l do s := s + #$1a;
        blockwrite(ofile, s[1], length(s));
        close(ifile);
        close(ofile);
        while root <> nil do begin
                cur := root;
                root := root^.next;
                freemem(cur, sizeof(THelpIntTopic));
        end;
end;

function find(root:PHelpTopicList; topic_name:string):PHelpTopicList;
var
        name        : array[1..12] of char;
        i, l        : integer;
        found        : boolean;
        r        : PHelpTopicList;
begin
        fillchar(name, 12, ' ');
        l := length(topic_name);
        if l > 12 then l := 12;
        for i:=1 to l do name[i] := upcase(topic_name[i]);

        r := root;
        found := false;
        while (not found) and (r <> nil) do begin
                found := true;
                for i:=1 to 12 do if name[i] <> r^.topic.name[i] then begin found := false; break; end;
                if found then break;
                r := r^.next;
        end;
        if not found then r := nil;
        find := r;
end;

function from_file(fname:string):PHelpTopicList;
var
        f        : file;
        r, l, c        : PHelpTopicList;
        nt, fs        : longint;
begin
        r := nil; c := nil; l := nil;
        assign(f, fname);
        {$I-}
        reset(f, 1);
        {$I+}
        while true do begin
                getmem(c, sizeof(THelpTopicList));
                blockread(f, c^.topic, sizeof(THelpTopic));
                c^.next := nil;
                c^.htext := nil;
                c^.hlen := 0;
                if r = nil then r := c;
                if l <> nil then l^.next := c;
                if (c^.topic.recno = 0) and (c^.topic.ofs = 0) and (c^.topic.ofs = 0) then break;
                l := c;
        end;
        fs := filesize(f);
        c := r;
        while c <> nil do begin
                if (c^.topic.recno = 0) and (c^.topic.ofs = 0) and (c^.topic.ofs = 0) then break;
                if (c^.next^.topic.recno = 0) and (c^.next^.topic.ofs = 0) and (c^.next^.topic.ofs = 0) then nt := fs
                else nt := (c^.next^.topic.recno shl 7) + c^.next^.topic.ofs;
                c^.hlen := nt - ((c^.topic.recno shl 7) + c^.topic.ofs) + 1;
                getmem(c^.htext, c^.hlen);
                seek(f, (c^.topic.recno shl 7) + c^.topic.ofs);
                blockread(f, c^.htext[0], c^.hlen - 1);
                c^.htext[c^.hlen - 1] := #0;
                c := c^.next;
        end;
        close(f);
        from_file := r;
end;

function from_memory(p:pointer):PHelpTopicList;
var
        rp, ep        : pchar;
        r, l, c        : PHelpTopicList;
        nt, fs        : longint;
begin
        r := nil; c := nil; l := nil;
        rp := p;
        while true do begin
                getmem(c, sizeof(THelpTopicList));
                move(rp[0], c^.topic, sizeof(THelpTopic));
                inc(rp, sizeof(THelpTopic));
                c^.next := nil;
                c^.htext := nil;
                c^.hlen := 0;
                if r = nil then r := c;
                if l <> nil then l^.next := c;
                if (c^.topic.recno = 0) and (c^.topic.ofs = 0) and (c^.topic.ofs = 0) then break;
                l := c;
        end;
        ep := rp;
        while ep[0] <> #$1a do inc(ep);
        rp := p;
        fs := ep - rp;
        c := r;
        while c <> nil do begin
                if (c^.topic.recno = 0) and (c^.topic.ofs = 0) and (c^.topic.ofs = 0) then break;
                if (c^.next^.topic.recno = 0) and (c^.next^.topic.ofs = 0) and (c^.next^.topic.ofs = 0) then nt := fs
                else nt := (c^.next^.topic.recno shl 7) + c^.next^.topic.ofs;
                c^.hlen := nt - ((c^.topic.recno shl 7) + c^.topic.ofs) + 1;
                getmem(c^.htext, c^.hlen);
                move(rp[(c^.topic.recno shl 7) + c^.topic.ofs], c^.htext[0], c^.hlen - 1);
                c^.htext[c^.hlen - 1] := #0;
                c := c^.next;
        end;
        from_memory := r;
end;

procedure free(hlp:PHelpTopicList);
var h:PHelpTopicList;
begin
        while hlp <> nil do begin
                h := hlp;
                hlp := hlp^.next;
                if h^.htext <> nil then freemem(h^.htext, h^.hlen);
                freemem(h, sizeof(THelpTopicList));
        end;
end;

end.

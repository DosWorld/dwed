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
unit dwedhelp;

interface

procedure dwed_help(var topic_id:integer;
        help_menu_clr,
        help_menu_sel_clr,
        help_clr,
        help_hl_clr : byte);

implementation

uses scr, scrui, kbd, strutil, help, event;

procedure helpbin;external;
{$L dwedhelp.obj}

var topic_list : PHelpTopicList;
        topic_menu : pchar;
        width      : integer;

function get_name(t : PHelpTopicList):string;
var s : string;
    i : integer;
begin
        s := '';
        for i := 1 to 12 do s := s + t^.topic.name[i];
        get_name := trim(s);
end;

procedure dwed_help(var topic_id:integer;
        help_menu_clr,
        help_menu_sel_clr,
        help_clr,
        help_hl_clr : byte);
var r : PHelpTopicList;
        y, i      : integer;
        p         : pchar;
        helpStr   : string;
        selItem   : integer;
        e         : TEvent;
begin
        scr.cursor_off;
        r := nil;
        selItem := topic_id;
        while true do begin
                r := topic_list;
                i := topic_id;
                while (i <> 0) and (r <> nil) do begin
                        dec(i);
                        r := r^.next;
                end;
                if r <> nil then begin
                        for i := 1 to scr.getheight - 1 do scr.cln(width + 4, i, help_clr);
                        scr.printhl(width + 5, 2, help_clr, help_hl_clr, '~' + #$9 + '~ Help topic - ~' + get_name(r) + '~');
                        p := r^.htext;
                        i := r^.hlen;
                        y := 4;
                        helpStr := '';
                        while i <> 0 do begin
                                case p[0] of
                                #$0A: begin
                                        if (helpStr[1] <> '/')
                                        and  (helpStr[2] <> '/')
                                        and (length(helpStr) > 0) then begin
                                                scr.printhl(width + 5, y, help_clr, help_hl_clr, helpStr);
                                        end;
                                        inc(y);
                                        helpStr := '';
                                end;
                                #$0D:
                                else helpStr := helpStr + p[0];
                                end;
                                inc(p);
                                dec(i);
                        end;
                        if (helpStr[1] <> '/')
                        and  (helpStr[2] <> '/')
                        and (length(helpStr) > 0) then begin
                                scr.printhl(width + 5, y, help_clr, help_hl_clr, helpStr);
                        end;
                end;
                while true do begin
                        scrui.vmenu(e, 0, 1, width + 4, scr.getheight - 1,
                                help_menu_clr, help_menu_sel_clr,
                                'Help', topic_menu, selItem);
                        if e.etype = KEYBOARD then break;
                end;
                case e.scancode of
                SCAN_ESC: break;
                SCAN_BS: break;
                SCAN_ENTER: topic_id := selItem;
                SCAN_SPACE: topic_id := selItem;
                end;
        end;
        kbd.reset;
end;

procedure init;
var t : PHelpTopicList;
    maxlen    : integer;
    len       : integer;
    totallen  : integer;
    topicname : string;
    i, pos    : integer;
begin
        topic_list := from_memory(Pointer(@helpbin));
        maxlen := 0;
        totallen := 0;
        t := topic_list;
        while t <> nil do begin
                topicname := get_name(t);
                len := t^.topic.lvl * 2 + length(topicname);
                if maxlen < len then maxlen := len;
                inc(totallen, len + 1);
                t := t^.next;
        end;
        getmem(topic_menu, totallen);
        pos := 0;
        t := topic_list;
        while t <> nil do begin
                topicname := get_name(t);
                if topicname = '$' then break;
                if pos <> 0 then begin
                        topic_menu[pos] := #$0A;
                        inc(pos);
                end;
                topicname := lpad(topicname, length(topicname) + t^.topic.lvl * 2);
                for i := 1 to length(topicname) do begin
                        topic_menu[pos] := topicname[i];
                        inc(pos);
                end;
                t := t^.next;
        end;
        topic_menu[pos] := #0;
        width := maxlen;
end;

begin
        init;
end.

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
unit event;

interface

const
key_ctrl  = 1;
key_shift = 2;
key_alt   = 4;

type
EventType = (NONE,
        KEYBOARD,
        MOUSE_MOVE,
        MOUSE_PRESS_B1, MOUSE_PRESS_B2,
        MOUSE_RELEASE_B1, MOUSE_RELEASE_B2
        );

PEvent = ^TEvent;
TEvent = record
        etype          : EventType;
        scancode       : byte;
        ascii          : char;
        ctrl_keys      : word;
        mouse_left     : boolean;
        mouse_right    : boolean;
        mouse_x        : integer;
        mouse_y        : integer;
end;

procedure wait_event(var e : TEvent);
function has_event : boolean;
function ctrl_key_word(is_ctrl, is_shift, is_alt : boolean) : word;

implementation

uses kminput;

function has_event:boolean;
begin
        has_event := kbd_haskey;
end;

procedure wait_event(var e : TEvent);
var     state    : byte;
        newstate : byte;
        mx, my   : integer;
        flags    : byte;
        key      : word;
begin
        fillchar(e, sizeof(TEvent), #0);
        e.etype := NONE;
        if mouse_avail then begin
                state := mouse_buttons;
                e.mouse_x := mouse_getx;
                mx := mouse_getx;
                my := mouse_gety;
                e.mouse_y := mouse_gety;
        end else begin
                e.mouse_x := 0;
                e.mouse_y := 0;
                e.mouse_left := false;
                e.mouse_right := false;
        end;
        while e.etype = NONE do begin
                if kbd_haskey then begin
                        key := kbd_getkey;
                        e.etype := KEYBOARD;
                        e.scancode := hi(key);
                        e.ascii := chr(lo(key));
                end else if mouse_avail then begin
                        newstate := mouse_buttons;
                        e.mouse_x := mouse_getx;
                        e.mouse_y := mouse_gety;
                        e.mouse_left := (newstate and MOUSE_B1) <> 0;
                        e.mouse_right := (newstate and MOUSE_B2) <> 0;
                        if state <> newstate then begin
                                if (newstate and MOUSE_B1) <> (state and MOUSE_B1) then begin
                                        if (newstate and MOUSE_B1) <> 0 then
                                                e.etype := MOUSE_PRESS_B1
                                        else e.etype := MOUSE_RELEASE_B1; 
                                end else if (newstate and MOUSE_B2) <> (state and MOUSE_B2) then begin
                                        if (newstate and MOUSE_B2) <> 0 then
                                                e.etype := MOUSE_PRESS_B2
                                        else e.etype := MOUSE_RELEASE_B2; 
                                end;
                        end else if (e.mouse_x <> mx) or (e.mouse_y <> my) then begin
                                e.etype := MOUSE_MOVE;
                        end;
                end;
                if e.etype = NONE then begin
                        asm
                                mov        ax,$8600
                                xor        cx, cx
                                mov        dx, 250
                                int        $15
                        end;
                end;
        end;
        if e.etype <> MOUSE_MOVE  then begin
                flags := kbd_getflags;
                e.ctrl_keys := ctrl_key_word(is_ctrl(flags), is_shift(flags), is_alt(flags));
        end;
end;

function ctrl_key_word(is_ctrl, is_shift, is_alt : boolean) : word;
var     r : word;
begin
        r := 0;
        if is_ctrl then r := r or key_ctrl;
        if is_shift then r := r or key_shift;
        if is_alt then r := r or key_alt;
        ctrl_key_word := r;
end;

end.

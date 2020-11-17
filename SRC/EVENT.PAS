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
{$G-,S-,R-,I-}
unit event;

interface

Type
EventType = (NONE,
        KEYBOARD,
        MOUSE_MOVE,
        MOUSE_PRESS_B1, MOUSE_PRESS_B2,
        MOUSE_RELEASE_B1, MOUSE_RELEASE_B2
        );

PEvent = ^TEvent;
TEvent = record
        etype          : EventType;
        key            : word;
        is_ctrl        : boolean;
        is_shift       : boolean;
        is_alt         : boolean;
        mouse_left     : boolean;
        mouse_right    : boolean;
        mouse_x        : integer;
        mouse_y        : integer;
end;

procedure wait_event(var e : TEvent);

implementation

uses mouse, kbd;

procedure wait_event(var e : TEvent);
var state    : byte;
    newstate : byte;
    mx, my   : integer;
begin
        e.key := 0;
        e.etype := NONE;
        if mouse.mavail then begin
                state := mouse.mbuttons;
                e.mouse_x := mouse.mgetx;
                mx := mouse.mgetx;
                my := mouse.mgety;
                e.mouse_y := mouse.mgety;
        end else begin
                e.mouse_x := 0;
                e.mouse_y := 0;
                e.mouse_left := false;
                e.mouse_right := false;
        end;
        while e.etype = NONE do begin
                if kbd.haskey then begin
                        e.etype := KEYBOARD;
                        e.key := kbd.getkey;
                        e.is_ctrl := kbd.is_ctrl;
                        e.is_alt := kbd.is_alt;
                        e.is_shift := kbd.is_shift;
                        break;
                end;
                if mouse.mavail then begin
                        newstate := mouse.mbuttons;
                        e.mouse_x := mouse.mgetx;
                        e.mouse_y := mouse.mgety;
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
        end;
end;

end.
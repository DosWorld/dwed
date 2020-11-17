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
{$B-,S-,R-,I-}
unit dwedpar;

interface

type

ParamsContext=record
        pos  : integer;
        len  : integer;
        line : string;
end;

procedure pinit(var ctx : ParamsContext; cmdParams : string);
function phas_next(var ctx : ParamsContext) : boolean;
function pnext(var ctx : ParamsContext) : string;

implementation

procedure pinit(var ctx : ParamsContext; cmdParams : string);
begin
        ctx.pos := 1;
        ctx.line := cmdParams;
        ctx.len := length(ctx.line);
end;

function phas_next(var ctx : ParamsContext) : boolean;
begin
        while (ctx.line[ctx.pos] = ' ') and (ctx.pos <= ctx.len) do inc(ctx.pos);
        phas_next := ctx.pos <= ctx.len;
end;

function pnext(var ctx : ParamsContext) : string;
var res : string;
    i : integer;
    cur, prev : char;
    inquote   : boolean;
begin
        res := '';
        i := ctx.pos;
        prev := ' '; inquote := false;
        while (ctx.pos <= ctx.len) do begin
                cur := ctx.line[ctx.pos];
                case cur of
                '"': if not inquote then inquote := true
                     else if inquote then inquote := false;
                ' ': if not inquote then break;
                end;
                inc(ctx.pos);
                prev := cur;
        end;
        res := copy(ctx.line, i, ctx.pos - i);
        pnext := res;
end;

{
Test-case
var c : ParamsContext;
    i : integer;
begin
        pinit(c, ' test1 aa="test o test" test2 ');
        i := 0;
        while phas_next(c) do begin
                writeln(i, ' ', pnext(c));
                inc(i);
        end;
}
end.
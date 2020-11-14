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
unit sysext;

interface

procedure movew(var src var dst; count : word);
procedure assign(var f : file; name : string);
procedure GetVec(VecNo :Word; Var SavPoint :Pointer);
procedure SetVec(VecNo :Word; NewPoint :Pointer);

implementation

procedure movew(var src var dst; count : word);assembler;
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

procedure assign(var f : file; name : string);
begin
        System.assign(f, name);
end;

procedure GetVec(VecNo :Word; Var SavPoint :Pointer); (* DOS Sucks      *)
Var
   SavSeg, SavOff :Word;            (* Temp variables for pointer       *)
Begin
   Asm
      Push  Es                      (* Save Es                          *)
      Shl   VecNo, 2                (* Multiply num by 4 to get address *)
      Mov   Es, Word Ptr 0h         (* Zero Es. Vect Int's start at 0:0 *)
      Mov   Di, VecNo               (* Di = Num * 4                     *)
      Mov   Ax, Word Ptr [Es:Di]    (* Copy offset word of int,         *)
      Mov   SavOff, Ax              (* and save it                      *)
      Add   Di, 2                   (* Point to next word (segment)     *)
      Mov   Ax, Word Ptr [Es:Di]    (* Ax = Offset                      *)
      Mov   SavSeg, Ax              (* Save in temporary variable       *)
      Pop   Es                      (* Retrieved stored value           *)
   End;
   SavPoint := Ptr(SavSeg, SavOff); (* Convert Seg:Offset to pointer    *)
End;

procedure SetVec(VecNo :Word; NewPoint :Pointer);  (* Don't use units   *)
Type                                (* Revectors the interrupts         *)
   PType          = Array[0..1] of Word;
Var
   NtPoint        : ^PType;
Begin
   Asm Cli End;                     (* No interrupts can be generated   *)
   NtPoint := @NewPoint;            (* during the process               *)
   MemW[0:VecNo*4] := NtPoint^[0];
   MemW[0:VecNo*4+2] := NtPoint^[1];
   Asm Sti End;                     (* Enable Interrupts                *)
End;

end.

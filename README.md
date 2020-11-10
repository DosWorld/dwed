# DWED

Text file editor for MS-DOS and 8086 CPU designed in modern style for a IBM XT-grade PC.

Main features:

* Support files over 64k
* Support syntax hightlight (C/C++/C--, Pascal, Basic, Assembler, Xml/Html, text files etc)
* Support multiple file editing at the same time
* Support internal clipboard (size up to 32k)
* Support unix-like text files for open
* Dont require DPMI-server or 80286 CPU

Restrictions:

* This software is writen in Turbo Pascal, so string length is limited to 255 chars.
* DOS-conventional memory will be enought to load file up to ~300k..400k (expect - 300k border).
* No Undo/Redo functionality. The reason is the same as why i dont build AST for syntax hightlight - here is no memory for it.

# Screenshots

Text file:
![Image Screenshot - Txt syntax hightlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-TXT.PNG)

Turbo Pascal source code:
![Image Screenshot - Pascal syntax hightlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-PAS.PNG)

Power Basic source code:
![Image Screenshot - Basic syntax hightlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-BAS.PNG)

C source code:
![Image Screenshot - C syntax hightlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-C.PNG)

# Build

To build binaries, you need Turbo Pascal 7.0 in path and my small make. Then - type

      make

# LICENSE

MIT License

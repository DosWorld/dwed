# DWED

Text file editor for MS-DOS and 8086 CPU designed in modern style.

Main features:

* Support files over 64k
* Support syntax hightlight (C/C++/C--, Pascal, Basic, Assembler, Xml/Html, text files etc)
* Support multiple file editing at the same time
* Support internal clipboard
* Support unix-like text files for open
* Dont require DPMI-server or 80286 CPU

Restrictions:

* This software is writen in Turbo Pascal, so string length is limited to 255 chars.
* DOS-conventional memory will be enought to load file up to ~300k..400k (expect 300k border).

# Screenshots

![Image Screenshot - Txt syntax hightlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-TXT.PNG)
![Image Screenshot - Pascal syntax hightlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-PAS.PNG)
![Image Screenshot - Basic syntax hightlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-BAS.PNG)

# Build

To build binaries, you need Turbo Pascal 7.0 in path and my small make. Then - type

      make

# LICENSE

MIT License

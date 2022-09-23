# DWED

Text file editor and IDE for MS-DOS and 8086/88 CPU (IBM XT-grade PC) designed in modern style.

Main features:

* Support files with size over 64k
* Support basic syntax highlight (C/C++/C--, Pascal, Basic, Assembler, Xml/Html, text files etc)
* Support multiple file editing at the same time
* Support internal clipboard (size up to 32k)
* Support unix-like text files for open
* Dont require DPMI-server or 80286 CPU, but support huge swap-file (could be placed on ramdisk) - up to 2G
* Support Long File Names (LFN)
* Support Windows Clipboard (you can use it with DosBox-X)
* Support user's color scheme (via config-file)
* Support user's shell script running by hotkeys **F5**, **F8**, **F9**.
* You can disable highlight and receive good speed with XT.
* Support mouse

Restrictions:

* This software is writen in Borland Pascal, so string length is limited to 255 chars.
* DOS-conventional memory will be enought to load file up to ~300k..400k (expect - 300k border).
* DWED don't parse file content in the same way, as compilers - so, some time syntax highlight can fail (be wrong). I know it. But it is better then nothing.
* No Undo/Redo functionality. The reason is the same as why i dont build AST for syntax highlight - here is no memory/CPU speed for it.

Here is small review/intro on FreeDOS channel: http://www.youtube.com/watch?v=7zFomGoKdlQ

# How to run and use
Use:

	C:\DWED\dwed.exe filename1 .. filenameN

Use key **F1** to get more documentation (hotkeys, tips etc). I don't want write documentation and put all knowledge to buildin help.

# Screenshots

### Text file highlight
![Image Screenshot - Txt syntax highlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-TXT.PNG)

### Turbo Pascal syntax highlight
![Image Screenshot - Pascal syntax highlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-PAS.PNG)

### Power Basic syntax highlight
![Image Screenshot - Basic syntax highlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-BAS.PNG)

### C syntax highlight
![Image Screenshot - C syntax highlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-C.PNG)

### Help mode
![Image Screenshot - C syntax highlighjt](https://github.com/DosWorld/dwed/raw/main/DWED-HLP.PNG)

### ASCII Table addon
![Image ASCII Table addon](https://github.com/DosWorld/dwed/raw/main/DWED-ASC.PNG)

Inspired by

	ASCII program. Version 4.23 (C) Compact Soft, 1991.
	By: Alexander Dudarenko & Dmitry Kohmanyuk.

Published at Softpanorama in 1993 (SP53A), now here is my remake for dwed.
### Calculator addon
![Image Calculator addon](https://github.com/DosWorld/dwed/raw/main/DWED-CLC.PNG)

# Build and dependency

Requires system2 library - https://github.com/DosWorld/libsystem2

To build binaries, you need Borland Pascal 7.0 in path, SPHINX C-- by Michael Sheker and my small make. Then - type

      make

# License

MIT License

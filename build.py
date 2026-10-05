#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Assemble dist/PartageCOM.bat a partir de src/gui.ps1 et des binaires de vendor/.

Le .bat produit est un fichier unique "tout-en-un" :
  - un en-tete .bat (ASCII pur) qui extrait et execute le PowerShell en memoire ;
  - le script PowerShell (interface WinForms) entre #PS_BEGIN et #PS_END ;
  - trois binaires encodes en base64 (com0com x64, com0com x86, hub4com).

Encodage de sortie : UTF-8 SANS BOM (le script contient des accents ; l'en-tete
.bat reste ASCII et cmd s'arrete sur "exit /b" avant les octets accentues).

Usage : python3 build.py
"""
import base64
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
SRC = ROOT / "src" / "gui.ps1"
VENDOR = ROOT / "vendor"
OUT = ROOT / "dist" / "PartageCOM.bat"

BINARIES = [
    ("COM0COM_X64", VENDOR / "com0com-3.0.0.0-Win-x64_Setup-Signed.exe"),
    ("COM0COM_X86", VENDOR / "com0com-3.0.0.0-Win-x86_Setup-Signed.exe"),
    ("HUB4COM",     VENDOR / "hub4com-2.1.0.0.exe"),
]

HEADER = r"""@echo off
REM ============================================================
REM  PartageCOM - fichier unique "tout-en-un"  (F5PBG)
REM  Contient : interface graphique (PowerShell), com0com v3.0.0.0 signe
REM  (x86 et x64) et hub4com v2.1.0.0 - projet com0com, licence GPL.
REM  Double-cliquez simplement sur ce fichier. Journal : PartageCOM.log
REM ============================================================
set "PARTAGECOM_BAT=%~f0"
set "PARTAGECOM_AUTO=%~1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -Command "$f=[IO.File]::ReadAllLines($env:PARTAGECOM_BAT); $a=[Array]::IndexOf($f,'#PS_BEGIN'); $b=[Array]::IndexOf($f,'#PS_END'); $c=($f[($a+1)..($b-1)] -join [Environment]::NewLine); & ([scriptblock]::Create($c))"
if errorlevel 1 (
  echo.
  echo PartageCOM s'est arrete sur une erreur. Consultez PartageCOM.log dans ce dossier.
  pause
)
exit /b
#PS_BEGIN
"""


def b64(path: pathlib.Path) -> str:
    data = path.read_bytes()
    s = base64.b64encode(data).decode("ascii")
    return "\n".join(s[i:i + 76] for i in range(0, len(s), 76))


def main() -> None:
    gui = SRC.read_text(encoding="utf-8")
    out = HEADER + gui + "\n#PS_END\n"
    for name, path in BINARIES:
        out += f"#B64_{name}_BEGIN\n{b64(path)}\n#B64_{name}_END\n"
    # Fins de ligne Windows, encodage UTF-8 sans BOM.
    out = out.replace("\r\n", "\n").replace("\n", "\r\n")
    OUT.write_bytes(out.encode("utf-8"))
    print(f"ecrit : {OUT} ({OUT.stat().st_size} octets)")


if __name__ == "__main__":
    main()

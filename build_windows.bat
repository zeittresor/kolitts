@echo off
setlocal EnableExtensions
cd /d "%~dp0"
color 0E
title KolibriTTS v0.1 - Windows Build

echo ============================================================
echo   KolibriTTS v0.1 - FASM compiler script for Windows
echo ============================================================
echo.

set "FASM=tools\fasm.exe"
if not exist "%FASM%" if exist "%FASM_HOME%\fasm.exe" set "FASM=%FASM_HOME%\fasm.exe"
if not exist "%FASM%" where fasm.exe >nul 2>nul && set "FASM=fasm.exe"

if not exist "%FASM%" (
  color 0C
  echo [ERROR] FASM was not found.
  echo Put the official Windows fasm.exe in tools\fasm.exe,
  echo set FASM_HOME, or add FASM to PATH.
  echo Official download: https://flatassembler.net/download.php
  echo.
  pause
  exit /b 2
)

if not exist build mkdir build
echo [1/2] Assembling src\main.asm ...
"%FASM%" src\main.asm build\KOLITTS
if errorlevel 1 (
  color 0C
  echo [ERROR] Assembly failed.
  pause
  exit /b 1
)

echo [2/2] Copying example text ...
copy /y examples\beispiel_de.txt build\beispiel_de.txt >nul
copy /y examples\example_en.txt build\example_en.txt >nul
color 0A
echo.
echo [SUCCESS] build\KOLITTS was created.
echo Copy KOLITTS and the TXT files to a KolibriOS-accessible drive.
echo.
pause
exit /b 0

@echo off
setlocal EnableExtensions
cd /d "%~dp0"
color 0E
title KolibriTTS for Windows v0.5 - FASM Build
echo ============================================================
echo   KolibriTTS for Windows v0.5 - Native Win32 FASM Build
echo ============================================================
echo.
set "FASM=tools\fasm.exe"
if not exist "%FASM%" if exist "%FASM_HOME%\fasm.exe" set "FASM=%FASM_HOME%\fasm.exe"
if not exist "%FASM%" where fasm.exe >nul 2>nul && set "FASM=fasm.exe"
if not exist "%FASM%" (
  color 0C
  echo [ERROR] FASM was not found.
  echo Put fasm.exe in tools\fasm.exe, set FASM_HOME, or add it to PATH.
  pause
  exit /b 2
)
if not exist build mkdir build
echo [1/2] Assembling the native Windows application...
"%FASM%" src\windows_tts.asm build\KolibriTTS.exe
if errorlevel 1 (
  color 0C
  echo [ERROR] Assembly failed.
  pause
  exit /b 1
)
echo [2/2] Copying example text files...
copy /y examples\example_de.txt build\example_de.txt >nul
copy /y examples\example_en.txt build\example_en.txt >nul
color 0A
echo.
echo [SUCCESS] build\KolibriTTS.exe was created.
pause

@echo off
rem Use Git Bash explicitly. On Windows, plain "bash" can resolve to the WSL
rem launcher at C:\Windows\System32\bash.exe, which does not understand
rem Windows-style paths like D:\3D\... and would silently report every
rem listed folder as missing.
cd /d "%~dp0"

set "GITBASH="
if exist "%ProgramFiles%\Git\bin\bash.exe"      set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined GITBASH if exist "%ProgramFiles%\Git\usr\bin\bash.exe"  set "GITBASH=%ProgramFiles%\Git\usr\bin\bash.exe"
if not defined GITBASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles(x86)%\Git\bin\bash.exe"

if not defined GITBASH (
  echo refresh.cmd: error: could not find Git Bash. Install Git for Windows or
  echo edit this script to point GITBASH at your bash.exe.
  pause
  exit /b 1
)

"%GITBASH%" refresh.sh
pause

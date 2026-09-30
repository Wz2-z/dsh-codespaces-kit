@echo off
rem Thin launcher for the (bilingual) control panel.
rem Looks for console.ps1 next to itself, then dsh-console.ps1 (older name), and says so if neither exists.
chcp 65001 >nul
setlocal
set "HERE=%~dp0"
set "PS1="
if exist "%HERE%console.ps1" set "PS1=%HERE%console.ps1"
if not defined PS1 if exist "%HERE%dsh-console.ps1" set "PS1=%HERE%dsh-console.ps1"
if not defined PS1 (
  echo.
  echo Could not find console.ps1 or dsh-console.ps1 next to this launcher:
  echo   %HERE%
  echo.
  echo Copy console.ps1 from the kit's install\ folder next to this file.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo console exited with code %RC%
  pause
)
endlocal

@echo off
rem Thin launcher for the (bilingual) control panel. The real thing is console.ps1.
chcp 65001 >nul
setlocal
set "HERE=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%console.ps1" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo console exited with code %RC%
  pause
)
endlocal

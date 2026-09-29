@echo off
rem dsh-codespaces <command> -- Windows entry point
setlocal
chcp 65001 >nul
set "HERE=%~dp0"
set "CMD=%~1"

if /i "%CMD%"=="doctor" (
  shift
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%doctor.ps1" %1 %2 %3 %4 %5
  exit /b %ERRORLEVEL%
)
if /i "%CMD%"=="setup" (
  shift
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%setup.ps1" %1 %2 %3 %4 %5
  exit /b %ERRORLEVEL%
)
if /i "%CMD%"=="help" goto HELP
if "%CMD%"=="" goto HELP
echo Unknown command: %CMD%

:HELP
echo.
echo   dsh-codespaces doctor     check GitHub CLI / Codespace / DSH / SSH / tunnel / sync ...
echo   dsh-codespaces setup      install or repair everything
echo.
echo   Examples:
echo     dsh-codespaces doctor
echo     dsh-codespaces doctor -NoTunnel
echo     dsh-codespaces setup -Repo your-name/your-repo
echo.
exit /b 1

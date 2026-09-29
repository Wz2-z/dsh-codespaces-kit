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
if /i "%CMD%"=="status" (
  shift
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%status.ps1" %1 %2 %3 %4 %5
  exit /b %ERRORLEVEL%
)
if /i "%CMD%"=="audit" (
  shift
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%audit.ps1" %1 %2 %3 %4 %5
  exit /b %ERRORLEVEL%
)
if /i "%CMD%"=="setup" (
  shift
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%setup.ps1" %1 %2 %3 %4 %5
  exit /b %ERRORLEVEL%
)
if /i "%CMD%"=="repair" (
  shift
  echo [repair] re-running setup (idempotent), then doctor ...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%setup.ps1" %1 %2 %3 %4 %5
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%doctor.ps1" %1 %2 %3 %4 %5
  exit /b %ERRORLEVEL%
)
if /i "%CMD%"=="update" (
  shift
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%update.ps1" %1 %2 %3 %4 %5
  exit /b %ERRORLEVEL%
)
if /i "%CMD%"=="uninstall" (
  shift
  powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%uninstall.ps1" %1 %2 %3 %4 %5
  exit /b %ERRORLEVEL%
)
if /i "%CMD%"=="help" goto HELP
if "%CMD%"=="" goto HELP
echo Unknown command: %CMD%

:HELP
echo.
echo   dsh-codespaces status     one screen: codespace / tunnel / dsh / sync / last push / pending
echo   dsh-codespaces doctor     check GitHub CLI / Codespace / DSH / SSH / tunnel / sync ... (12 items)
echo   dsh-codespaces audit      what keys / tokens / configs exist, what each can do
echo   dsh-codespaces setup      install everything (first time)
echo   dsh-codespaces repair     re-run setup (idempotent) then doctor
echo   dsh-codespaces update     upgrade dsh in the cloud and reopen the tunnel
echo   dsh-codespaces uninstall  preview removal; add -Yes and scope flags to actually do it
echo.
echo   Examples:
echo     dsh-codespaces status
echo     dsh-codespaces doctor
echo     dsh-codespaces doctor -NoTunnel
echo     dsh-codespaces audit
echo     dsh-codespaces setup -Repo your-name/your-repo
echo     dsh-codespaces uninstall
echo     dsh-codespaces uninstall -Yes -Local -Cloud
echo.
exit /b 1

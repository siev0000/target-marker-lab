@echo off
setlocal

set "ROOT=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\sync-from-game.ps1"

if errorlevel 1 (
  echo.
  echo Sync failed.
  pause
  exit /b 1
)

echo.
echo Sync complete. Run npm run build to verify.
pause

@echo off
title FAST Hostel System - Starting...
color 1F

:: ── Delete old batch files ───────────────────────────────────────────────────
if exist "%~dp0run_in_browser.bat"  del /f /q "%~dp0run_in_browser.bat"
if exist "%~dp0start_hostel.bat"    del /f /q "%~dp0start_hostel.bat"

:: ── Kill anything on port 8080 ────────────────────────────────────────────────
echo [1/3] Freeing port 8080...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":8080 "') do (
    taskkill /PID %%a /F >nul 2>&1
)
timeout /t 1 /nobreak >nul

:: ── Start Flutter web server in background ───────────────────────────────────
echo [2/3] Starting FAST Hostel web server...
cd /d "%~dp0"
start "" /min cmd /c "flutter run -d web-server --web-port 8080 --release 2>&1 | findstr /v \"Downloading\""

:: ── Wait for server to be ready then open browser ────────────────────────────
echo [3/3] Waiting for server to be ready...
:WAIT_LOOP
timeout /t 3 /nobreak >nul
curl -s -o nul -w "%%{http_code}" http://localhost:8080 2>nul | findstr "200" >nul
if errorlevel 1 (
    echo     Still starting...
    goto WAIT_LOOP
)

echo.
echo  ============================================
echo   FAST Hostel System is READY!
echo   Opening landing page at http://localhost:8080/#/
echo  ============================================
echo.
start "" "http://localhost:8080/#/"

:: Keep window open so server stays alive
echo  [Server is running. Close this window to stop.]
echo.
pause >nul

@echo off
title Music Widget Server
color 0A
echo.
echo  Music Widget Server
echo  ===================
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo  ERROR: Node.js not found.
  echo  Download from https://nodejs.org and install, then run this again.
  echo.
  pause
  exit /b 1
)

cd /d "%~dp0server"

if not exist node_modules (
  echo  Installing dependencies...
  echo.
  npm install
  echo.
)

echo  OBS Browser Source URLs:
echo.
echo    Small   400x80    http://localhost:8888/widget.html?size=sm
echo    Medium  420x140   http://localhost:8888/widget.html?size=md
echo    Large   520x180   http://localhost:8888/widget.html?size=lg
echo.
echo  In OBS: Add Source - Browser - paste a URL above
echo  Set Custom Width/Height to match the size you chose.
echo.
echo  Press Ctrl+C to stop the server.
echo.

node server.js
pause

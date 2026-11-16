@echo off
title NightMarket local server
cd /d "%~dp0"
set PORT=8765

set PY=
where py >nul 2>nul && set PY=py
if not defined PY where python >nul 2>nul && set PY=python
if not defined PY goto nopy

echo NightMarket is running at: http://localhost:%PORT%/
echo Make sure your Google API key website restriction includes: http://localhost:%PORT%/*
echo This window closes automatically after you close the web page.
echo.
start "" "http://localhost:%PORT%/index.html"
%PY% server.py %PORT%
exit /b 0

:nopy
echo Python 3 was not found. Please install it from https://www.python.org/downloads/
pause
exit /b 1

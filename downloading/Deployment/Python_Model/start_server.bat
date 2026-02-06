@echo off
cd /d "%~dp0"
echo Starting Local PHP Server on http://localhost:8000...
echo Press Ctrl+C to stop.
php -S 0.0.0.0:8000 -t .
pause

@echo off
cd /d "%~dp0"

echo ------------------------------------------------ >> training.log
echo Starting Training at %date% %time% >> training.log

:: Check if python is available
where python >nul 2>nul
if %errorlevel%==0 (
    python server_train.py >> training.log 2>&1
) else (
    echo Python not found! Please install Python and add it to PATH. >> training.log
)

echo Training finished. >> training.log
echo ------------------------------------------------ >> training.log

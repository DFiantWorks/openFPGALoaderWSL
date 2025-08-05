@echo off
setlocal enabledelayedexpansion

echo ========================================
echo openFPGALoader Windows/WSL Wrapper Setup
echo ========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] This script is not running as administrator.
    echo Some operations may require elevated privileges.
    echo.
)

REM Get WSL username
echo [INFO] Detecting WSL username...
for /f "tokens=*" %%i in ('wsl whoami') do set WSL_USERNAME=%%i
echo Found WSL username: %WSL_USERNAME%

REM Get WSL home directory
echo [INFO] Detecting WSL home directory...
for /f "tokens=*" %%i in ('wsl echo $HOME') do set WSL_HOME=%%i
echo Found WSL home: %WSL_HOME%

REM Copy WSL script
echo [INFO] Copying WSL script to %WSL_HOME%/openFPGALoader.sh...
copy "openFPGALoader.sh" "%WSL_HOME%\openFPGALoader.sh" >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] WSL script copied successfully.
) else (
    echo [ERROR] Failed to copy WSL script.
    echo Please manually copy openFPGALoader.sh to your WSL home directory.
)

REM Make WSL script executable
echo [INFO] Making WSL script executable...
wsl chmod +x ~/openFPGALoader.sh
if %errorlevel% equ 0 (
    echo [SUCCESS] WSL script is now executable.
) else (
    echo [WARNING] Failed to make WSL script executable.
    echo Please run 'chmod +x ~/openFPGALoader.sh' in WSL manually.
)

REM Copy Windows scripts to a convenient location
echo [INFO] Copying Windows scripts...
if not exist "%USERPROFILE%\bin" mkdir "%USERPROFILE%\bin"
copy "openFPGALoader.bat" "%USERPROFILE%\bin\openFPGALoader.bat" >nul 2>&1
copy "openFPGALoader.ps1" "%USERPROFILE%\bin\openFPGALoader.ps1" >nul 2>&1

if %errorlevel% equ 0 (
    echo [SUCCESS] Windows scripts copied to %USERPROFILE%\bin\
    echo.
    echo [INFO] To use the scripts from anywhere, add %USERPROFILE%\bin\ to your PATH:
    echo setx PATH "%PATH%;%USERPROFILE%\bin"
) else (
    echo [ERROR] Failed to copy Windows scripts.
)

echo.
echo ========================================
echo Installation Summary
echo ========================================
echo.
echo [INFO] Prerequisites to install manually:
echo   1. usbipd-win on Windows:
echo      winget install --interactive --exact dorssel.usbipd-win
echo.
echo   2. openFPGALoader in WSL:
echo      sudo apt update ^&^& sudo apt install openfpgaloader
echo.
echo [INFO] Usage examples:
echo   openFPGALoader.bat -b arty-a7-35t C:\path\to\bitstream.bit
echo   openFPGALoader.ps1 -b arty-a7-35t C:\path\to\bitstream.bit
echo.
echo [INFO] For more information, see README.md
echo.
echo Installation complete!
pause 
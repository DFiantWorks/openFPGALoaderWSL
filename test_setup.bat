@echo off
setlocal enabledelayedexpansion

echo ========================================
echo openFPGALoader Wrapper Setup Test
echo ========================================
echo.

set "all_tests_passed=true"

REM Test 1: Check if WSL is available
echo [TEST 1] Checking WSL availability...
wsl --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [PASS] WSL is available
) else (
    echo [FAIL] WSL is not available or not properly installed
    set "all_tests_passed=false"
)

REM Test 2: Check if usbipd is available on Windows
echo [TEST 2] Checking usbipd availability on Windows...
usbipd --version >nul 2>&1
if %errorlevel% equ 0 (
    echo [PASS] usbipd is available on Windows
) else (
    echo [FAIL] usbipd is not available on Windows
    echo [INFO] Install with: winget install --interactive --exact dorssel.usbipd-win
    set "all_tests_passed=false"
)

REM Test 3: Check if WSL script exists
echo [TEST 3] Checking WSL script availability...
wsl test -f ~/openFPGALoader.sh
if %errorlevel% equ 0 (
    echo [PASS] WSL script exists
) else (
    echo [FAIL] WSL script not found in WSL home directory
    echo [INFO] Copy openFPGALoader.sh to your WSL home directory
    set "all_tests_passed=false"
)

REM Test 4: Check if WSL script is executable
echo [TEST 4] Checking WSL script permissions...
wsl test -x ~/openFPGALoader.sh
if %errorlevel% equ 0 (
    echo [PASS] WSL script is executable
) else (
    echo [FAIL] WSL script is not executable
    echo [INFO] Run: wsl chmod +x ~/openFPGALoader.sh
    set "all_tests_passed=false"
)

REM Test 5: Check if openFPGALoader is available in WSL
echo [TEST 5] Checking openFPGALoader availability in WSL...
wsl which openFPGALoader >nul 2>&1
if %errorlevel% equ 0 (
    echo [PASS] openFPGALoader is available in WSL
) else (
    echo [FAIL] openFPGALoader is not available in WSL
    echo [INFO] Install with: wsl sudo apt update && wsl sudo apt install openfpgaloader
    set "all_tests_passed=false"
)

REM Test 6: Check if lsusb is available in WSL
echo [TEST 6] Checking lsusb availability in WSL...
wsl which lsusb >nul 2>&1
if %errorlevel% equ 0 (
    echo [PASS] lsusb is available in WSL
) else (
    echo [FAIL] lsusb is not available in WSL
    echo [INFO] Install with: wsl sudo apt install usbutils
    set "all_tests_passed=false"
)

REM Test 7: Check USB device detection
echo [TEST 7] Checking USB device detection...
for /f "tokens=*" %%i in ('powershell.exe -Command "usbipd list" 2^>nul') do (
    echo %%i | findstr "Digilent" >nul
    if !errorlevel! equ 0 (
        echo [PASS] Digilent USB device detected
        goto :device_found
    )
)
echo [FAIL] No Digilent USB device detected
echo [INFO] Make sure your Digilent device is connected
set "all_tests_passed=false"
:device_found

REM Test 8: Check Windows script availability
echo [TEST 8] Checking Windows script availability...
if exist "openFPGALoader.bat" (
    echo [PASS] Windows batch script found
) else (
    echo [FAIL] Windows batch script not found
    set "all_tests_passed=false"
)

if exist "openFPGALoader.ps1" (
    echo [PASS] Windows PowerShell script found
) else (
    echo [FAIL] Windows PowerShell script not found
    set "all_tests_passed=false"
)

echo.
echo ========================================
echo Test Results
echo ========================================
echo.

if "%all_tests_passed%"=="true" (
    echo [SUCCESS] All tests passed! Your setup is ready.
    echo.
    echo [INFO] You can now use:
    echo   openFPGALoader.bat -b arty-a7-35t C:\path\to\bitstream.bit
    echo   openFPGALoader.ps1 -b arty-a7-35t C:\path\to\bitstream.bit
) else (
    echo [WARNING] Some tests failed. Please fix the issues above before using the wrapper.
    echo.
    echo [INFO] Run install.bat to set up the wrapper scripts.
)

echo.
echo Test completed.
pause 
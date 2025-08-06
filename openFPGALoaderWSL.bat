@echo off
setlocal enabledelayedexpansion

REM Windows wrapper for openFPGALoader running in WSL2
REM This script converts Windows file paths to WSL paths and calls the WSL script

REM Check if arguments are provided
if "%~1"=="" (
    echo Usage: openFPGALoader.bat [openFPGALoader arguments...]
    echo Example: openFPGALoader.bat -b arty-a7-35t my_bitstream.bit
    exit /b 1
)

REM Get the current Windows directory
for /f "tokens=*" %%d in ('cd') do set "current_dir=%%d"

REM Get the batch file's directory and convert to WSL path using wslpath
for /f "tokens=*" %%p in ('wsl -e wslpath "%~dp0"') do set "batch_dir=%%p"
set "batch_dir=!batch_dir:"=!"
REM Remove trailing slash from batch_dir if it exists
if "!batch_dir:~-1!"=="/" set "batch_dir=!batch_dir:~0,-1!"

REM Build the argument string, converting the last argument (file path) to WSL format
set "args="
set "last_arg="
set "arg_count=0"

REM Count arguments first
for %%a in (%*) do set /a arg_count+=1

REM Process all arguments
set "current_arg=0"
for %%a in (%*) do (
    set /a current_arg+=1
    
    REM If this is the last argument, check if it looks like a file path
    if !current_arg! equ !arg_count! (
        set "last_arg=%%a"
        
        REM Check if the last argument looks like a file path
        REM Look for drive letter (C:, D:, etc.), path separators, or file extensions
        set "is_file_path=false"
        
        REM Check for drive letter pattern (X:)
        echo !last_arg! | findstr /r "^[A-Za-z]:" >nul
        if !errorlevel! equ 0 set "is_file_path=true"
        
        REM Check for path separators (backslashes or forward slashes)
        echo !last_arg! | findstr /r "[\\/]" >nul
        if !errorlevel! equ 0 set "is_file_path=true"
        
        REM Check for file extensions (common FPGA file extensions) - this catches filenames like "foo.bit"
        REM Use string manipulation to check if argument ends with file extension
        set "ext_check=!last_arg!"
        if "!ext_check:~-4!"==".bit" set "is_file_path=true"
        if "!ext_check:~-4!"==".bin" set "is_file_path=true"
        if "!ext_check:~-4!"==".hex" set "is_file_path=true"
        if "!ext_check:~-4!"==".svf" set "is_file_path=true"
        if "!ext_check:~-4!"==".jed" set "is_file_path=true"
        if "!ext_check:~-4!"==".isc" set "is_file_path=true"
        if "!ext_check:~-4!"==".mcs" set "is_file_path=true"
        if "!ext_check:~-4!"==".rpd" set "is_file_path=true"
        if "!ext_check:~-4!"==".rbf" set "is_file_path=true"
        if "!ext_check:~-4!"==".sof" set "is_file_path=true"
        if "!ext_check:~-4!"==".pof" set "is_file_path=true"
        
        REM Check for relative paths starting with . or .. (e.g., ./foo.bit, ../design.bit)
        echo !last_arg! | findstr /r "^\.\.?[\\/]" >nul
        if !errorlevel! equ 0 set "is_file_path=true"
        
        REM If it looks like a file path, convert it to WSL format
        if "!is_file_path!"=="true" (
            REM Check if it's a drive letter path (absolute Windows path)
            echo !last_arg! | findstr /r "^[A-Za-z]:" >nul
            if !errorlevel! equ 0 (
                REM Convert Windows absolute path to WSL path using wslpath
                for /f "tokens=*" %%p in ('wsl -e wslpath "!last_arg!"') do set "last_arg=%%p"
                set "last_arg=!last_arg:"=!"
            ) else (
                REM For relative paths or just filenames, convert to absolute WSL path
                REM Convert backslashes to forward slashes in the filename
                set "last_arg=!last_arg:\=/!"
                
                REM Combine current WSL directory with the filename
                REM Convert current_dir to WSL format using wslpath
                for /f "tokens=*" %%p in ('wsl -e wslpath "!current_dir!"') do set "current_dir_wsl=%%p"
                set "current_dir_wsl=!current_dir_wsl:"=!"
                
                set "last_arg=!current_dir_wsl!/!last_arg!"
            )
        )
    ) else (
        REM Keep other arguments as-is
        if defined args (
            set "args=!args! %%a"
        ) else (
            set "args=%%a"
        )
    )
)

REM Combine all arguments with the converted last argument
if defined args (
    set "final_args=!args! !last_arg!"
) else (
    set "final_args=!last_arg!"
)

REM Call the WSL script with the converted arguments
@REM if "!is_file_path!"=="true" (
@REM     echo Converting Windows path to WSL path...
@REM     echo Original last argument: %last_arg%
@REM     echo Converted last argument: !last_arg!
@REM ) else (
@REM     echo Last argument does not appear to be a file path, passing as-is...
@REM     echo Last argument: !last_arg!
@REM )
echo.

REM Use wsl --cd to set the working directory and run the script from the batch file's location
wsl --cd "!current_dir!" -d Ubuntu -e bash -c "!batch_dir!/openFPGALoader.sh !final_args!"

REM Check the exit code from WSL
@REM if %errorlevel% neq 0 (
@REM     echo Error: openFPGALoader failed with exit code %errorlevel%
@REM     exit /b %errorlevel%
@REM )

@REM echo openFPGALoader completed successfully. 
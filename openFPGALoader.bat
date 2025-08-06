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
                REM Convert Windows absolute path to WSL path
                set "last_arg=!last_arg:\=/!"
                set "last_arg=!last_arg:C:=/mnt/c!"
                set "last_arg=!last_arg:D:=/mnt/d!"
                set "last_arg=!last_arg:E:=/mnt/e!"
                set "last_arg=!last_arg:F:=/mnt/f!"
                set "last_arg=!last_arg:G:=/mnt/g!"
                set "last_arg=!last_arg:H:=/mnt/h!"
                set "last_arg=!last_arg:I:=/mnt/i!"
                set "last_arg=!last_arg:J:=/mnt/j!"
                set "last_arg=!last_arg:K:=/mnt/k!"
                set "last_arg=!last_arg:L:=/mnt/l!"
                set "last_arg=!last_arg:M:=/mnt/m!"
                set "last_arg=!last_arg:N:=/mnt/n!"
                set "last_arg=!last_arg:O:=/mnt/o!"
                set "last_arg=!last_arg:P:=/mnt/p!"
                set "last_arg=!last_arg:Q:=/mnt/q!"
                set "last_arg=!last_arg:R:=/mnt/r!"
                set "last_arg=!last_arg:S:=/mnt/s!"
                set "last_arg=!last_arg:T:=/mnt/t!"
                set "last_arg=!last_arg:U:=/mnt/u!"
                set "last_arg=!last_arg:V:=/mnt/v!"
                set "last_arg=!last_arg:W:=/mnt/w!"
                set "last_arg=!last_arg:X:=/mnt/x!"
                set "last_arg=!last_arg:Y:=/mnt/y!"
                set "last_arg=!last_arg:Z:=/mnt/z!"
            ) else (
                REM For relative paths or just filenames, convert to absolute WSL path
                REM Get current Windows directory and convert to WSL path
                for /f "tokens=*" %%d in ('cd') do set "current_dir=%%d"
                set "current_dir=!current_dir:\=/!"
                set "current_dir=!current_dir:C:=/mnt/c!"
                set "current_dir=!current_dir:D:=/mnt/d!"
                set "current_dir=!current_dir:E:=/mnt/e!"
                set "current_dir=!current_dir:F:=/mnt/f!"
                set "current_dir=!current_dir:G:=/mnt/g!"
                set "current_dir=!current_dir:H:=/mnt/h!"
                set "current_dir=!current_dir:I:=/mnt/i!"
                set "current_dir=!current_dir:J:=/mnt/j!"
                set "current_dir=!current_dir:K:=/mnt/k!"
                set "current_dir=!current_dir:L:=/mnt/l!"
                set "current_dir=!current_dir:M:=/mnt/m!"
                set "current_dir=!current_dir:N:=/mnt/n!"
                set "current_dir=!current_dir:O:=/mnt/o!"
                set "current_dir=!current_dir:P:=/mnt/p!"
                set "current_dir=!current_dir:Q:=/mnt/q!"
                set "current_dir=!current_dir:R:=/mnt/r!"
                set "current_dir=!current_dir:S:=/mnt/s!"
                set "current_dir=!current_dir:T:=/mnt/t!"
                set "current_dir=!current_dir:U:=/mnt/u!"
                set "current_dir=!current_dir:V:=/mnt/v!"
                set "current_dir=!current_dir:W:=/mnt/w!"
                set "current_dir=!current_dir:X:=/mnt/x!"
                set "current_dir=!current_dir:Y:=/mnt/y!"
                set "current_dir=!current_dir:Z:=/mnt/z!"
                
                REM Convert backslashes to forward slashes in the filename
                set "last_arg=!last_arg:\=/!"
                
                REM Combine current WSL directory with the filename
                set "last_arg=!current_dir!/!last_arg!"
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

wsl ~/openFPGALoaderWin/openFPGALoader.sh !final_args!

REM Check the exit code from WSL
@REM if %errorlevel% neq 0 (
@REM     echo Error: openFPGALoader failed with exit code %errorlevel%
@REM     exit /b %errorlevel%
@REM )

@REM echo openFPGALoader completed successfully. 
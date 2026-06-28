@echo off
setlocal enabledelayedexpansion

echo Received: %* > params.log

set OUT_OBJ=
set ARGS_FILE=gcc_args.txt
set SKIP=0
set INPUT_RC=

> "%ARGS_FILE%" echo.

:parse
if "%~1"=="" goto end

if "%SKIP%"=="1" (
    set SKIP=0
    shift
    goto parse
)

echo Processing: "%~1" >> params.log

:: Handle /fo
if /i "%~1"=="/fo" (
    set OUT_OBJ=%~2
    set SKIP=1
    shift
    goto parse
)

:: Ignore --preprocessor itself and its value
if /i "%~1"=="--preprocessor" (
    set SKIP=1
    shift
    goto parse
)

:: Handle --preprocessor-arg with merge for split -D macros
if /i "%~1"=="--preprocessor-arg" (
    set "pre_val=%~2"
    if defined pre_val (
        if /i "!pre_val:~0,2!"=="-D" (
            echo !pre_val! | find "=" >nul
            if errorlevel 1 (
                if not "%~3"=="" (
                    set "next_val=%~3"
                    if "!next_val:~0,1!" NEQ "-" (
                        set "pre_val=!pre_val!=!next_val!"
                        set SKIP=1
                        echo Merged: "!pre_val!" >> params.log
                    )
                )
            )
        )
        echo "!pre_val!" >> "%ARGS_FILE%"
        echo Wrote preprocessor arg: "!pre_val!" >> params.log
    )
    shift
    shift
    goto parse
)

:: Combined --preprocessor-arg=...
set "arg=%~1"
if not "!arg:--preprocessor-arg=!"=="!arg!" (
    set "val=!arg:*--preprocessor-arg=!"
    if "!val:~0,1!"=="=" set "val=!val:~1!"
    echo "!val!" >> "%ARGS_FILE%"
    echo Combined form: wrote "!val!" >> params.log
    shift
    goto parse
)

:: Record the .rc file (last non-option argument)
if "!arg:~0,1!" NEQ "-" if "!arg:~0,1!" NEQ "/" (
    set "INPUT_RC=!arg!"
)

:: General arguments (including -D, -I, etc.)
set "next="
if not "%~2"=="" set "next=%~2"
set "merged=!arg!"

:: Merge split -D
if /i "!arg:~0,2!"=="-D" (
    echo !arg! | find "=" >nul
    if errorlevel 1 (
        if not "!next!"=="" (
            if "!next:~0,1!" NEQ "-" (
                set "merged=!arg!=!next!"
                set SKIP=1
                echo Merged: "!merged!" >> params.log
            )
        )
    )
)

echo "!merged!" >> "%ARGS_FILE%"
shift
goto parse

:end
if "%OUT_OBJ%"=="" (
    echo Error: /fo not found.
    exit /b 1
)

:: Convert OUT_OBJ to absolute path
if not "%OUT_OBJ:~1,1%"==":" set "OUT_OBJ=%CD%\%OUT_OBJ%"

:: Show response file content
echo Response file content: >> params.log
type "%ARGS_FILE%" >> params.log

:: Preprocess
gcc -E -xc -DRC_INVOKED @"%ARGS_FILE%" > pre.rc
if errorlevel 1 (
    echo Preprocessing failed.
    exit /b %errorlevel%
)

:: Copy pre.rc to .rc file's directory and change there
if defined INPUT_RC (
    for %%F in ("%INPUT_RC%") do set "RC_DIR=%%~dpF"
    if exist "!RC_DIR!\" (
        copy /y pre.rc "!RC_DIR!\pre.rc" >nul
        cd /d "!RC_DIR!"
    )
)

:: Compile with windres (relative pre.rc, absolute OUT_OBJ)
"D:\Program Files\msys64\ucrt64\bin\windres.exe" -O coff pre.rc "%OUT_OBJ%"
if errorlevel 1 (
    echo windres failed.
    exit /b %errorlevel%
)

:: Clean up temporary files in RC_DIR
if defined RC_DIR del "!RC_DIR!\pre.rc" 2>nul
del "%ARGS_FILE%" 2>nul

endlocal
@echo off
setlocal enabledelayedexpansion

set OUT=WirtsTools.lua
set BASE=Base.lua
set FEATURES_DIR=Features
set VERSION_FILE=VERSION

REM Delete output file if it exists to avoid appending
if exist %OUT% del %OUT%

REM Read version from VERSION file
set /p VERSION=<%VERSION_FILE%

REM Write header to OUT
echo --------------------------------------------------------------------- >> %OUT%
echo --WirtsTools.lua >> %OUT%
echo --version %VERSION% >> %OUT%
echo --Required Notice: Copyright WirtsLegs 2024, (https://github.com/WirtsLegs/WirtsTools) >> %OUT%
echo --Directions: load this script as Do Script File, then call setup functions in a do script action for the features you wish to use >> %OUT%
echo --See readme for full details >> %OUT%
echo --------------------------------------------------------------------- >> %OUT%

REM Add Base.lua (skip first 3 lines entirely)
set header_lines=0
for /f "usebackq delims=" %%l in ("%BASE%") do (
    set /a header_lines+=1
    if !header_lines! gtr 3 (
        echo %%l >> %OUT%
    )
)

REM Add features
for %%f in (%FEATURES_DIR%\*.lua) do (
    echo( >> %OUT%
    echo( >> %OUT%
    setlocal enabledelayedexpansion
    set header_lines=0
    for /f "usebackq delims=" %%l in ("%%f") do (
        set "line=%%l"
        if !header_lines! lss 3 (
            echo !line! | findstr /c:"Copyright WirtsLegs" >nul
            if !errorlevel! == 0 (
                REM skip copyright notice
            ) else (
                if !header_lines! == 0 (
                    set "line=!line:.lua=!"
                )
                echo !line! >> %OUT%
            )
            set /a header_lines+=1
        ) else (
            echo !line! >> %OUT%
        )
    )
    endlocal
)

echo Build complete: %OUT%
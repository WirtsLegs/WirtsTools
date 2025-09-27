@echo off
setlocal enabledelayedexpansion

set OUT=WirtsTools.lua
set BASE=Base.lua
set FEATURES_DIR=Features

copy /b %BASE% %OUT%
for %%f in (%FEATURES_DIR%\*.lua) do (
    type "%%f" >> %OUT%
)

echo Build complete: %OUT%
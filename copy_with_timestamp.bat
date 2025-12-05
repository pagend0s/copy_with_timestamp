@echo off

GOTO PowerShell

:PowerShell
pushd %~dp0
echo.
CLS
powershell -ExecutionPolicy Bypass -File .\Resources\copy_with_date_stamp.ps1 -UseGui

pause

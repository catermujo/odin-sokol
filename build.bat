@echo off

setlocal

if /I "%~1"=="shared" shift
if /I "%~1"=="static" shift
if /I "%~1"=="all" shift

call "%~dp0build_windows.cmd" %*
exit /b %errorlevel%

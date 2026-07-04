@echo off

setlocal

call "%~dp0build_windows.cmd" static %*
exit /b %errorlevel%

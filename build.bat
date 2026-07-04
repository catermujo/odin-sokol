@echo off

setlocal

call "%~dp0build_windows.cmd" shared %*
exit /b %errorlevel%

@echo off
rem Ponto de entrada para Windows (cmd ou PowerShell): bootstrap.cmd [alvo]
rem Contorna a politica de execucao de scripts do PowerShell.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
exit /b %ERRORLEVEL%

@echo off
cd /d %TEMP%
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -NoProfile -NoExit -File ""\\nas3\Client-Certificates\AutoConfig\Config Scripts\Start-CloudDomainConfig.ps1""' -Verb RunAs"
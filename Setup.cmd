@echo off
rem Double-click to set up this laptop. Asks for admin once. Opens in Windows Terminal when there is one.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$a = '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0setup.ps1\"'; if (Get-Command wt.exe -ErrorAction SilentlyContinue) { Start-Process wt.exe -Verb RunAs -ArgumentList \"powershell.exe $a\" } else { Start-Process powershell.exe -Verb RunAs -ArgumentList $a }"

@echo off
powershell -NoLogo -ExecutionPolicy Bypass -Command "iex (irm functions.osdcloud.com); Invoke-OSDCloud -Phase OOBE"
exit /b 0


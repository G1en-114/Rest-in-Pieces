@echo off
rem Startup task (schtasks /sc onstart, SYSTEM): restart the relay 3 s after it exits
cd /d C:\tomb
:loop
C:\tomb\python\python.exe -u C:\tomb\relay.py >> C:\tomb\relay.log 2>&1
ping -n 4 127.0.0.1 >nul
goto loop

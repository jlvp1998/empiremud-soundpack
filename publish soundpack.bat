@echo off
rem Sends your soundpack changes to GitHub. Players get them the next time
rem they open the soundpack. Put this file in the soundpack folder (the one
rem with MUSHclient.exe that came from git), or leave it in the owner's
rem soundpack-release folder.
setlocal enabledelayedexpansion
cd /d "%~dp0"
if not exist ".git\HEAD" cd /d "C:\Users\Owner\Documents\empire_mud_soundpack" 2>nul
if not exist ".git\HEAD" (
	echo This isn't a soundpack folder from git. Move this file next to MUSHclient.exe.
	pause
	exit /b
)
set GIT=git
where git >nul 2>nul || for /d %%d in ("%LOCALAPPDATA%\GitHubDesktop\app-*") do if exist "%%d\resources\app\git\cmd\git.exe" set GIT="%%d\resources\app\git\cmd\git.exe"
%GIT% --version >nul 2>nul || (
	echo Couldn't find git. Install GitHub Desktop or Git for Windows first.
	pause
	exit /b
)
rem show what will be sent, so nothing goes out by mistake
%GIT% add -A
%GIT% fetch -q origin main
%GIT% diff --cached --quiet || goto ask
rem nothing new, but changes already committed with git may still be waiting
set AHEAD=0
for /f %%n in ('%GIT% rev-list --count origin/main..HEAD') do set AHEAD=%%n
if "%AHEAD%"=="0" (
	echo You haven't changed anything, so there is nothing to send.
	pause
	exit /b
)
echo You already committed these files with git, but they haven't been sent yet:
%GIT% diff --name-only origin/main...HEAD
echo.
set /p "OK=Press Enter to send them, or close this window to stop. "
goto send

:ask
echo These files will be sent to every player:
%GIT% diff --cached --name-only
echo.
rem players hear this when the soundpack updates
set "MSG="
set /p "MSG=What did you change? Players hear this when they update. Or close this window to stop. "
if not defined MSG set "MSG=Soundpack update"
>"%TEMP%\soundpack-change.txt" echo(!MSG!
%GIT% commit -q -F "%TEMP%\soundpack-change.txt"
del "%TEMP%\soundpack-change.txt"

:send
echo Getting any changes other people made...
%GIT% pull -q --no-edit origin main
if errorlevel 1 (
	echo Your changes and someone else's changes clash on the same file. Ask the soundpack owner to help.
	pause
	exit /b
)
echo Sending your changes to GitHub...
%GIT% push -q origin main
if errorlevel 1 (
	echo That did NOT work. Check your internet and try again.
) else (
	echo Done. Players get the update the next time they open the soundpack.
)
pause

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
%GIT% diff --cached --quiet && (
	echo You haven't changed anything, so there is nothing to send.
	pause
	exit /b
)
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

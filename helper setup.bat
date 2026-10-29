@echo off
rem For people who help with the soundpack through GitHub. Players don't need this.
rem
rem MUSHclient rewrites its own settings files every time it runs, so git keeps
rem asking you to commit them. Run this once in your copy of the soundpack, and
rem git will leave those files alone. Your own settings stay on your computer.
cd /d "%~dp0"
git update-index --skip-worktree mushclient_prefs.sqlite MUSHclient.ini
for /f "delims=" %%f in ('git ls-files worlds/plugins/state') do git update-index --skip-worktree "%%f"
if errorlevel 1 (
	echo That did NOT work. Make sure this soundpack folder came from GitHub.
) else (
	echo Done. Git will stop asking you to commit MUSHclient's settings files.
)
pause

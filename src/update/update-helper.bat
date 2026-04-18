@echo off
REM Args: %1 = source dir (extracted release root), %2 = target dir (app root), %3 = pid to wait for
setlocal
set "SRC=%~1"
set "DST=%~2"
set "PID=%3"

:wait
tasklist /fi "PID eq %PID%" 2>nul | find "%PID%" >nul
if not errorlevel 1 (
    timeout /t 1 /nobreak >nul
    goto wait
)

REM Mirror new files over existing install (do NOT purge user's config or extras)
robocopy "%SRC%" "%DST%" /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP >nul

start "" "%DST%\App.bat"
exit /b 0

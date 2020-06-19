@echo off
setlocal

echo Current Version:
type vesion.txt & echo. 

SET /P AREYOUSURE=Did you update vesion.txt (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO END

butler push releases/Fugitive_Windows.zip wavesonics/fugitive:windows-release --userversion-file vesion.txt
butler push releases/Fugitive_Linux.zip wavesonics/fugitive:linux-release --userversion-file vesion.txt
butler push releases/Fugitive_OSX.zip wavesonics/fugitive:osx-release --userversion-file vesion.txt

:END
endlocal
#!/bin/bash
# This script exists because it appears that you cannot pass env vars
# to  C:\cygwin\bin\bash.exe from the windows command prompt.
NSIS_BUILD_FOR=mingw32-4.4:qt-4.8
$1 $2 $3 $4

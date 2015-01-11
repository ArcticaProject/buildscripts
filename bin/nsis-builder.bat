D:
if "%1"=="mingw32-4.4" (
	cd D:\Build\GIT\nightly\mingw32-4.4\qt-4.8\x2goclient\
	rem this includes setting PATH=%PATH%;D:\MinGW\libexec\gcc\mingw32\4.4.0\
	call "D:\Qt\4.8.5\bin\qtvars.bat"
)
if "%1"=="mingw32-4.8" (
	cd D:\Build\GIT\nightly\mingw32-4.8\qt-4.8\x2goclient\
	rem this includes setting PATH=%PATH%;D:\i686-4.8.2-release-posix-dwarf-rt_v3-rev3\mingw32\libexec\gcc\i686-w64-mingw32\4.8.2\
	call "D:\Qt\4.8.6\bin\qtvars.bat"
)
set PATH=%PATH%;C:\Program Files (x86)\Git\bin\
set PATH=%PATH%;D:\x2goclient-contrib\upx\3.91_bin\
set PATH=%PATH%;C:\Program Files (x86)\NSIS\Unicode\
rem use msysgit's sed
rem enable debug
if "%3"=="--console" sed -i 's/#CONFIG += console/CONFIG += console/' x2goclient.pro
%COMSPEC% /c config_win.bat || exit /b %errorlevel%
mingw32-make || exit /b %errorlevel%
dir release\x2goclient.exe
cd x2gohelper 
mingw32-make || exit /b %errorlevel%
cd ..
dir release\x2gohelper.exe
rmdir /s /q nsis\x2goclient
cd nsis
mkdir x2goclient
if "%1"=="mingw32-4.4" (
	xcopy /S D:\Build\scripts\current_files\%1\%2\x2goclient x2goclient
)

if "%1"=="mingw32-4.8" (
	call ..\copy-deps-win32.bat
)
copy ..\release\x2goclient.exe x2goclient\
copy ..\release\x2gohelper.exe x2goclient\
upx x2goclient\x2goclient.exe
upx x2goclient\x2gohelper.exe
makensis x2goclient.nsi || exit /b %errorlevel%

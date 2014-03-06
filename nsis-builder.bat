call "D:\Qt\4.8.5\bin\qtvars.bat"
set PATH=%PATH%;D:\MinGW\libexec\gcc\mingw32\4.4.0\
set PATH=%PATH%;C:\Program Files (x86)\Git\bin\
set PATH=%PATH%;D:\x2goclient-contrib\upx\3.91_bin\
set PATH=%PATH%;C:\Program Files (x86)\NSIS\
echo "hello" > D:\test.txt
D:
cd D:\Build\GIT\nightly\x2goclient
rem use msysgit's sed
rem enable debug
if "%1"=="--console" sed -i 's/#CONFIG += console/CONFIG += console/' x2goclient.pro
%COMSPEC% /c config_win.bat
mingw32-make
dir release\x2goclient.exe
cd nsis
mkdir x2goclient
xcopy /S D:\Build\scripts\current_files\x2goclient x2goclient
copy ..\release\x2goclient.exe x2goclient\
upx x2goclient\x2goclient.exe
makensis x2goclient.nsi



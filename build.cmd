@echo off
:: Build APK rilis universal untuk pengujian lokal.
::
:: Gradle di Windows bisa gagal dengan "Unable to establish loopback connection"
:: bila folder TEMP memakai nama pendek 8.3 (contoh: C:\Users\CREATO~1\...).
:: JDK 16+ membuat pipe internal lewat Unix domain socket di folder itu dan
:: connect-nya gagal. Skrip ini mengarahkan tmpdir Java ke path pendek biasa.
setlocal
set "JTMP=C:\Temp\jtmp"
if not exist "%JTMP%" mkdir "%JTMP%"
set "TEMP=%JTMP%"
set "TMP=%JTMP%"
set "JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=%JTMP% -Djdk.net.unixdomain.tmpdir=%JTMP%"
if not defined JAVA_HOME if exist "C:\Program Files\Android\Android Studio\jbr" (
    set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
)
flutter build apk --release %*
endlocal

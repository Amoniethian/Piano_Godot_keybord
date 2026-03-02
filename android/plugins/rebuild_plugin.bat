@echo off
setlocal

echo [1/3] Building GodotMidiUSB plugin...
cd /d "%~dp0..\"

call gradlew.bat :plugins:GodotMidiUSB:assembleRelease
if errorlevel 1 (
    echo.
    echo ERROR: Build failed. Check Android SDK setup.
    echo Make sure ANDROID_HOME or local.properties is configured.
    pause
    exit /b 1
)

echo [2/3] Copying AAR to plugins directory...
copy /Y "plugins\GodotMidiUSB\build\outputs\aar\GodotMidiUSB-release.aar" "plugins\GodotMidiUSB-release.aar"
if errorlevel 1 (
    echo ERROR: Copy failed.
    pause
    exit /b 1
)

echo [3/3] Done!
echo GodotMidiUSB-release.aar is ready. Re-export APK from Godot now.
pause

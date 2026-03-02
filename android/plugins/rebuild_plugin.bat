@echo off
:: 重新编译 GodotMidiUSB 插件 AAR 并更新到 plugins 目录
:: 在 android/ 目录的同级目录（项目根目录）中双击运行，或在 CMD 中执行：
::   android\plugins\rebuild_plugin.bat

echo [1/3] 编译 GodotMidiUSB 插件...
cd /d "%~dp0..\"
call gradlew.bat :plugins:GodotMidiUSB:assembleRelease
if errorlevel 1 (
    echo [错误] 编译失败，请检查 Android SDK 配置。
    pause
    exit /b 1
)

echo [2/3] 复制 AAR 到 plugins 目录...
copy /Y "plugins\GodotMidiUSB\build\outputs\aar\GodotMidiUSB-release.aar" "plugins\GodotMidiUSB-release.aar"
if errorlevel 1 (
    echo [错误] 复制失败。
    pause
    exit /b 1
)

echo [3/3] 完成！
echo 新的 GodotMidiUSB-release.aar 已就位。
echo 请在 Godot 中重新导出 APK。
pause

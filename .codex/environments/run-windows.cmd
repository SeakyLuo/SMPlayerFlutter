@echo off
setlocal
chcp 65001 >nul
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"
call "%LOCALAPPDATA%\flutter\bin\flutter.bat" --no-version-check run -d windows

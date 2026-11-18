@echo off
setlocal
rem Flutter decodes MSBuild and linker output as UTF-8.
chcp 65001 >nul
pushd "%~dp0.."
call flutter run -d windows %*
set "build_result=%errorlevel%"
popd
exit /b %build_result%

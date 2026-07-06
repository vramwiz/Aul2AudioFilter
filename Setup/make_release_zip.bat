@echo off
setlocal

set "PROJECT_ROOT=%~dp0.."
set "PLUGIN_DIR=C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter"
set "PLUGIN_FILE=%PLUGIN_DIR%\Aul2AudioFilter.auf2"
set "README_FILE=%PROJECT_ROOT%\README.md"
set "PACKAGE_NAME=Aul2AudioFilter"
set "WORK_DIR=%~dp0%PACKAGE_NAME%"
set "ZIP_FILE=%~dp0%PACKAGE_NAME%.zip"

if not exist "%PLUGIN_FILE%" (
  echo Plugin file not found:
  echo   %PLUGIN_FILE%
  echo Build the project first, then run this batch again.
  exit /b 1
)

if not exist "%README_FILE%" (
  echo README not found:
  echo   %README_FILE%
  exit /b 1
)

if exist "%WORK_DIR%" rmdir /S /Q "%WORK_DIR%"
if exist "%ZIP_FILE%" del /Q "%ZIP_FILE%"

mkdir "%WORK_DIR%"
copy /Y "%PLUGIN_FILE%" "%WORK_DIR%\Aul2AudioFilter.auf2" >nul
copy /Y "%README_FILE%" "%WORK_DIR%\README.md" >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Compress-Archive -Path '%WORK_DIR%' -DestinationPath '%ZIP_FILE%' -Force"

if errorlevel 1 (
  echo Failed to create zip:
  echo   %ZIP_FILE%
  exit /b 1
)

rmdir /S /Q "%WORK_DIR%"

echo Created:
echo   %ZIP_FILE%
exit /b 0

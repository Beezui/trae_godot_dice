@echo off
chcp 65001 >nul
echo ====================================
echo Skill CSV to JSON Converter
echo ====================================
echo.

set SCRIPT_DIR=%~dp0
set CSV_FILE=%SCRIPT_DIR%..\table\skill.csv
set JSON_FILE=%SCRIPT_DIR%..\table\skill.json

echo Converting: %CSV_FILE%
echo Output: %JSON_FILE%
echo.

powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%convert_skill_csv_to_json.ps1" "%CSV_FILE%" "%JSON_FILE%"

echo.
echo Press any key to exit...
pause >nul

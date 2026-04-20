@echo off
chcp 65001
cd /d "%~dp0"
echo Converting hero.csv to hero.json...
python convert_hero_csv_to_json.py "..\table\hero.csv" "..\table\hero.json"
if %errorlevel% equ 0 (
    echo Conversion successful!
) else (
    echo Conversion failed!
)
pause

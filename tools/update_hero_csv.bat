@echo off
chcp 65001
cd /d "%~dp0"
python update_hero_csv.py "..\table\hero.csv"
pause

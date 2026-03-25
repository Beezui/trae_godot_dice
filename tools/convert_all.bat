@echo off
chcp 65001 >nul
echo ==================================================
echo 关卡配置表 CSV to JSON 转换工具
echo ==================================================
echo.

cd /d "%~dp0"

echo [1/8] 转换技能配置表...
python convert_skill_csv_to_json.py
echo.

echo [2/8] 转换数字骰子配置表...
python convert_skill_csv_to_json.py --num-dices
echo.

echo [3/8] 转换技能骰子配置表...
python convert_skill_csv_to_json.py --skill-dices
echo.

echo [4/8] 转换属性骰子配置表...
python convert_skill_csv_to_json.py --attr-dices
echo.

echo [5/8] 转换英雄角色配置表...
python convert_skill_csv_to_json.py --hero
echo.

echo [6/8] 转换场景配置表...
python convert_skill_csv_to_json.py --scenes
echo.

echo [7/8] 转换核心节点配置表...
python convert_skill_csv_to_json.py --core-nodes
echo.

echo [8/8] 转换随机节点配置表...
python convert_skill_csv_to_json.py --random-nodes
echo.

echo ==================================================
echo 所有转换完成！
echo ==================================================
echo.
pause

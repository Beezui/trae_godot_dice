# Skill CSV to JSON 转换工具使用说明

## 概述

本工具用于将 `skill.csv` 文件转换为 `skill.json` 格式，解决 CSV 编码问题并提供更好的数据结构支持。

## 工具位置

```
res://tools/
├── convert_skill_csv_to_json.py     # Python 版本（推荐）
├── convert_skill_csv_to_json.ps1    # PowerShell 版本（备选）
├── convert_skill_csv_to_json.bat    # Windows 批处理启动器
└── README.md                        # 本说明文档
```

## 使用方法

### 方法一：Python 版本（强烈推荐）

**这是最可靠的方法，推荐使用！**

1. **确保已安装 Python 3.6+**

2. **运行转换脚本**：
   ```bash
   cd res://tools/
   python convert_skill_csv_to_json.py
  
   ```
   #导出技能骰子表
   
   python convert_skill_csv_to_json.py --skill-dices

3. **自动转换**：
   - 工具会自动读取 `res://table/skill.csv`
   - 转换为 `res://table/skill.json`
   - 显示转换结果和技能列表

4. **查看结果**：
   - 转换成功后，打开 `res://table/skill.json` 查看结果
   - 中文正常显示，无乱码

### 方法二：PowerShell 版本（备选）

如果未安装 Python，可使用 PowerShell 版本：

1. **双击运行批处理文件**：
   ```
   res://tools/convert_skill_csv_to_json.bat
   ```

2. **或直接运行 PowerShell 脚本**：
   ```powershell
   powershell -ExecutionPolicy Bypass -File "res://tools/convert_skill_csv_to_json.ps1" "res://table/skill.csv" "res://table/skill.json"
   ```

## 功能特性

### ✅ 自动编码检测
工具会自动尝试多种编码格式：
- UTF-8
- GBK（中文 Windows 默认）
- GB2312
- UTF-8 with BOM

### ✅ 智能 CSV 解析
- 正确处理带引号的字段
- 处理字段内的逗号
- 自动去除首尾空格

### ✅ 属性类型解析
自动解析 `属性类型` 字段，例如：
```
1:力量，2:敏捷
```
转换为 JSON 格式：
```json
{
  "1": "力量",
  "2": "敏捷"
}
```

## 输入输出示例

### 输入：skill.csv
```csv
id，名称，描述，属性类型，图标
10001，火球术，"向目标发射一枚火球...", "1:力量，2:敏捷",10001
10002，冰冻术，"冻结目标 3 秒...", "1:智力",10002
```

### 输出：skill.json
```json
{
  "skills": [
    {
      "id": "10001",
      "name": "火球术",
      "description": "向目标发射一枚火球...",
      "attribute_dice": {
        "1": "力量",
        "2": "敏捷"
      },
      "icon": "10001"
    },
    {
      "id": "10002",
      "name": "冰冻术",
      "description": "冻结目标 3 秒...",
      "attribute_dice": {
        "1": "智力"
      },
      "icon": "10002"
    }
  ]
}
```

## 常见问题

### Q: 转换后中文显示为乱码？
A: 工具会自动检测编码，如果仍有问题，请检查 CSV 文件的原始编码格式。

### Q: 转换失败，提示无法读取文件？
A: 确认 CSV 文件路径正确，文件未被其他程序占用。

### Q: 属性骰子配置为空？
A: 检查 CSV 中 `属性类型` 列的格式是否为 `序号：属性名`，多个属性用逗号分隔。

### Q: 如何在 Godot 中使用转换后的 JSON？
A: 转换完成后重启 Godot 编辑器，技能系统会自动加载新的 JSON 配置。

## 添加新技能

1. **编辑 skill.csv**，添加新行：
   ```csv
   10003，闪电链，"对目标及周围敌人造成伤害","1:智力",10003
   ```

2. **运行转换工具**

3. **在 skill_system.gd 中添加技能处理逻辑**：
   ```gdscript
   match skill_id:
       "10001":
           _execute_fireball(skill, caster, target)
       "10002":
           _execute_frost(skill, caster, target)
       "10003":
           _execute_lightning(skill, caster, target)  # 新增
   ```

## 技术细节

### 批处理版本
- 使用 PowerShell 进行 CSV 解析和 JSON 生成
- 支持多种编码自动检测
- 彩色输出，易于查看结果

### Python 版本
- 使用 Python 内置 csv 和 json 模块
- 跨平台支持（Windows/Linux/Mac）
- 可作为独立脚本或模块调用

## 注意事项

1. **转换前备份**：建议先备份原始 CSV 文件
2. **Godot 缓存**：转换后需重启 Godot 编辑器
3. **文件格式**：确保 CSV 使用逗号分隔，引号包裹包含逗号的字段
4. **编码统一**：建议统一使用 UTF-8 编码编辑 CSV 文件

## 更新日志

- **v1.0** (2026-03-11)
  - 初始版本发布
  - 支持 CSV 到 JSON 的完整转换
  - 自动编码检测
  - 智能属性类型解析

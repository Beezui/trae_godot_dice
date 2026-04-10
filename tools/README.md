# Skill CSV to JSON 转换工具使用说明

## 概述

本工具用于将游戏中的各种 CSV 配置文件转换为 JSON 格式，解决 CSV 编码问题并提供更好的数据结构支持。支持转换的文件包括：
- `skill.csv` → `skill.json`（技能配置）
- `NumDices.csv` → `NumDices.json`（数字骰子配置）
- `SkillDices.csv` → `SkillDices.json`（技能骰子配置）
- `AttrDices.csv` → `AttrDices.json`（属性骰子配置）
- `hero.csv` → `hero.json`（英雄角色配置）
- `scenes.csv` → `scenes.json`（场景配置）
- `core_nodes.csv` → `core_nodes.json`（核心节点配置）
- `boss.csv` → `boss.json`（BOSS 配置）

## 工具位置

```
res://tools/
├── convert_skill_csv_to_json.py     # Python 版本（CSV 转 JSON）
├── convert_json_to_csv.py           # Python 版本（JSON 转 CSV）
├── convert_skill_csv_to_json.ps1    # PowerShell 版本（备选）
├── convert_skill_csv_to_json.bat    # Windows 批处理启动器
└── README.md                        # 本说明文档
```

## 使用方法

### 方法 0：批量转换所有配置（推荐）

**最快速的方式，一次性转换所有配置文件！**

1. **双击运行批处理文件**：
   ```
   res://tools/convert_all.bat
   ```

2. **等待转换完成**：
   - 自动依次转换 8 个配置文件
   - 显示每个文件的转换进度
   - 转换完成后按任意键关闭

### 方法一：Python 版本（推荐单个文件转换）

**这是最可靠的方法，推荐使用！**

1. **确保已安装 Python 3.6+**

2. **运行转换脚本**：
   ```bash
   cd res://tools/
   
   # 导出技能配置表
   python convert_skill_csv_to_json.py
   
   # 导出数字骰子表
   python convert_skill_csv_to_json.py --num-dices
   
   # 导出技能骰子表
   python convert_skill_csv_to_json.py --skill-dices
   
   # 导出属性骰子表
   python convert_skill_csv_to_json.py --attr-dices
   
   # 导出英雄角色表
   python convert_skill_csv_to_json.py --hero
   
   # 导出核心节点表
   python convert_skill_csv_to_json.py --core-nodes
   
   # 导出随机节点表
   python convert_skill_csv_to_json.py --random-nodes
   
   # 导出 BOSS 配置表
   python convert_skill_csv_to_json.py --boss
   ```
3. **自动转换**：
   - 导出技能配置：读取 `res://table/skill.csv` → 转换为 `res://table/skill.json`
   - 导出数字骰子：读取 `res://table/NumDices.csv` → 转换为 `res://table/NumDices.json`
   - 导出技能骰子：读取 `res://table/SkillDices.csv` → 转换为 `res://table/SkillDices.json`
   - 导出属性骰子：读取 `res://table/AttrDices.csv` → 转换为 `res://table/AttrDices.json`
   - 导出英雄角色：读取 `res://table/hero.csv` → 转换为 `res://table/hero.json`
   - 导出场景配置：读取 `res://table/scenes.csv` → 转换为 `res://table/scenes.json`
   - 导出核心节点：读取 `res://table/core_nodes.csv` → 转换为 `res://table/core_nodes.json`
   - 导出随机节点：读取 `res://table/random_nodes.csv` → 转换为 `res://table/random_nodes.json`
   - 导出 BOSS 配置：读取 `res://table/boss.csv` → 转换为 `res://table/boss.json`
   - 显示转换结果和数据列表

4. **查看结果**：
   - 转换成功后，打开相应的 JSON 文件查看结果：
     - 技能配置：`res://table/skill.json`
     - 数字骰子：`res://table/NumDices.json`
     - 技能骰子：`res://table/SkillDices.json`
     - 属性骰子：`res://table/AttrDices.json`
     - 英雄角色：`res://table/hero.json`
     - 场景配置：`res://table/scenes.json`
     - 核心节点：`res://table/core_nodes.json`
     - 随机节点：`res://table/random_nodes.json`
     - BOSS 配置：`res://table/boss.json`
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

### 方法三：JSON 转 CSV 转换

如果需要将 JSON 文件转换回 CSV 文件，可使用以下命令：

1. **转换核心节点配置**：
   ```bash
   cd res://tools/
   python convert_json_to_csv.py --core-nodes
   ```

2. **指定输入输出文件**：
   ```bash
   python convert_json_to_csv.py --core-nodes [input.json] [output.csv]
   ```

3. **示例**：
   ```bash
   python convert_json_to_csv.py --core-nodes ../table/core_nodes.json ../table/core_nodes.csv
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

### Q: 英雄角色配置中的数组格式有什么要求？
A: 英雄角色配置中的数组（如属性值、技能骰子 ID、纹理等）使用分号（;）作为分隔符，例如：`5;11;17;23;29;35`。

### Q: 技能骰子 ID 现在是数组格式，如何配置？
A: 技能骰子 ID 现在支持多个值，使用分号（;）分隔，例如：`4001;4002;4003`。

### Q: 核心节点配置中的 next、enemy、npc 字段如何配置？
A: 这些字段都是数组格式，使用分号（;）分隔，例如：
- `next`: `2;4;6` 表示下一个节点可以是 2、4 或 6
- `enemy`: `1;2;3` 表示包含敌人 ID 为 1、2、3 的敌人
- `npc`: `1;3` 表示包含 NPC ID 为 1 和 3 的 NPC

### Q: 随机节点配置中的 npc 字段如何配置？
A: npc 字段使用分号（;）分隔多个 NPC ID，例如：`1;2;3` 表示包含 NPC ID 为 1、2、3 的 NPC。

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

- **v1.3** (2026-03-24)
  - 新增核心节点配置转换功能（core_nodes.csv → core_nodes.json）
  - 新增随机节点配置转换功能（random_nodes.csv → random_nodes.json）
  - 支持关卡系统配置表的完整转换

## 更新日志

- **v1.4** (2026-04-08)
  - 新增 BOSS 配置转换功能

- **v1.3** (2026-04-04)
  - 新增核心节点配置转换功能

- **v1.2** (2026-03-21)
  - 新增场景配置转换功能

- **v1.1** (2026-03-17)
  - 新增属性骰子配置转换功能
  - 新增英雄角色配置转换功能
  - 优化英雄角色数组解析，支持分号分隔的数组格式
  - 修复空数据行处理逻辑

- **v1.0** (2026-03-11)
  - 初始版本发布
  - 支持 CSV 到 JSON 的完整转换
  - 自动编码检测
  - 智能属性类型解析

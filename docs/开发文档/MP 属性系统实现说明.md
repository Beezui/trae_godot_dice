# MP 属性系统实现说明

**日期**: 2026-04-15  
**状态**: 已完成

---

## 概述

为角色系统添加了行动点（MP）属性，支持不同角色使用不同的行动点名称（如"魔法值"、"体力值"、"能量值"等）。

---

## 修改文件清单

### 1. 配置文件

#### `table/hero.csv`
- **修改内容**: 添加 `attr_mp` 和 `mp_name` 两列
- **列位置**: 第 7 列（attr_mp）、第 8 列（mp_name）
- **数据格式**:
  - `attr_mp`: 固定整数值（如 "50"、"30"）
  - `mp_name`: 字符串（如 "魔法值"、"体力值"）

**示例数据**:
```csv
id,name,attr_str,attr_agi,attr_int,attr_hp,attr_mp,mp_name,skill_slot,skill_dice_id,texture,portrait,hero_texture
1，测试角色，1;1;2;2;3;3,1;3;3;3;5;5,1;1;2;2;3;3,100,50，魔法值，1,4001,1001;1001;1001;1001;1001;1001,1,idle;idle;idle;idle;idle;idle
2，测试怪物，2;2;4;4;5;5,1;3;3;3;5;5,1;1;2;2;3;3,100,30，体力值，1,4002,1001;1001;1001;1001;1001;1001,1,idle;idle;idle;idle;idle;idle
```

#### `table/hero.json`
- **修改内容**: 由 CSV 转换工具自动生成
- **新增字段**:
  ```json
  {
    "attr_mp": "50",
    "mp_name": "魔法值"
  }
  ```

### 2. 转换工具

#### `tools/convert_skill_csv_to_json.py`
- **修改函数**: `convert_hero_csv_to_json()`
- **修改内容**:
  - 更新列数检查：从 11 列改为 13 列
  - 添加 `attr_mp` 和 `mp_name` 的解析逻辑
  - 在输出 JSON 中包含 MP 属性

**修改位置**: 第 500-550 行

#### 新增工具 `tools/convert_hero_csv_to_json.py`
- **用途**: 独立的 hero.csv 转 hero.json 工具（支持 MP 属性）
- **使用方式**:
  ```bash
  python convert_hero_csv_to_json.py ../table/hero.csv ../table/hero.json
  ```

### 3. 角色系统脚本

#### `scripts/character/BaseCharacter.gd`

**新增属性** (第 16-18 行):
```gdscript
var attr_mp: int     # 行动点上限（固定值）
var current_mp: int  # 当前行动点
var mp_name: String  # 行动点名称
```

**修改 `load_from_data()` 函数** (第 81-85 行):
```gdscript
# 解析行动点（MP）
var mp_value = data.get("attr_mp", "50")
attr_mp = int(mp_value) if mp_value is String else mp_value
current_mp = attr_mp
mp_name = data.get("mp_name", "魔法值")
```

**新增方法**:

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| `get_mp_percentage()` | 无 | float | 获取 MP 百分比 |
| `can_afford_mp(cost)` | cost: int | bool | 检查是否有足够 MP |
| `take_mp_cost(cost)` | cost: int | bool | 消耗 MP |
| `recover_mp(amount)` | amount: int | int | 恢复 MP |
| `set_mp(value)` | value: int | void | 设置 MP 值 |

**修改 `get_config()` 方法**:
- 添加 `attr_mp`、`current_mp`、`mp_name` 到返回的字典中

---

## 使用方法

### 1. 在 CSV 中配置 MP 属性

编辑 `table/hero.csv`，添加 `attr_mp` 和 `mp_name` 列：

```csv
id,name,...,attr_mp,mp_name,...
1，法师角色，...,80，魔法值，...
2，战士角色，...,40，体力值，...
3，刺客角色，...,60，能量值，...
```

### 2. 转换为 JSON

运行转换工具：
```bash
cd tools
python convert_hero_csv_to_json.py ../table/hero.csv ../table/hero.json
```

### 3. 在代码中使用 MP

```gdscript
# 获取角色实例
var character = CharacterManager.get_character(hero_id)

# 检查 MP 是否足够
if character.can_afford_mp(20):
    # 消耗 MP 并释放技能
    if character.take_mp_cost(20):
        use_skill()

# 恢复 MP（回合结束）
character.recover_mp(10)

# 获取 MP 百分比（用于 UI 显示）
var mp_percent = character.get_mp_percentage()

# 获取行动点名称（用于 UI 显示）
print("当前", character.mp_name, "：", character.current_mp, "/", character.attr_mp)
```

---

## 设计说明

### 为什么 MP 是固定值而不是骰子？

1. **简化操作**: 避免每次行动都要投掷 MP 骰子
2. **策略性**: 玩家需要管理固定的 MP 池，做出资源分配决策
3. **符合直觉**: 类似传统 RPG 的魔法值系统

### 为什么行动点名称需要配置？

1. **职业差异化**:
   - 法师/牧师：魔法值（Mana）
   - 战士/骑士：体力值（Stamina）
   - 刺客/武僧：能量值（Energy）
   - 狂战士：怒气值（Rage）

2. **UI 显示**: 可以根据 `mp_name` 动态显示不同的文本

3. **扩展性**: 未来可以根据 `mp_name` 实现不同的恢复机制

---

## MP 恢复机制建议

根据需求"以上可能都存在"，建议实现以下多种恢复方式：

### 1. 回合结束自动恢复
```gdscript
func _on_turn_ended():
    for character in all_characters:
        character.recover_mp(10)  # 固定恢复
        # 或按比例恢复
        # character.recover_mp(character.attr_mp * 0.2)
```

### 2. 使用物品恢复
```gdscript
func use_mana_potion(character, amount):
    character.recover_mp(amount)
    item_manager.remove_item("mana_potion")
```

### 3. 特定技能恢复
```gdscript
# 冥想技能
func meditate(character):
    if character.take_mp_cost(5):  # 消耗 MP
        character.recover_mp(20)   # 恢复更多 MP（净 gain）
```

### 4. 战斗外恢复
```gdscript
func _on_battle_won():
    for character in party:
        character.set_mp(character.attr_mp)  # 完全恢复
```

---

## UI 显示建议

### 角色骰子上的 MP 显示
```gdscript
# 在角色骰子上添加 MP 标签
var mp_label = Label.new()
mp_label.text = "%s: %d/%d" % [character.mp_name, character.current_mp, character.attr_mp]
dice.add_child(mp_label)
```

### 进度条显示
```gdscript
# MP 进度条
$mp_bar.max_value = character.attr_mp
$mp_bar.value = character.current_mp
$mp_bar_label.text = character.mp_name
```

---

## 技能消耗建议

```gdscript
# 技能配置示例（skill.json）
{
    "id": "10001",
    "name": "火球术",
    "mp_cost": 20,  # 新增：MP 消耗
    "damage_formula": "p1 * 2 + 10"
}

# 技能使用时
func use_skill(skill_id, caster, target):
    var skill = skill_manager.get_skill(skill_id)
    var mp_cost = skill.get("mp_cost", 0)
    
    if not caster.can_afford_mp(mp_cost):
        print("MP 不足！")
        return false
    
    caster.take_mp_cost(mp_cost)
    execute_skill(skill, caster, target)
    return true
```

---

## 注意事项

1. **编码问题**: 
   - CSV 文件必须使用 UTF-8 with BOM 编码
   - 分隔符必须是英文逗号（,），不是中文逗号（，）
   - 包含特殊字符的字段需要用双引号包裹

2. **备份原文件**:
   - 修改前已备份：`hero.csv.bak`
   - 如需回滚：`copy hero.csv.bak hero.csv`

3. **Godot 缓存**:
   - 修改 JSON 后需重启 Godot 编辑器
   - 或使用 `hero_csv_reader.gd` 的 `refresh()` 方法

4. **兼容性**:
   - 旧版 hero.json 没有 `attr_mp` 和 `mp_name` 字段时，使用默认值（50，"魔法值"）
   - 不影响现有功能

---

## 测试建议

1. **基础测试**:
   - 创建角色后检查 `attr_mp` 和 `mp_name` 是否正确加载
   - 测试 `take_mp_cost()` 在 MP 充足和不足时的行为
   - 测试 `recover_mp()` 不会超过上限

2. **边界测试**:
   - MP=0 时的行为
   - 负数消耗的处理
   - 超过上限的恢复处理

3. **集成测试**:
   - 与技能系统联动
   - 与 UI 系统联动
   - 存档/读档时 MP 状态的保存

---

## 下一步工作

1. **技能系统集成**: 为现有技能添加 `mp_cost` 配置
2. **UI 实现**: 在角色骰子上显示 MP 进度
3. **恢复机制**: 实现回合结束自动恢复
4. **战斗框架**: 在战斗流程中集成 MP 管理

---

**完成时间**: 2026-04-15  
**开发者**: Claude Code

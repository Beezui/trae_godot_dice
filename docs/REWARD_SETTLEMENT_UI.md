# 奖励结算 UI 使用文档

## 文件位置

```
scripts/ui/reward_settlement_ui.gd        # 主脚本
scripts/ui/reward_settlement_ui_example.gd # 使用示例
scenes/ui/reward_settlement_ui.tscn       # UI场景
```

## 快速开始

### 1. 基础使用

```gdscript
# 预加载场景
const REWARD_UI_SCENE: PackedScene = preload("res://scenes/ui/reward_settlement_ui.tscn")

# 实例化并显示
var ui = REWARD_UI_SCENE.instantiate()
get_tree().root.add_child(ui)

# 准备奖励数据
var rewards = [
    {"id": "101", "amount": 1},  # 火焰术 x1
    {"id": "301", "amount": 3},  # 生命药水 x3
]

# 从道具表获取数据（见下文"道具表接口"）
var item_table = _get_item_table()

# 显示奖励
ui.show_rewards(rewards, item_table)

# 监听确认按钮
ui.on_confirm_pressed.connect(_on_confirm)

func _on_confirm():
    print("玩家确认领取奖励")
    # TODO: 添加奖励到背包
```

### 2. 根据关卡类型显示奖励

```gdscript
## 根据关卡类型决定是否显示奖励
## @param level_type: String - "battle", "reward", "encounter", "trade"
func show_level_rewards(level_type: String, rewards: Array):
    # 贸易关卡不显示奖励
    if level_type == "trade":
        return

    # 其他关卡显示奖励
    if level_type in ["battle", "reward", "encounter"]:
        var ui = REWARD_UI_SCENE.instantiate()
        get_tree().root.add_child(ui)
        ui.show_rewards(rewards, get_item_table())
```

### 3. 从道具表获取数据

奖励 UI 需要道具表数据来显示道具名称、图标等信息。

#### 方案 A：使用示例中的模拟数据

```gdscript
func _get_item_table() -> Dictionary:
    return {
        "101": {"name": "火焰术", "type": "技能书", "price": 100, "description": "学习火焰技能", "icon": "fire_skill.png"},
        "201": {"name": "力量护符", "type": "宝物", "price": 200, "description": "增加力量属性", "icon": "amulet_str.png"},
        "301": {"name": "生命药水", "type": "消耗品", "price": 30, "description": "恢复少量生命值", "icon": "potion_hp_small.png"},
    }
```

#### 方案 B：从 TableManager 加载（待实现）

```gdscript
# TODO: 在 TableManager 或 DataManager 中实现
func get_item_table() -> Dictionary:
    var table_manager = get_node("/root/TableManager")
    return table_manager.get_items_table()
```

## 道具表数据结构

```gdscript
# 道具表格式
{
    "101": {
        "name": "火焰术",
        "type": "技能书",
        "price": 100,
        "description": "学习火焰技能",
        "icon": "fire_skill.png"
    },
    ...
}
```

### 道具表字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 道具唯一标识 |
| name | String | 显示名称 |
| type | String | 道具类型（技能书/宝物/消耗品） |
| price | int | 价格（金币） |
| description | String | 详细描述 |
| icon | String | 图标文件名（在 `textures/items/` 目录下） |

## 奖励数据结构

```gdscript
# 单个奖励格式
{"id": "101", "amount": 1}

# 多个奖励
[
    {"id": "101", "amount": 1},
    {"id": "301", "amount": 3},
    {"id": "gold", "amount": 100},  # 金币奖励
]
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 道具ID（金币用 "gold"） |
| amount | int | 数量 |

## 信号说明

| 信号 | 参数 | 说明 |
|------|------|------|
| on_confirm_pressed | - | 玩家点击"确认领取"按钮 |
| on_reward_hovered | Dictionary | 鼠标悬停在奖励项上，参数为奖励数据 |
| on_reward_hover_exited | - | 鼠标离开奖励项 |

## UI 特性

1. **居中显示**：面板自动居中在屏幕中央
2. **滚动列表**：奖励过多时可滚动
3. **悬停提示**：鼠标悬停显示道具详细信息（名称、描述、价格）
4. **数量显示**：当数量 > 1 时显示 "xN"
5. **图标显示**：从 `textures/items/` 目录加载图标

## 待集成事项

1. **道具表接入**：将 `_get_item_table()` 替换为实际的 TableManager 数据
2. **金币奖励**：当 `id` 为 "gold" 时，需要特殊处理显示金币图标
3. **奖励发放**：在 `on_confirm_pressed` 回调中实现奖励发放逻辑
4. **动画效果**：可选添加奖励出现的动画效果

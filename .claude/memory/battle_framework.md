---
name: 战斗框架架构与使用
description: 战斗框架的单例结构、核心方法、调用流程和场景创建指南
type: reference
---

# 战斗框架参考文档

## 全局单例列表 (Autoload)

以下单例在 `project.godot` 中注册，可在任何脚本中直接调用：

| 单例名称 | 路径 | 职责 |
|---------|------|------|
| `BattleManager` | `res://scripts/battle/battle_manager.gd` | 战斗流程管理（回合、阶段、胜负判定） |
| `DiceManager` | `res://scripts/dice/dice_manager.gd` | 所有类型骰子的创建管理 |
| `DiceThrowController` | `res://scripts/dice/dice_throw_controller.gd` | 投掷控制（蓄力 + 震动效果） |
| `DiceResultDetector` | `res://scripts/dice/dice_result_detector.gd` | 骰子结果检测（向量点积法） |
| `CharacterManager` | `res://scripts/character/CharacterManager.gd` | 角色创建/生命周期管理 |
| `SkillManager` | `res://skills/skill_manager.gd` | 技能注册/冷却/释放 |
| `CameraManager` | `res://scripts/camera_manager.gd` | 摄像机配置管理 |

## 核心方法速查

### 战斗流程
```gdscript
# 初始化战斗
BattleManager.initialize_battle(level_node: LevelNode, player_party: Array[int]) -> bool

# 开始战斗流程
BattleManager.start_battle()

# 玩家结束回合
BattleManager.player_end_turn()

# 玩家使用技能
BattleManager.player_use_skill(character, skill_dice, target) -> bool
```

### 骰子创建
```gdscript
# 角色骰子
DiceManager.create_character_dice(character: BaseCharacter, parent: Node, position: Vector3) -> RigidBody3D

# 技能骰子（可隐藏）
DiceManager.create_skill_dice(skill_dice_id: String, parent: Node, position: Vector3, add_to_scene: bool) -> RigidBody3D

# 属性骰子
DiceManager.create_attribute_dice(hero_id: int, attr_type: String, parent: Node, position: Vector3) -> RigidBody3D

# 批量创建属性骰子
DiceManager.create_all_attribute_dices(hero_id: int, parent: Node, positions: Array) -> Dictionary
```

### 投掷控制
```gdscript
# 开始蓄力（自动记录位置并处理震动）
DiceThrowController.start_charge(dices: Array)

# 结束蓄力并投掷
DiceThrowController.end_charge()

# 普通投掷
DiceThrowController.throw_normal(dices: Array, force_multiplier: float)
```

### 结果检测
```gdscript
# 等待骰子稳定
DiceResultDetector.wait_for_dice_stable(dices: Array, timeout: float) -> bool

# 检测单个骰子值
DiceResultDetector.check_dice_value(dice: RigidBody3D) -> int
```

### 角色管理
```gdscript
# 创建角色
CharacterManager.create_character(hero_id: int, character_type: String) -> BaseCharacter

# 获取角色
CharacterManager.get_character(hero_id: int) -> BaseCharacter

# 清空所有角色
CharacterManager.clear_all_characters()

# 设置骰子缩放
CharacterManager.set_character_dice_scale(hero_id: int, scale: Vector3) -> bool
```

### 技能释放
```gdscript
# 使用技能
SkillManager.use_skill(skill_id: String, caster: Node, targets: Array, params: Dictionary) -> bool

# 检查技能可用
SkillManager.can_use_skill(skill_id: String) -> bool

# 获取技能配置
SkillManager.get_skill(skill_id: String) -> Dictionary
```

## 战斗场景创建流程

### 1. 创建场景文件 (.tscn)

场景结构：
```
- Node3D (继承 BattleSceneBase)
  - Camera3D
  - DirectionalLight3D
  - Sandbox
    - Ground
    - WallNorth
    - WallSouth
    - WallEast
    - WallWest
  - BattleUI
    - SkillBar (BattleSkillBar 场景)
```

### 2. 创建脚本文件 (.gd)

```gdscript
extends BattleSceneBase

func _ready():
    super._ready()
    
    # 生成关卡数据
    var level_node = LevelGenerator.generate_level(1, Time.get_ticks_msec())
    
    # 玩家队伍（英雄 ID 列表）
    var player_party = [1]  # 使用 hero_id=1 的玩家
    
    # 初始化战斗
    initialize_battle(level_node, player_party)
    
    # 开始战斗流程
    start_battle_flow()


func _on_battle_completed(victory: bool):
    if victory:
        print("战斗胜利！")
        # 进入下一关卡
    else:
        print("战斗失败！")
        # 返回标题或重试
```

### 3. 最小可用战斗场景示例

```gdscript
# res://scenes/my_battle_scene.gd
extends BattleSceneBase

@export var player_hero_ids: Array[int] = [1]

func _ready():
    super._ready()
    
    # 创建测试关卡
    var test_level = LevelGenerator.generate_level(1, 12345)
    
    # 初始化并启动
    initialize_battle(test_level, player_hero_ids)
    start_battle_flow()
```

## 投掷流程详解

### 完整投掷流程（玩家回合）

```gdscript
# 1. 玩家选择技能骰子（BattleSkillBar 中处理）
selected_skill_dice = skill_dice
selected_character = character

# 2. 将骰子移动到场景（悬浮状态）
_move_skill_dice_to_scene(skill_dice)

# 3. 开始蓄力（空格键按下）
DiceThrowController.start_charge(all_throw_dices)

# 4. 结束蓄力并投掷（空格键松开）
DiceThrowController.end_charge()

# 5. 等待骰子稳定
await DiceResultDetector.wait_for_dice_stable(all_throw_dices, 5.0)

# 6. 获取结果
var skill_result = skill_dice.get_dice_value()
var attr_results = {
    "str": str_dice.get_attribute_value(),
    "agi": agi_dice.get_attribute_value(),
    "int": int_dice.get_attribute_value()
}

# 7. 释放技能
SkillManager.use_skill(skill_id, caster_node, targets, params)

# 8. 复位骰子
_reset_throw_dices()
```

## 战斗阶段流程

```
PHASE_ENTER (入场阶段)
    ├─ 敌方角色入场 + 自动投掷
    └─ 玩家角色入场 + 自动投掷
    
PHASE_SETUP (准备阶段)
    ├─ 生成技能骰子（隐藏，仅 UI 显示）
    ├─ 生成属性骰子（悬浮待命）
    └─ 初始化 UI
    
PHASE_BATTLE (战斗阶段)
    ├─ 玩家回合
    │   ├─ 恢复 MP
    │   ├─ 等待玩家操作
    │   └─ 玩家结束回合
    ├─ 敌方回合
    │   ├─ AI 决策
    │   ├─ 投掷骰子
    │   └─ 释放技能
    └─ 检查胜负
    
PHASE_RESOLVE (结算阶段)
    └─ 结算奖励
    
PHASE_TRANSITION (转换阶段)
    └─ 投掷命运骰子（进入下一关）
```

## 关键配置

### 投掷区域标准位置

沙盘尺寸：24.0 x 13.5（16:9 比例）

```gdscript
# 投掷区域 z 坐标（靠近南墙）
var initial_z = base_height / 2 - 2  # 4.75

# 属性骰子位置（x 轴均匀分布）
var str_position = Vector3(-2.0, 4.0, 4.75)
var agi_position = Vector3(0.0, 4.0, 4.75)
var int_position = Vector3(2.0, 4.0, 4.75)

# 技能骰子位置
var skill_position = Vector3(-4.0, 4.0, 4.75)
```

### 摄像机配置

```gdscript
# BattleSceneBase 默认配置
@export var sandbox_width: float = 24.0
@export var sandbox_height: float = 13.5
@export var camera_height: float = 50.0
@export var camera_fov: float = 15.0

# 摄像机位置
camera.position = Vector3(1.3, camera_height, 14.1)
camera.rotation = Vector3(-75 * PI/180, 5.1 * PI/180, -4.9 * PI/180)
```

## 常见问题

### Q: 如何自定义技能 UI 布局？
A: 修改 `BattleSkillBar` 场景中的 `SkillContainer` (VBoxContainer) 布局属性。

### Q: 如何添加新的骰子类型？
A: 在 `DiceManager` 中添加新的 `create_xxx_dice()` 方法，并确保骰子场景继承自基础骰子。

### Q: 如何修改投掷力度？
A: 调整 `DiceThrowController` 的 `max_force` 和 `min_force_ratio` 导出变量。

### Q: 如何检测战斗结束？
A: 连接 `BattleManager.on_battle_finished` 信号或重写 `_on_battle_finished()` 方法。

## 相关文件路径

- 战斗管理器：`res://scripts/battle/battle_manager.gd`
- 战斗场景基类：`res://scripts/battle/battle_scene_base.gd`
- 技能栏 UI: `res://scripts/ui/battle_skill_bar.gd`
- 骰子管理器：`res://scripts/dice/dice_manager.gd`
- 投掷控制器：`res://scripts/dice/dice_throw_controller.gd`
- 结果检测器：`res://scripts/dice/dice_result_detector.gd`
- 角色管理器：`res://scripts/character/CharacterManager.gd`
- 技能管理器：`res://skills/skill_manager.gd`

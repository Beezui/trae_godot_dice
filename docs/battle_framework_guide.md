# 战斗框架使用指南

## 概述

本项目战斗框架基于 Godot 4.x 构建，采用 **autoload 单例模式** 统一管理核心系统，提供了一套完整的回合制战斗解决方案，包括：

- 角色创建与管理
- 骰子生成与投掷（含蓄力震动效果）
- 技能释放与结算
- 回合制战斗流程
- 战斗 UI 系统

## 架构图

```
┌─────────────────────────────────────────────────────────┐
│                    战斗场景                              │
│              (继承 BattleSceneBase)                      │
└─────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  BattleManager  │  │   DiceManager   │  │CharacterManager │
│  (战斗流程控制)  │  │  (骰子创建)     │  │  (角色创建)     │
└─────────────────┘  └─────────────────┘  └─────────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│DiceThrowController│ │DiceResultDetector│ │  SkillManager   │
│  (投掷 + 震动)     │ │  (结果检测)      │ │  (技能释放)     │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## 快速开始

### 1. 创建战斗场景

创建一个新的场景文件，根节点继承 `BattleSceneBase`：

```gdscript
# my_battle_scene.gd
extends BattleSceneBase

@export var player_hero_ids: Array[int] = [1]

func _ready():
    super._ready()
    
    # 生成关卡数据（或使用已有关卡）
    var level_node = LevelGenerator.generate_level(1, Time.get_ticks_msec())
    
    # 初始化战斗
    initialize_battle(level_node, player_hero_ids)
    
    # 启动战斗流程
    start_battle_flow()


func _on_battle_completed(victory: bool):
    """战斗完成回调"""
    if victory:
        print("🎉 战斗胜利！")
        # 进入下一关卡或显示结算界面
    else:
        print("💀 战斗失败！")
        # 返回标题或重试
```

### 2. 最小可用示例

```gdscript
# 最简单的战斗场景
extends BattleSceneBase

func _ready():
    super._ready()
    var test_level = LevelGenerator.generate_level(1, 12345)
    initialize_battle(test_level, [1])
    start_battle_flow()
```

## 核心系统详解

### BattleManager - 战斗流程管理

负责管理整个战斗流程，包括入场、回合、胜负判定。

**主要方法：**
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

**战斗阶段：**
```
PHASE_ENTER → PHASE_SETUP → PHASE_BATTLE → PHASE_RESOLVE → PHASE_TRANSITION
   入场          准备          战斗           结算           转换
```

### DiceManager - 骰子创建管理

统一负责所有类型骰子的创建。

**创建角色骰子：**
```gdscript
var character_dice = DiceManager.create_character_dice(
    character,  # BaseCharacter 实例
    sandbox,    # 父节点（通常是场景的 Sandbox）
    position    # 位置 Vector3
)
```

**创建技能骰子：**
```gdscript
var skill_dice = DiceManager.create_skill_dice(
    skill_dice_id,    # 技能骰子 ID（如 "4001"）
    sandbox,          # 父节点
    position,         # 位置
    false             # 是否添加到场景（false=隐藏，仅 UI 使用）
)
```

**创建属性骰子：**
```gdscript
var str_dice = DiceManager.create_attribute_dice(
    hero_id,      # 英雄 ID
    "str",        # 属性类型："str"/"agi"/"int"
    sandbox,      # 父节点
    position      # 位置
)
```

### DiceThrowController - 投掷控制

统一的投掷控制器，**自动处理蓄力震动效果**。

**蓄力投掷流程：**
```gdscript
# 1. 开始蓄力（空格键按下）
DiceThrowController.start_charge(dices)  # 自动记录位置并处理震动

# 2. 结束蓄力并投掷（空格键松开）
DiceThrowController.end_charge()  # 使用 start_charge 时记录的骰子
```

**普通投掷：**
```gdscript
DiceThrowController.throw_normal(dices, force_multiplier)
```

**配置参数：**
```gdscript
@export var max_charge_time: float = 2.0    # 最大蓄力时间（秒）
@export var max_force: float = 20.0         # 最大投掷力度
@export var min_force_ratio: float = 0.3    # 最小力度比例
@export var shake_amplitude: float = 0.05   # 震动幅度
```

### DiceResultDetector - 结果检测

使用**向量点积法**检测骰子结果。

**等待骰子稳定：**
```gdscript
var is_stable = await DiceResultDetector.wait_for_dice_stable(dices, 5.0)
if is_stable:
    print("骰子已稳定")
```

**检测骰子值：**
```gdscript
var dice_value = DiceResultDetector.check_dice_value(dice)
```

### CharacterManager - 角色管理

负责角色的创建、生命周期和状态管理。

**创建角色：**
```gdscript
# 玩家角色
var player = CharacterManager.create_character(1, "player")

# 敌方角色
var enemy = CharacterManager.create_character(2, "enemy")
```

**获取角色：**
```gdscript
var character = CharacterManager.get_character(hero_id)
```

**清空所有角色：**
```gdscript
CharacterManager.clear_all_characters()
```

### SkillManager - 技能管理

负责技能的注册、冷却和释放。

**使用技能：**
```gdscript
var success = SkillManager.use_skill(
    skill_id,   # 技能 ID（如 "10001"）
    caster,     # 施法者节点
    targets,    # 目标数组
    params      # 参数（包含 dice_results 等）
)
```

**技能参数格式：**
```gdscript
var params = {
    "dice_results": {
        "str": 4,
        "agi": 3,
        "int": 5
    },
    "scene": get_tree().current_scene,
    "caster_position": Vector3(0, 0, 0)
}
```

## 投掷流程完整示例

```gdscript
# 玩家选择技能后
func _on_skill_selected(skill_dice, character):
    selected_skill_dice = skill_dice
    selected_character = character
    
    # 1. 将技能骰子移动到场景（悬浮状态）
    _move_skill_dice_to_scene(skill_dice)
    
    # 2. 显示投掷提示
    _show_throw_hint("按空格键投掷")


# 空格键按下：开始蓄力
func _input(event):
    if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
        if selected_skill_dice and not is_charging:
            _start_throw()
    
    # 空格键松开：投掷
    if event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed:
        if is_charging:
            _execute_throw()


func _start_throw():
    is_charging = true
    
    # 获取所有要投掷的骰子（技能骰子 + 属性骰子）
    var all_dices = [selected_skill_dice, str_dice, agi_dice, int_dice]
    
    # 开始蓄力（自动处理震动）
    DiceThrowController.start_charge(all_dices)


func _execute_throw():
    is_charging = false
    
    # 获取所有骰子
    var all_dices = [selected_skill_dice, str_dice, agi_dice, int_dice]
    
    # 解除 freeze 状态
    for dice in all_dices:
        if dice.has_method("set_freeze"):
            dice.set_freeze(false)
        dice.linear_velocity = Vector3.ZERO
        dice.angular_velocity = Vector3.ZERO
    
    # 结束蓄力并投掷
    DiceThrowController.end_charge()
    
    # 等待骰子稳定
    await DiceResultDetector.wait_for_dice_stable(all_dices, 5.0)
    
    # 获取结果
    var skill_result = selected_skill_dice.get_dice_value()
    var attr_results = {
        "str": str_dice.get_attribute_value(),
        "agi": agi_dice.get_attribute_value(),
        "int": int_dice.get_attribute_value()
    }
    
    # 释放技能
    await _release_skill(skill_result, attr_results)
    
    # 复位骰子
    await _reset_throw_dices()
```

## 战斗场景配置

### 沙盘标准尺寸

```gdscript
@export var sandbox_width: float = 24.0   # 宽度（x 轴）
@export var sandbox_height: float = 13.5  # 高度（z 轴，16:9 比例）
```

### 投掷区域位置

```gdscript
# 投掷区域 z 坐标（靠近南墙）
var initial_z = sandbox_height / 2 - 2  # 4.75

# 属性骰子位置
var str_position = Vector3(-2.0, 4.0, initial_z)
var agi_position = Vector3(0.0, 4.0, initial_z)
var int_position = Vector3(2.0, 4.0, initial_z)

# 技能骰子位置
var skill_position = Vector3(-4.0, 4.0, initial_z)
```

### 摄像机配置

```gdscript
@export var camera_height: float = 50.0
@export var camera_fov: float = 15.0

# 摄像机位置
camera.position = Vector3(1.3, camera_height, 14.1)
camera.rotation = Vector3(-75 * PI/180, 5.1 * PI/180, -4.9 * PI/180)
```

## 配置文件

### Autoload 注册 (project.godot)

```ini
[autoload]
SkillManager="*res://skills/skill_manager.gd"
DiceTextureManager="*res://scripts/dice/dice_texture_manager.gd"
DiceThrowController="*res://scripts/dice/dice_throw_controller.gd"
DiceResultDetector="*res://scripts/dice/dice_result_detector.gd"
CharacterManager="*res://scripts/character/CharacterManager.gd"
CameraManager="*res://scripts/camera_manager.gd"
BattleManager="*res://scripts/battle/battle_manager.gd"
DiceManager="*res://scripts/dice/dice_manager.gd"
```

## 文件结构

```
晋升吧骰子/
├── scripts/
│   ├── battle/
│   │   ├── battle_manager.gd          # 战斗管理器
│   │   └── battle_scene_base.gd       # 战斗场景基类
│   ├── dice/
│   │   ├── dice_manager.gd            # 骰子管理器
│   │   ├── dice_throw_controller.gd   # 投掷控制器
│   │   └── dice_result_detector.gd    # 结果检测器
│   ├── character/
│   │   ├── CharacterManager.gd        # 角色管理器
│   │   ├── BaseCharacter.gd           # 角色基类
│   │   ├── PlayerCharacter.gd         # 玩家角色
│   │   └── EnemyCharacter.gd          # 敌方角色
│   └── ui/
│       └── battle_skill_bar.gd        # 技能栏 UI
├── skills/
│   ├── skill_manager.gd               # 技能管理器
│   ├── fireball_skill.gd              # 火球术
│   └── blizzard_skill.gd              # 暴风雪
└── scenes/
    └── test/
        └── battle_test_scene.tscn     # 战斗测试场景
```

## 常见问题

### Q: 如何自定义技能 UI 布局？

修改 `BattleSkillBar` 场景中的 `SkillContainer` (VBoxContainer) 布局属性。

### Q: 如何添加新的骰子类型？

在 `DiceManager` 中添加新的 `create_xxx_dice()` 方法，并确保骰子场景继承自基础骰子。

### Q: 如何修改投掷力度？

调整 `DiceThrowController` 的 `max_force` 和 `min_force_ratio` 导出变量。

### Q: 如何检测战斗结束？

连接 `BattleManager.on_battle_finished` 信号：
```gdscript
BattleManager.on_battle_finished.connect(_on_battle_finished)

func _on_battle_finished(winner: String):
    print("战斗结束，胜利者：", winner)
```

### Q: 如何切换不同场景的战斗？

确保场景继承 `BattleSceneBase`，并在 `_ready()` 中调用 `initialize_battle()` 和 `start_battle_flow()`。

## 许可证

本项目采用 MIT 许可证。

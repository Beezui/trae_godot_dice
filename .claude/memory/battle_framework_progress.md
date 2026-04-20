---
name: 战斗框架进度
description: 战斗框架开发进度和已完成功能
type: project
---

## 战斗框架开发进度

### 已完成功能

1. **伤害结算系统**
   - 技能命中后即时结算伤害
   - 支持公式计算（str*2 + agi*2 等）
   - fireball_skill.gd 和 blizzard_skill.gd 已实现 `_apply_damage_to_target()`

2. **投掷锁定机制**
   - 技能释放期间禁止再次投掷
   - `is_releasing_skill` 状态标志
   - 骰子复位后解锁

3. **受击效果**
   - 角色骰子原地抖动（0.16 秒）
   - 骰面切换为 hit 贴图（持续 0.5 秒）
   - 受击时调用 `take_hit_effect()`

4. **敌方角色高亮**
   - 行动前 0.5 秒高亮提示
   - 使用背面剔除 + 放大网格实现边缘光效果
   - 行动结束后移除高亮

5. **投掷方向调整**
   - 玩家：从南侧（Z=+6）向北投掷
   - 敌方：从北侧（Z=-6）向南投掷
   - 角色入场与技能投掷方向一致

6. **入场优化**
   - 玩家优先入场，敌方后入场
   - 玩家从中间位置入场（X=0）
   - 敌方随机位置入场
   - 投掷力度降低（12→8，旋转 -5~5→-3~3）

7. **余韵时间调整**
   - 玩家投掷后余韵：1.5 秒 → 1.0 秒

**DiceThrowController** 统一投掷管理：
- ✅ 蓄力功能（空格键按住蓄力，0-2 秒）
- ✅ 震动效果（蓄力期间自动震动，无需手动调用）
- ✅ 力度计算（根据蓄力时间比例）
- ✅ 多骰子同时投掷支持

**DiceResultDetector** 统一结果检测：
- ✅ 向量点积法检测骰子面值
- ✅ `wait_for_dice_stable()` 等待骰子稳定
- ✅ 超时保护（默认 5 秒）

### 核心单例系统 (Autoload)

以下 7 个单例已在 `project.godot` 中注册并正常工作：

| 单例名称 | 文件路径 | 职责 | 状态 |
|---------|---------|------|------|
| `BattleManager` | `scripts/battle/battle_manager.gd` | 战斗流程管理（回合、阶段、胜负判定） | ✅ 完成 |
| `DiceManager` | `scripts/dice/dice_manager.gd` | 骰子创建统一管理 | ✅ 完成 |
| `DiceThrowController` | `scripts/dice/dice_throw_controller.gd` | 投掷控制（蓄力 + 震动） | ✅ 完成 |
| `DiceResultDetector` | `scripts/dice/dice_result_detector.gd` | 结果检测（向量点积法） | ✅ 完成 |
| `CharacterManager` | `scripts/character/CharacterManager.gd` | 角色创建/生命周期管理 | ✅ 完成 |
| `SkillManager` | `skills/skill_manager.gd` | 技能注册/冷却/释放 | ✅ 完成 |
| `CameraManager` | `scripts/camera_manager.gd` | 摄像机配置管理 | ✅ 完成 |

### 战斗流程 (BattleManager)

**战斗阶段流程**：
```
PHASE_ENTER → PHASE_SETUP → PHASE_BATTLE → PHASE_RESOLVE → PHASE_TRANSITION
   入场          准备          战斗           结算           转换
```

**已完成功能**：
- ✅ 玩家/敌方角色入场（自动投掷）
- ✅ 技能骰子生成（隐藏，仅 UI 使用）
- ✅ 属性骰子生成（悬浮待命）
- ✅ 玩家回合/敌方回合切换
- ✅ MP 恢复与消耗
- ✅ 胜负判定
- ✅ 战斗统计

**待完成功能**：
- ⚠️ 敌方 AI 决策（当前为简单随机）
- ⚠️ 战斗奖励结算（TODO）
- ⚠️ 命运骰子转换阶段（预留接口）

### UI 系统 (BattleSkillBar)

**已完成功能**：
- ✅ 技能按钮列表（垂直排列，TextureButton）
- ✅ 技能图标加载（从 skill.json 读取）
- ✅ 空格键投掷（按下蓄力，松开投掷）
- ✅ 蓄力提示显示（百分比）
- ✅ 属性骰子复位（各自初始位置，已修复重合 bug）
- ✅ MP 显示与消耗
- ✅ 回合显示

**已修复问题**：
- ✅ 属性骰子重置位置重合 → 使用 Dictionary 记录各自初始位置
- ✅ 技能骰子结果检测 → 确认使用 DiceResultDetector

### 角色系统

**CharacterManager** 角色管理：
- ✅ 从 hero.csv/json 加载配置
- ✅ 创建玩家/敌方角色
- ✅ 角色骰子关联
- ✅ 角色状态管理（HP、MP、存活/阵亡）

**角色类继承**：
```
BaseCharacter (基类)
├── PlayerCharacter (玩家角色)
└── EnemyCharacter (敌方角色)
```

### 技能系统

**SkillManager** 技能管理：
- ✅ 从 skill.csv 自动注册技能
- ✅ 技能冷却时间管理
- ✅ 技能执行接口

**已实现技能**：
- ✅ `fireball_skill.gd` - 火球术（10001）
- ✅ `blizzard_skill.gd` - 暴风雪（10002）
- ✅ `skill_base.gd` - 技能基类

### 场景系统

**BattleSceneBase** 战斗场景基类：
- ✅ 沙盘搭建（地面 + 4 面墙）
- ✅ 摄像机配置
- ✅ UI 容器
- ✅ 战斗流程集成

**测试场景**：
- ✅ `battle_test_scene.tscn` - 战斗测试场景（主场景）
- ✅ `character_test_arena.gd` - 角色测试场景
- ✅ `skill_dice_test.tscn` - 技能骰子测试场景
- ✅ `attr_dice_test.tscn` - 属性骰子测试场景

### 配置文件

**已提交配置文件**：
| 配置文件 | 说明 | 状态 |
|---------|------|------|
| `table/hero.csv` + `table/hero.json` | 英雄配置（属性、技能、贴图） | ✅ |
| `table/AttrDices.csv` + `.json` | 属性骰子配置 | ✅ |
| `table/SkillDices.csv` + `.json` | 技能骰子配置 | ✅ |
| `table/skill.csv` + `.json` | 技能配置 | ✅ |
| `table/boss.csv` + `.json` | Boss 配置 | ✅ |
| `table/random_nodes.csv` + `.json` | 随机节点配置 | ✅ |
| `table/骰子面配置.csv` | 骰子面配置 | ✅ |

### 文档

**已创建文档**：
- ✅ `docs/battle_framework_guide.md` - 完整使用指南（GitHub 发布版）
- ✅ `.claude/memory/battle_framework.md` - 参考文档（速查表）
- ✅ `.claude/MEMORY.md` - 记忆索引

---

## 待完成功能

### 高优先级

1. **敌方 AI 完善**
   - 当前：简单随机选择技能
   - 需要：基于 MP、技能冷却、战况的决策逻辑

2. **战斗奖励结算**
   - `_resolve_rewards()` 方法待实现
   - 需要根据关卡节点配置发放奖励

3. **命运骰子转换**
   - `PHASE_TRANSITION` 阶段待实现
   - 需要调用 `DestinyDiceManager`

### 中优先级

4. **物品骰子系统**
   - `BattleManager.item_dices` 预留
   - `battle_skill_bar.gd` 物品栏 UI 预留

5. **技能冷却 UI 显示**
   - 当前 SkillManager 有冷却功能
   - 缺少 UI 显示

6. **战斗动画系统**
   - 技能释放动画待完善
   - 受击动画待添加

### 低优先级

7. **多人游戏支持**
   - 当前为单机设计
   - 如需联机需要重构网络层

8. **存档系统**
   - 战斗进度保存
   - 角色状态保存

---

## 技术债务

### 已知问题

1. **BattleManager 代码复杂度**
   - `_enemy_throw_dice()` 方法较长（~80 行）
   - 建议：拆分为更小的私有方法

2. **DiceCSVReader 依赖**
   - 多处代码 `DiceCSVReader.new()` 创建新实例
   - 建议：改为单例或缓存

3. **技能参数传递**
   - `params` 字典结构不统一
   - 建议：定义 SkillParams 类

### 代码优化建议

1. **统一错误处理**
   - 当前部分方法返回 `null`，部分 `push_error()`
   - 建议：统一错误处理策略

2. **信号管理**
   - 部分信号连接未断开
   - 建议：使用 `RefCounted` 或添加 `_cleanup()` 方法

---

## 项目文件结构

```
晋升吧骰子/
├── scripts/                      # 核心脚本
│   ├── battle/                   # 战斗系统
│   │   ├── battle_manager.gd     # 战斗管理器
│   │   └── battle_scene_base.gd  # 战斗场景基类
│   ├── dice/                     # 骰子系统
│   │   ├── dice_manager.gd       # 骰子管理器
│   │   ├── dice_throw_controller.gd  # 投掷控制器
│   │   ├── dice_result_detector.gd   # 结果检测器
│   │   └── strategies/           # 骰子策略
│   ├── character/                # 角色系统
│   │   ├── CharacterManager.gd   # 角色管理器
│   │   ├── BaseCharacter.gd      # 角色基类
│   │   ├── PlayerCharacter.gd    # 玩家角色
│   │   └── EnemyCharacter.gd     # 敌方角色
│   ├── levels/                   # 关卡系统
│   ├── ui/                       # UI 系统
│   └── test/                     # 测试脚本
├── skills/                       # 技能实现
│   ├── skill_manager.gd
│   ├── skill_base.gd
│   ├── fireball_skill.gd
│   └── blizzard_skill.gd
├── scenes/                       # 场景文件
│   ├── battle/
│   ├── test/
│   └── ui/
├── table/                        # 配置文件
│   ├── hero.csv / hero.json
│   ├── skill.csv / skill.json
│   ├── AttrDices.csv / .json
│   ├── SkillDices.csv / .json
│   └── ...
├── textures/                     # 贴图资源
└── docs/                         # 文档
    └── battle_framework_guide.md
```

---

## 下次开发建议

### 启动检查清单

1. 打开 Godot 编辑器
2. 确认无编译错误
3. 运行 `scenes/test/battle_test_scene.tscn` 测试战斗流程
4. 测试投掷功能（空格键蓄力 + 投掷）
5. 测试技能释放

### 建议开发顺序

1. **完善敌方 AI**（提升战斗可玩性）
2. **实现奖励结算**（完成战斗闭环）
3. **添加更多技能**（丰富战斗内容）
4. **优化 UI 体验**（提升视觉效果）

---

## 相关链接

- GitHub 仓库：https://github.com/Beezui/trae_godot_dice
- 战斗框架文档：`docs/battle_framework_guide.md`
- 参考文档（速查表）：`.claude/memory/battle_framework.md`

### 最后更新
2026-04-19

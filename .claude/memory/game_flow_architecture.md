---
name: 游戏完整流程架构
description: 从游戏开始到结束的完整流程架构设计，包含 8 个开发任务和流程衔接说明
type: reference
---

# 游戏完整流程架构

**文档创建时间**: 2026-04-20  
**详细文档**: `docs/游戏流程开发计划.md`

---

## 完整游戏流程图

```
[标题界面] → [角色选择界面] → [游戏主入口场景]
                                      │
                                      ▼
                                 [生成关卡网]
                                      │
                                      ▼
                              [进入初始关卡节点]
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    关卡内流程循环                            │
│                                                              │
│         ┌────────────┐                                       │
│         │ 判断节点类型 │                                       │
│         └─────┬──────┘                                       │
│               │                                               │
│    ┌──────────┼──────────┬─────────────┐                     │
│    ▼          ▼          ▼             ▼                     │
│ [战斗节点] [奇遇节点] [交易节点]   [奖励节点]                │
│    │          │          │             │                     │
│    │       (待开发)   (待开发)     (待开发)                   │
│    ▼                                                         │
│ [生成敌人] ✅                                                  │
│    │                                                         │
│ [开始战斗] ✅                                                  │
│    │                                                         │
│ [战斗进行] ✅                                                  │
│    │                                                         │
│ [战斗结束] ✅                                                  │
│    │                                                         │
│ [奖励结算] ⚠️                                                 │
│    │                                                         │
│ [投掷命运骰子] ⚠️                                              │
│    │                                                         │
│ [选择下一节点] ✅                                              │
│    │                                                         │
│ └───────────────┘ (返回判断节点类型)                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
[终局节点]
    │
    ▼
[游戏结算界面]
    │
    ▼
[返回标题/重新开始]
```

---

## 当前状态评估

### ✅ 已完成的核心组件

| 组件 | 文件 | 状态 |
|------|------|------|
| 战斗管理器 | `scripts/battle/battle_manager.gd` | ✅ 完成 |
| 战斗场景基类 | `scripts/battle/battle_scene_base.gd` | ✅ 完成 |
| 关卡生成器 | `scripts/levels/level_generator_core.gd` | ✅ 完成 |
| 关卡场景管理 | `scripts/levels/level_stage.gd` | ✅ 完成 |
| 关卡转换控制器 | `scripts/levels/level_transition_controller.gd` | ✅ 完成 |
| 命运骰子管理器 | `scripts/levels/destiny_dice_manager.gd` | ✅ 完成 |
| 敌人选择器 | `scripts/levels/enemy_selector.gd` | ✅ 完成 |
| 场景配置管理 | `scripts/levels/level_scene_config.gd` | ✅ 完成 |
| NPC 生成器 | `scripts/levels/npc_spawner.gd` | ✅ 完成 |

### ⚠️ 待完成的衔接工作

| 问题 | 说明 |
|------|------|
| 缺少游戏主入口 | 没有场景负责启动游戏流程 |
| 场景架构分离 | 普通场景继承 `关卡模板.gd`，战斗场景需要继承 `BattleSceneBase` |
| 战斗与转换未衔接 | 战斗结束后未自动触发命运骰子 |
| 奖励结算未实现 | `_resolve_rewards()` 方法待实现 |
| 角色选择未实现 | 没有玩家选择角色的 UI/流程 |

---

## 开发任务列表

### 第一阶段：基础架构整合

| 任务 | 目标 | 状态 |
|------|------|------|
| 任务 1 | 创建游戏主入口场景 | ⏳ 待开发 |
| 任务 2 | 统一场景架构（创建 LevelSceneBase） | ⏳ 待开发 |
| 任务 3 | 实现场景类型分发逻辑 | ⏳ 待开发 |

### 第二阶段：战斗流程衔接

| 任务 | 目标 | 状态 |
|------|------|------|
| 任务 4 | 实现战斗奖励结算 | ⏳ 待开发 |
| 任务 5 | 衔接战斗结束与命运骰子 | ⏳ 待开发 |

### 第三阶段：游戏入口与出口

| 任务 | 目标 | 状态 |
|------|------|------|
| 任务 6 | 创建角色选择界面 | ⏳ 待开发 |
| 任务 7 | 创建标题界面 | ⏳ 待开发 |
| 任务 8 | 创建游戏结算界面 | ⏳ 待开发 |

---

## 关键设计决策

### 1. 统一场景架构

**问题**: 普通场景和战斗场景继承不同的基类，导致流程整合困难

**解决方案**: 创建 `LevelSceneBase` 作为所有场景的统一基类
- `LevelSceneBase` 包含基础系统（摄像机、光照、边界、可视系统）
- `BattleSceneBase` 继承 `LevelSceneBase`，添加战斗特有系统
- 普通场景模板也继承 `LevelSceneBase`

### 2. 场景处理器模式

**问题**: 不同节点类型需要不同的初始化逻辑

**解决方案**: 使用 `SceneHandlerBase` 模式
- `CombatSceneHandler` 处理战斗场景初始化
- `AdventureSceneHandler` 处理奇遇场景（待实现）
- `TradeSceneHandler` 处理交易场景（待实现）
- `RewardSceneHandler` 处理奖励场景（待实现）

### 3. 战斗与命运骰子衔接

**问题**: 战斗结束后需要自动触发命运骰子流程

**解决方案**: 通过信号连接
- `BattleSceneBase._on_battle_finished` 检测战斗结束
- 胜利后延迟 2 秒调用 `LevelTransitionController.start_destiny_dice_flow`
- 命运骰子投掷完成后切换场景

---

## 测试检查清单

### 完整流程测试

- [ ] 启动游戏显示标题界面
- [ ] 点击开始游戏进入角色选择
- [ ] 选择角色后点击确认开始游戏
- [ ] 关卡网成功生成
- [ ] 正确加载初始关卡场景
- [ ] 战斗节点正确触发战斗
- [ ] 战斗框架正常工作（投掷、技能、结算）
- [ ] 战斗胜利后显示奖励
- [ ] 奖励后自动触发命运骰子
- [ ] 投掷命运骰子选择下一节点
- [ ] 正确切换到下一节点场景
- [ ] 到达终点后显示游戏结算
- [ ] 返回标题/重新开始正常工作

### 边界情况测试

- [ ] 战斗失败后的处理
- [ ] 无下一节点时的结算
- [ ] 关卡网生成失败的处理
- [ ] 场景加载失败的处理

---

## 相关文件索引

### 核心单例
- `scripts/battle/battle_manager.gd`
- `scripts/battle/battle_scene_base.gd`
- `scripts/levels/level_stage.gd`
- `scripts/levels/level_transition_controller.gd`
- `scripts/levels/destiny_dice_manager.gd`
- `scripts/levels/enemy_selector.gd`
- `scripts/levels/level_generator_core.gd`
- `scripts/levels/level_scene_config.gd`

### 配置文件
- `table/hero.json` - 角色配置
- `table/scenes.json` - 场景配置
- `table/random_nodes.json` - 随机节点配置

### 测试场景
- `scenes/test/battle_test_scene.gd` - 战斗测试
- `scenes/test/level_stage_test.gd` - 关卡阶段测试

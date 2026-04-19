---
name: 关卡类型开发进度
description: 四种关卡类型（战斗、奇遇、交易、奖励）开发进度与架构设计
type: project
---

# 关卡类型开发进度

**更新日期**: 2026-04-19

## 开发策略

- 分步开发：每个类型关卡开发完成通过测试后继续下一个
- 单例模式：使用全局通用形式
- 各类型互不影响
- 已完成的节点与 3D 关卡映射功能集成

## 架构设计：混合方案

```
scripts/levels/
├── level_manager.gd              # 统一入口单例（协调器，约 200 行）[待创建]
├── types/
│   ├── combat_level_handler.gd   # 战斗关卡处理器 [待创建]
│   ├── adventure_level_handler.gd # 奇遇关卡处理器 [待开发]
│   ├── trade_level_handler.gd    # 交易关卡处理器 [待开发]
│   └── reward_level_handler.gd   # 奖励关卡处理器 [待开发]
```

## 当前进度

### ✅ 已完成 - 战斗关卡基础框架

**核心组件**:
- `BattleManager` (Autoload 单例) - 战斗流程管理
- `BattleSceneBase` - 战斗场景基类
- `BattleSkillBar` - 技能栏 UI
- `EnemySelector` (Autoload 单例) - 敌人选择器

**敌人系统**:
- hero.csv 新增 `type` 和 `stage` 列
  - type: 1=玩家，2=普通敌人，3=精英敌人，4=Boss
  - stage: 1-4，表示从该阶段开始出现
- EnemySelector 根据阶段随机选择敌人
  - 只选择 stage <= 当前阶段的敌人
  - 同 stage 敌人权重 ×2
  - 每关卡固定 1 个敌人

**战斗流程**:
1. 入场阶段 - 敌方和玩家角色入场（自动投掷）
2. 准备阶段 - 生成技能骰子、属性骰子
3. 战斗阶段 - 回合制战斗（玩家回合→敌方回合）
4. 结算阶段 - 胜负判定、奖励结算
5. 转换阶段 - 投掷命运骰子进入下一关

**待完善内容** (战斗关卡):
- [ ] 敌人配置完善（技能、AI 行为）
- [ ] MP 消耗计算逻辑
- [ ] 战斗日志系统
- [ ] 伤害数字显示
- [ ] 技能特效完善

### ⏳ 待开发 - 其他关卡类型

| 类型 | 状态 | 预计玩法 |
|------|------|----------|
| 奇遇关卡 | 待开发 | 根据投掷结果结算剧情/事件效果 |
| 交易关卡 | 待开发 | 生成商人 NPC + 商店 UI，玩家购买道具 |
| 奖励关卡 | 待开发 | 投掷骰子，根据结果获得奖励 |

## 核心文件列表

### 战斗关卡相关
- `scripts/battle/battle_manager.gd`
- `scripts/battle/battle_scene_base.gd`
- `scripts/ui/battle_skill_bar.gd`
- `scripts/levels/enemy_selector.gd`

### 关卡生成相关
- `scripts/levels/level_generator_core.gd`
- `scripts/levels/level_stage.gd`
- `scripts/levels/level_transition_controller.gd`
- `scripts/levels/destiny_dice_manager.gd`

### 配置文件
- `table/hero.json` - 角色配置（含敌人）
- `table/boss.json` - Boss 配置
- `table/scenes.json` - 场景配置
- `table/skill.json` - 技能配置

## 下一步计划

1. 等待战斗关卡完善需求
2. 完善战斗关卡细节
3. 开发奇遇关卡
4. 开发交易关卡
5. 开发奖励关卡
6. 整合测试

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

### 核心文件

- `scripts/battle/battle_manager.gd` - 战斗流程管理
- `scripts/ui/battle_skill_bar.gd` - 技能栏 UI 与投掷控制
- `scenes/dice_6.gd` - 骰子逻辑（受击效果、高亮效果）
- `scripts/character/BaseCharacter.gd` - 角色逻辑（伤害结算）
- `skills/fireball_skill.gd` - 火球技能（伤害结算）
- `skills/blizzard_skill.gd` - 冰风暴技能（伤害结算）

### 最后更新
2026-04-19

---
name: 敌人选择器设计文档
description: EnemySelector 单例的实现逻辑和使用方式
type: reference
---

# EnemySelector 设计文档

**文件**: `scripts/levels/enemy_selector.gd`

## 功能

根据当前关卡阶段从 hero.csv 中随机选择敌人。

## 核心规则

1. **类型筛选**: 只选择 type >= 2 的敌人（排除玩家角色）
   - type=1: 玩家角色
   - type=2: 普通敌人
   - type=3: 精英敌人
   - type=4: Boss

2. **阶段筛选**: 只选择 stage <= 当前阶段的敌人
   - 例如：阶段 2 可以选择 stage=1 或 stage=2 的敌人
   - 阶段 1 只能选择 stage=1 的敌人

3. **权重计算**: 同 stage 敌人权重 ×2
   - 例如：当前阶段 2，stage=2 的敌人权重是 stage=1 的 2 倍

## API 使用

```gdscript
# 获取单例
var enemy_selector = EnemySelector.get_instance()

# 加载敌人池（根据阶段）
enemy_selector.load_enemy_pool(stage)

# 随机选择一个敌人
var enemy_config = enemy_selector.select_enemy(stage)

# 清空缓存
enemy_selector.clear()
```

## 返回数据结构

```json
{
    "id": "2",
    "name": "test_enemy",
    "type": 2,
    "stage": 1,
    "attr_str": ["2", "2", "4", "4", "5", "5"],
    "attr_agi": ["1", "3", "3", "3", "5", "5"],
    "attr_int": ["1", "1", "2", "2", "3", "3"],
    "attr_hp": "100",
    "attr_mp": "50",
    ...
}
```

## 集成位置

- `BattleManager._load_enemy_characters()` - 战斗关卡加载敌人时调用
- `LevelGeneratorCore._create_layer_node()` - 创建节点时存储 stage 信息

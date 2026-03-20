# 角色系统开发 Spec

## Why

当前项目已有英雄配置系统（hero.csv/hero.json）和属性骰子系统，但缺少统一的角色管理器来管理角色的创建、生命周期和状态。需要建立一个独立的角色管理系统，使得角色可以脱离具体场景存在，并支持在不同场景间复用。

## What Changes

- 创建角色管理器（CharacterManager）作为 Autoload 单例
- 创建角色基类（BaseCharacter）定义角色通用属性
- 创建玩家角色类（PlayerCharacter）继承自基类
- 创建敌人角色类（EnemyCharacter）继承自基类
- 新建角色测试场景（character_test_arena.tscn）
- 实现角色与骰子的关联机制
- 实现角色血量 UI 显示在骰子上

## Impact

- **Affected specs**: 骰子使用方式、技能系统、属性骰子系统
- **Affected code**: 
  - 新增：`scripts/character/` 目录
  - 新增：`scenes/character_test_arena.tscn` 测试场景
  - 修改：`project.godot`（添加 Autoload 配置）
  - 复用：现有的 `attr_dice.gd`、`dice_6.gd`、`skill_manager.gd`

## ADDED Requirements

### Requirement: 角色管理器
The system SHALL provide a global CharacterManager (Autoload singleton) that:
- Manages all character instances by hero ID
- Provides methods to create, get, and remove characters
- Handles character lifecycle across scenes
- Maintains character state persistence

#### Scenario: Create player character
- **WHEN** game starts with hero_id = 1
- **THEN** CharacterManager creates a PlayerCharacter instance
- **AND** the character is associated with hero data from hero.json
- **AND** the character's attribute dices are created and positioned

### Requirement: 角色基类
The system SHALL provide a BaseCharacter class that:
- Stores hero_id, name, attributes (str/agi/int/hp)
- References to character dice, attribute dices, and skill dices
- Provides methods for damage calculation and state management
- Does NOT depend on any specific scene

### Requirement: 玩家角色类
The system SHALL provide a PlayerCharacter class that:
- Inherits from BaseCharacter
- Marks the character as player-controlled
- Enables skill dice and attribute dice interaction
- Persists state across scene transitions

### Requirement: 敌人角色类
The system SHALL provide an EnemyCharacter class that:
- Inherits from BaseCharacter
- Marks the character as enemy-controlled
- Hides skill/attribute dices from the board (for future UI display)

### Requirement: 角色测试场景
The system SHALL provide a test scene (character_test_arena.tscn) that:
- Uses hero_id = 1 as the player character
- Includes dice throwing functionality
- Includes dice result detection
- Does NOT affect other existing scenes
- Shows HP UI on the character dice

### Requirement: 血量 UI 显示
The system SHALL display HP on the character dice:
- Uses a simple UI overlay on the dice
- Shows current HP / max HP
- Updates in real-time when damage is taken

## MODIFIED Requirements

### Requirement: 角色使用方式 (from 角色系统.md)
**Original**: 必须具备一个场景

**Modified**: 角色系统独立于场景，通过 CharacterManager 统一管理。场景只需从 CharacterManager 获取角色实例并显示。

### Requirement: 入场机制
**Original**: 生成后以投掷形式入场

**Modified**: 角色创建由 CharacterManager 负责，入场投掷动画由场景控制，但角色本身不依赖场景。

## REMOVED Requirements

None - all existing functionality will be preserved and extended.

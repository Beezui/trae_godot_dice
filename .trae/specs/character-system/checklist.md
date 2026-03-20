- [x] Task 1: 创建角色系统目录结构和基础文件
  - [x] Subtask 1.1: 创建 `scripts/character/` 目录
  - [x] Subtask 1.2: 创建 `BaseCharacter.gd` 角色基类
  - [x] Subtask 1.3: 创建 `PlayerCharacter.gd` 玩家角色类
  - [x] Subtask 1.4: 创建 `EnemyCharacter.gd` 敌人角色类
  - [x] Subtask 1.5: 创建 `CharacterManager.gd` 角色管理器（Autoload）

- [x] Task 2: 配置 Autoload 单例
  - [x] Subtask 2.1: 读取 `project.godot` 文件
  - [x] Subtask 2.2: 添加 CharacterManager 到 Autoload 配置
  - [x] Subtask 2.3: 验证配置正确性

- [x] Task 3: 创建角色测试场景
  - [x] Subtask 3.1: 创建 `scenes/character_test_arena.tscn` 场景文件
  - [x] Subtask 3.2: 创建 `scenes/character_test_arena.gd` 场景脚本
  - [x] Subtask 3.3: 实现投掷功能集成
  - [x] Subtask 3.4: 实现结果检测集成
  - [x] Subtask 3.5: 添加摄像机、灯光、沙盘等基础设置

- [x] Task 4: 实现角色血量 UI 显示
  - [x] Subtask 4.1: 创建 HP 显示 UI 组件（Label 或 TextureRect）
  - [x] Subtask 4.2: 实现 HP 绑定到角色数据
  - [x] Subtask 4.3: 实现 HP 更新逻辑
  - [x] Subtask 4.4: 测试 HP 显示效果

- [x] Task 5: 集成角色系统与现有系统
  - [x] Subtask 5.1: 角色与属性骰子关联
  - [x] Subtask 5.2: 角色与技能骰子关联
  - [x] Subtask 5.3: 使用 hero_id = 1 创建示例角色
  - [x] Subtask 5.4: 测试角色创建和初始化流程

- [x] Task 6: 测试与验证
  - [x] Subtask 6.1: 测试角色创建功能
  - [x] Subtask 6.2: 测试投掷功能
  - [x] Subtask 6.3: 测试结果检测功能
  - [x] Subtask 6.4: 测试 HP UI 显示
  - [x] Subtask 6.5: 验证不影响其他场景

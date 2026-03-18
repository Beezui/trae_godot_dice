# 属性骰子系统 - 实施计划

## 项目概述

实现属性骰子系统，支持力量、敏捷、智力三种属性骰子，根据角色属性动态生成和更新。

## 实施任务列表

### [x] 任务 1: 设计属性骰子类
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 创建 `attr_dice.gd` 类，继承自基础骰子类
  - 实现属性骰子的核心功能
  - 支持动态更新属性值和贴图
- **Success Criteria**:
  - 属性骰子类能够正确创建和初始化
  - 支持力量、敏捷、智力三种属性类型
  - 能够根据角色属性动态更新骰子面
- **Test Requirements**:
  - `programmatic` TR-1.1: 属性骰子能正确初始化并显示对应属性的面
  - `programmatic` TR-1.2: 属性骰子能响应角色属性变化并更新

### [x] 任务 2: 实现属性骰子管理器
- **Priority**: P0
- **Depends On**: 任务 1
- **Description**:
  - 创建 `attr_dice_manager.gd` 作为 Autoload
  - 管理所有属性骰子的创建和生命周期
  - 提供属性骰子的创建和获取接口
- **Success Criteria**:
  - 管理器能够为角色创建属性骰子
  - 能够根据角色ID获取对应的属性骰子
  - 支持属性骰子的动态更新
- **Test Requirements**:
  - `programmatic` TR-2.1: 能为指定角色创建属性骰子
  - `programmatic` TR-2.2: 能根据角色ID获取属性骰子

### [x] 任务 3: 实现角色属性读取
- **Priority**: P1
- **Depends On**: 任务 1
- **Description**:
  - 创建 `hero_csv_reader.gd` 读取角色配置
  - 支持从 hero.json 读取角色属性数据
  - 提供角色属性查询接口
- **Success Criteria**:
  - 能正确读取角色配置文件
  - 能获取角色的力量、敏捷、智力属性
  - 能获取角色的骰子贴图路径
- **Test Requirements**:
  - `programmatic` TR-3.1: 能读取并解析 hero.json 文件
  - `programmatic` TR-3.2: 能获取指定角色的属性数据

### [x] 任务 4: 实现属性值格式化
- **Priority**: P1
- **Depends On**: 任务 1
- **Description**:
  - 实现属性值的字符串格式化功能
  - 支持数值缩写（如 1000 → 1k）
  - 确保格式化后的字符串正确显示
- **Success Criteria**:
  - 大数值能正确缩写
  - 格式化后的字符串符合要求
  - 能处理各种数值范围
- **Test Requirements**:
  - `programmatic` TR-4.1: 1000 正确显示为 1k
  - `programmatic` TR-4.2: 1500 正确显示为 1.5k

### [x] 任务 5: 创建属性骰子测试场景
- **Priority**: P0
- **Depends On**: 任务 1, 任务 2, 任务 3
- **Description**:
  - 创建 `attr_dice_test.tscn` 测试场景
  - 使用角色 ID 1 的属性数据
  - 实现属性骰子的投掷和结果显示
- **Success Criteria**:
  - 测试场景能正确加载
  - 能显示角色的属性骰子
  - 能执行属性骰子的投掷和结果判定
- **Test Requirements**:
  - `human-judgement` TR-5.1: 场景加载正常，骰子显示正确
  - `programmatic` TR-5.2: 骰子投掷后能正确显示结果

### [x] 任务 6: 实现属性骰子与技能系统集成
- **Priority**: P1
- **Depends On**: 任务 1, 任务 2
- **Description**:
  - 对接现有技能系统，确保属性骰子结果能被技能正确读取
  - 测试技能与属性骰子的交互
  - 验证伤害计算是否正确反映属性值
- **Success Criteria**:
  - 技能能正确获取属性骰子的结果
  - 伤害计算正确反映属性值
  - 集成测试通过
- **Test Requirements**:
  - `programmatic` TR-6.1: 技能能正确读取属性骰子结果
  - `programmatic` TR-6.2: 伤害计算正确反映属性值

### [x] 任务 7: 测试和优化
- **Priority**: P2
- **Depends On**: 所有任务
- **Description**:
  - 进行全面的功能测试
  - 优化性能和稳定性
  - 修复可能的bug
- **Success Criteria**:
  - 所有测试用例通过
  - 系统运行稳定
  - 性能符合要求
- **Test Requirements**:
  - `programmatic` TR-7.1: 所有功能测试通过
  - `human-judgement` TR-7.2: 系统运行流畅

## 技术实现要点

1. **属性骰子类设计**:
   - 继承自基础骰子类
   - 增加属性类型和角色ID字段
   - 实现动态更新方法

2. **资源管理**:
   - 从角色配置中读取贴图路径
   - 缓存已加载的贴图
   - 确保资源正确释放

3. **属性更新机制**:
   - 监听角色属性变化
   - 自动更新骰子面
   - 保持数据一致性

4. **场景独立性**:
   - 不依赖特定场景结构
   - 通过参数传递所需数据
   - 支持在任何场景中使用

5. **测试策略**:
   - 使用角色 ID 1 进行测试
   - 验证属性值的动态更新
   - 测试与技能系统的集成

## 预期输出

- 完整的属性骰子系统
- 可独立使用的属性骰子类
- 与技能系统的无缝集成
- 功能完备的测试场景
- 详细的使用文档

## 时间估计

- 任务 1: 1 天
- 任务 2: 0.5 天
- 任务 3: 0.5 天
- 任务 4: 0.5 天
- 任务 5: 1 天
- 任务 6: 0.5 天
- 任务 7: 0.5 天

总计: 4.5 天
# 工作进度报告

## 更新日期
2026-04-22

## 项目状态
- **分支**: master
- **与远程同步**: 已同步
- **开发阶段**: 游戏主入口流程与地图 UI 优化

---

## 已完成功能

### 1. 节点网与关卡配置系统
- [x] 节点类型定义 (`level_node_type.gd`)
  - 战斗、奇遇、交易、奖励四种节点类型
  - 类型颜色和名称映射
- [x] 关卡场景配置 (`level_scene_config.gd`)
  - 从 random_nodes.json 读取配置
  - 从 scenes.json 加载场景映射
  - 权重随机选择场景
- [x] 关卡阶段管理 (`level_stage.gd`)
  - 动态加载/卸载关卡场景
  - 场景切换流程
  - NPC 生成管理
- [x] NPC 生成器 (`npc_spawner.gd`)
  - 从 hero.json 读取角色配置
  - 动态生成 NPC 到场景中

### 2. 关卡场景映射系统
- [x] 节点类型 → random_nodes.json → scenes.json → 3D 场景
- [x] 场景动态实例化并添加为 LevelStage 子节点
- [x] 切换节点时自动清理旧场景

### 3. 命运骰子系统
- [x] 命运骰子管理器 (`destiny_dice_manager.gd`)
- [x] 命运骰子配置生成
- [x] 投掷结果处理
- [x] 根据投掷结果选择节点

### 4. 地图预览功能
- [x] 关卡地图 UI (`level_map_display.tscn`)
  - 节点可视化显示
  - 连接线绘制
  - 可拖动查看
- [x] M 键开关地图显示

### 5. 游戏主入口流程
- [x] 游戏主入口场景 (`game_main.tscn`)
  - 标题场景 → 角色选择 → 游戏主入口完整流程
  - 沙盘环境搭建
  - 玩家角色生成
  - 命运骰子生成与投掷
  - 地图 UI 覆盖层集成
- [x] 关卡转换系统 (`level_transition_controller.gd`)
  - LoadingOverlay 加载动画
  - 场景平滑切换

### 6. 测试场景功能
- [x] level_stage_test.tscn 功能完善
  - 按 M 键 - 开关地图
  - 按 T 键 - 投掷命运骰子
  - 按 N 键 - 切换下一节点
  - 按 R 键 - 重载当前节点

---

## 已修复问题

### 1. 地图拖动问题（2026-04-22 修复）
**问题描述**: 命运骰子地图覆盖层无法拖动，日志显示 `canvas_offset` 在变化但视觉不动

**根本原因**:
1. 拖动算法错误：`drag_start_position = mouse_pos - canvas_offset` 导致 `canvas_offset` 永远不变
2. UI 重复创建：`_create_ui()` 被多次调用，导致多个子节点堆叠
3. 布局系统覆盖位置：即使设置 `layout_mode = 0`，Godot 仍可能覆盖 `position`

**解决方案**:
1. 修正拖动算法：`drag_start_position = get_local_mouse_position() - canvas.position`
2. 添加 `ui_created` 标志防止重复创建 UI
3. 使用 `call_deferred("_force_position_after_layout")` 强制应用位置
4. 使用 `set_position()` 和 `set_size()` 绕过布局系统

**文件**: `scripts/ui/destiny_dice_map_overlay.gd`

### 2. 重复场景问题（严重）
**问题描述**: 运行时出现两组地面和围墙，一组包含命运骰子，另一组包含角色骰子、技能骰子、属性骰子

**根本原因**: 
- `npc_spawner.gd` 使用 `character_test_arena.tscn` 作为 NPC 场景
- `character_test_arena` 是完整测试场景，包含地面、围墙、摄像机、光照和各种骰子
- 每个 NPC 都实例化一个完整场景

**解决方案**:
- 创建 `npc_scene.tscn` 简易场景（仅包含角色节点）
- 移除地面、围墙、摄像机、光照、骰子等冗余元素
- `npc_spawner.gd` 改用新的简易 NPC 场景

**提交**: b711498

### 3. 墙碰撞体位置问题
**问题描述**: 角色骰子入场投掷时与空气发生碰撞

**根本原因**:
- 四面墙碰撞体未设置位置，默认在原点 (0,0,0)
- 墙高度 50 米，范围 y=-25 到 y=25
- 骰子初始位置 Y=4 正好在墙的碰撞体内

**解决方案**:
- 为四面墙设置正确位置（场景边缘）
- 墙底部 Y=0，顶部 Y=50

**提交**: 64fd472

### 4. 主场景配置冲突
**问题描述**: F5 运行时加载错误的场景

**解决方案**:
- 统一 main_scene 和 run/main_scene 为 level_stage_test.tscn

**提交**: 8f6f76d

### 5. NPC 场景方法名冲突
**问题描述**: get_position() 和 set_position() 与 Node3D 内置方法冲突

**解决方案**:
- 重命名为 get_npc_position() 和 set_npc_position()

**提交**: 977efdf

---

## 提交记录

| 提交哈希 | 类型 | 描述 |
|---------|------|------|
| 待定 | fix | 修复地图拖动算法，使用正确的相对偏移量 |
| 977efdf | fix | 修复 NPC 场景方法名冲突 |
| b711498 | fix | 创建简易 NPC 场景解决重复场景问题 |
| 8f6f76d | fix | 统一主场景配置为 level_stage_test.tscn |
| b83530c | feat | 添加地图预览和命运骰子投掷功能 |
| 64fd472 | fix | 修复关卡场景墙碰撞体位置问题 |
| f271c4c | chore | 更新随机节点配置表 |
| 704056f | feat | 正在进行节点网与关卡配置 |

---

## 待开发功能

### 高优先级
- [ ] NPC 角色模型和交互功能
- [ ] 命运骰子投掷动画和 UI 提示
- [ ] 关卡切换时的过渡效果
- [ ] Boss 战场景处理

### 中优先级
- [ ] 技能骰子和属性骰子集成到关卡流程
- [ ] 角色与 NPC 对话系统
- [ ] 关卡事件触发机制

### 低优先级
- [ ] 地图 UI 优化（缩放、节点详情）
- [ ] 关卡配置编辑器工具
- [ ] 性能优化

---

## 文件结构

```
晋升吧骰子/
├── scripts/levels/          # 关卡系统核心脚本
│   ├── level_node.gd        # 关卡节点数据结构
│   ├── level_node_type.gd   # 节点类型枚举
│   ├── level_data.gd        # 关卡数据结构
│   ├── level_stage.gd       # 关卡场景管理器 (Autoload)
│   ├── level_scene_config.gd # 场景配置管理器
│   ├── level_transition_controller.gd # 关卡转换控制器
│   ├── npc_spawner.gd       # NPC 生成器
│   └── destiny_dice_manager.gd # 命运骰子管理器
├── scripts/ui/              # UI 系统
│   └── destiny_dice_map_overlay.gd # 命运骰子地图覆盖层
├── scripts/test/            # 测试脚本
│   └── level_stage_test.gd  # 关卡场景测试
├── scenes/
│   ├── test/
│   │   └── level_stage_test.tscn # 主测试场景
│   ├── game_main/           # 游戏主入口场景
│   │   └── game_main.tscn   # 游戏主入口
│   ├── ui/
│   │   └── level_map_display.tscn # 地图显示 UI
│   ├── 游戏场景/            # 关卡场景
│   │   ├── 村庄.tscn
│   │   ├── 熔火之窟.tscn
│   │   └── 神秘商店.tscn
│   ├── npc_scene.tscn       # 简易 NPC 场景 (新增)
│   └── npc_scene.gd         # NPC 脚本 (新增)
└── table/
    ├── random_nodes.json    # 随机节点配置
    └── scenes.json          # 场景映射配置
```

---

## 技术说明

### 关卡生成流程
1. LevelGenerator 生成关卡数据 (LevelData)
2. LevelData 包含所有节点 (LevelNode) 和连接关系
3. 每个节点有类型 (type) 用于场景选择

### 场景加载流程
1. LevelStage.load_level_scene() 接收节点数据
2. 根据节点类型从 random_nodes.json 选择配置
3. 从 scenes.json 获取场景路径
4. 实例化场景并添加为 LevelStage 子节点
5. 生成 NPC 和命运骰子

### 命运骰子流程
1. 按 T 键触发投掷
2. DestinyDiceManager 处理投掷
3. 根据投掷结果选择目标节点
4. LevelTransitionController 执行场景切换

### 地图拖动技术要点（Godot 4.x）
1. 使用 `layout_mode = 0` (POSITION) 允许手动设置位置
2. 使用 `anchors_preset = TOP_LEFT` 左上角锚点
3. 使用 `set_position()` 和 `set_size()` 比直接赋值更可靠
4. 使用 `call_deferred()` 在布局完成后再次设置位置
5. 拖动算法：保存鼠标相对控件的偏移量，而非相对 offset

---

## 备注
- 当前开发重点：完善游戏主入口流程和地图 UI
- 代码质量：生产级，可直接运行
- 注释语言：中文

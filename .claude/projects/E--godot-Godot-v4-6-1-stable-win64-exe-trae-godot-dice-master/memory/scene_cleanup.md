---
name: 场景清理机制
description: Sandbox 角色骰子和血条的统一清理机制，解决场景切换和贸易流程中的残留问题
type: project
---

## 场景清理机制

### 问题背景
Sandbox 是 game_main 的子节点，持久存在。通过 `sandbox.add_child(dice)` 添加的角色骰子和血条从未被清理，导致每次进入商店/战斗场景时残留上一次的 NPC 和角色骰子。

### 清理时机
仅在以下位置执行清理，**不在**贸易/战斗流程结束后清理（保留到命运骰子投掷完成）：

1. **`execute_transition()`（场景切换时）** — `scripts/levels/level_transition_controller.gd`
   - step 0：在加载新场景前先清理 Sandbox
   - 这是唯一正式清理点，确保角色骰子在整个命运骰子投掷阶段正常保留

2. **`_spawn_player()`（游戏初始化时）** — `scenes/game_main/game_main.gd`
   - 安全清理，防止上一次运行的残留

### 清理范围
- 所有 `dice_type == "character"` 的 RigidBody3D 骰子
- 所有加载了 `dice_health_bar_2d.gd` 脚本的血条节点（无论节点名是否被 Godot 自动重命名）

### 核心实现

**`character_enter_manager.gd`** 中的清理方法：
- `cleanup_sandbox(sandbox, dice_type, side)` — 通用清理，支持按类型和阵营过滤
- `cleanup_all_characters(sandbox)` — 清理所有角色骰子
- `cleanup_side_characters(sandbox, side)` — 清理特定阵营

**关键实现细节**：
1. 血条识别使用脚本匹配（`child.get_script() == hb_script`），不使用节点名匹配（Godot 会自动重命名重复节点名）
2. 骰子清理前调用 `_stop_dice_timers()` 停止所有 timer 并断开信号连接，防止 timer 回调在 `queue_free()` 后触发 `create_health_bar()` 创建孤儿血条
3. `Object.has_method()` 不检查脚本方法，需要使用 `get_script().has_method()` 或直接用 `call()` 调用

### 涉及的修改文件
- `scripts/character/character_enter_manager.gd` — 清理方法核心实现
- `scenes/game_main/game_main.gd` — `_cleanup_sandbox_characters()` 和 `_cleanup_sandbox_manual()` 方法
- `scripts/levels/level_transition_controller.gd` — `_cleanup_sandbox()` 方法，在 `execute_transition()` 中调用
- `scenes/dice_6.gd` — `cleanup_dice()` 方法（停止 timer、断开信号、清除血条引用）

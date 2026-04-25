---
name: 商店 UI 场景系统
description: 统一的商店 UI 场景文件，替代动态生成方式，已完成前进按钮和折扣骰子检测修复
type: project
---

## 商店 UI 场景系统

### 新创建的文件：
1. `scenes/ui/shop_ui.tscn` — 商店 UI 场景文件
   - 包含所有 UI 元素：背景、标题、金币显示、折扣显示、道具网格、折扣骰子按钮、前进按钮、提示框
   - 使用正确的锚点预设布局

2. `scripts/ui/shop_ui.gd` — 商店 UI 场景脚本
   - 处理 UI 渲染和信号
   - 提供 `update_gold()`, `update_discount()`, `populate_items()` 等方法

### 修改的文件：
1. `scripts/shop/shop_manager.gd` — 改为加载场景而非动态生成 UI
   - 新增 `_load_ui()` 函数，加载 `res://scenes/ui/shop_ui.tscn`
   - 移除旧的 `_create_ui()` 动态生成逻辑
   - `_refresh_shop_display()` 改为调用场景的 `populate_items()` 方法
   - 设置折扣后调用场景的 `update_discount()` 方法

2. `scenes/game_main/game_main.gd` — 折扣骰子检测使用统一检测器
   - `_get_discount_dice_result()` 改为调用 `DiceResultDetector.check_dice_value()`

### 关键改进：
- 商店 UI 现在通过统一场景文件管理，便于维护和扩展
- 折扣骰子检测与命运骰子使用相同的检测算法（向量点积法）
- 前进按钮已正确添加到场景中，点击后触发 `on_trade_completed` 信号结束交易
- 贸易/战斗流程结束后不再清理 Sandbox 角色，清理仅在场景切换时执行

### 已验证：
- 商店 UI 场景正确加载和显示
- 前进按钮可见且可点击，正确结束交易流程
- 折扣骰子结果检测正常（向量点积法）

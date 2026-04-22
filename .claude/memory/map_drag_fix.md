---
name: 地图拖动修复
description: 命运骰子地图覆盖层拖动问题的完整修复方案（2026-04-22）
type: feedback
---

## 地图拖动问题修复（完整版）

### 问题描述
命运骰子地图覆盖层（`destiny_dice_map_overlay.gd`）无法拖动，尽管日志显示 `canvas_offset` 在变化，但视觉上地图不动。

### 根本原因

1. **拖动算法错误**：
   ```gdscript
   # 错误的代码
   drag_start_position = mouse_pos - canvas_offset
   canvas_offset = mouse_pos - drag_start_position
   # 代入后：canvas_offset = mouse_pos - (mouse_pos - canvas_offset) = canvas_offset
   # 结果：canvas_offset 永远不会变化！
   ```

2. **UI 重复创建**：`_create_ui()` 被多次调用，导致多个子节点堆叠，尺寸混乱。

3. **布局系统覆盖位置**：即使设置了 `layout_mode = 0`，Godot 的布局系统仍可能在布局 pass 后覆盖 `position`。

### 修复方案

#### 1. 修正拖动算法
```gdscript
func _on_canvas_gui_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                is_dragging = true
                # 正确：保存鼠标相对于 canvas 左上角的偏移量
                drag_start_position = get_local_mouse_position() - canvas.position
            else:
                is_dragging = false
    elif event is InputEventMouseMotion:
        if is_dragging:
            var mouse_pos = get_local_mouse_position()
            # canvas 位置 = 鼠标位置 - 拖动开始时的偏移量
            canvas_offset = mouse_pos - drag_start_position
            _update_map_position()
```

#### 2. 防止 UI 重复创建
```gdscript
var ui_created: bool = false

func _create_ui():
    if ui_created:
        return
    ui_created = true
    # ... 创建 UI 代码
```

#### 3. 强制位置应用（防止布局覆盖）
```gdscript
func _update_map_position():
    if canvas:
        canvas.set_position(canvas_offset)
        canvas.layout_mode = 0  # POSITION
    if map_texture_rect:
        map_texture_rect.set_position(canvas_offset)
        map_texture_rect.layout_mode = 0  # POSITION
    
    # 强制在下一帧再次设置位置，防止布局系统覆盖
    call_deferred("_force_position_after_layout")

func _force_position_after_layout():
    if canvas:
        canvas.set_position(canvas_offset)
    if map_texture_rect:
        map_texture_rect.set_position(canvas_offset)
```

#### 4. 使用 set_position 和 set_size 绕过布局系统
```gdscript
func _update_canvas_size():
    if canvas:
        canvas.set_size(Vector2(map_width, map_height))
        canvas.set_position(Vector2.ZERO)
        canvas.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        canvas.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
```

### 节点结构
```
MapOverlay (Control) - 覆盖层，尺寸=屏幕尺寸
├── InfoLabel (Label) - 信息标签，layout_mode=POSITION
├── ChargeLabel (Label) - 蓄力标签，layout_mode=POSITION
├── map_texture_rect (TextureRect) - 地图纹理显示
│   ├── position = canvas_offset
│   ├── size = 地图尺寸 (9160x660)
│   ├── anchors_preset = TOP_LEFT
│   ├── layout_mode = POSITION
│   └── z_index = 1（在 canvas 上方渲染）
└── canvas (Control) - 输入捕获层
    ├── position = canvas_offset
    ├── size = 地图尺寸 (9160x660)
    ├── anchors_preset = TOP_LEFT
    ├── layout_mode = POSITION
    └── mouse_filter = MOUSE_FILTER_STOP
```

### 关键知识点

1. **Godot 4.x Control 布局系统**：
   - `layout_mode = 0` (POSITION) 允许手动设置位置和尺寸
   - `anchors_preset = TOP_LEFT` 使用左上角锚点
   - `set_position()` 和 `set_size()` 比直接赋值更可靠
   - 即使设置 `layout_mode = 0`，布局系统仍可能在下一帧覆盖，需要 `call_deferred()` 强制应用

2. **拖动算法**：
   - 正确：`drag_start_position = mouse_pos - canvas.position`（鼠标相对于控件的偏移）
   - 拖动时：`canvas_offset = mouse_pos - drag_start_position`

3. **z_index 层级**：
   - `map_texture_rect.z_index = 1` 在 canvas 上方渲染
   - `canvas.z_index = 0` 在底层接收输入

### 文件位置
- `scripts/ui/destiny_dice_map_overlay.gd`

### 相关记忆
- 地图拖动使用 `canvas_offset` 模式，配合 `call_deferred()` 防止布局覆盖
- 拖动算法：保存鼠标相对控件的偏移量，而不是相对 offset 的偏移量

---
name: 地图拖动修复
description: 命运骰子地图覆盖层拖动问题的修复方案
type: feedback
---

## 地图拖动问题修复

### 问题描述
命运骰子地图覆盖层（`destiny_dice_map_overlay.gd`）在拖动时存在两个问题：
1. 可拖动区域与地图区域不一致，操作不便
2. 拖动时会有闪烁/抖动

### 修复方案

**最终解决方案**：移除 ScrollContainer，直接使用 Control 节点绘制地图，使用 `canvas_offset` 实现拖动。

**关键代码改动**：

1. **移除 ScrollContainer**
   ```gdscript
   # 之前：使用 ScrollContainer + Canvas
   scroll_container = ScrollContainer.new()
   canvas = Control.new()
   scroll_container.add_child(canvas)
   
   # 修复后：直接使用 Canvas
   canvas = Control.new()
   canvas.mouse_filter = Control.MOUSE_FILTER_STOP
   add_child(canvas)
   ```

2. **设置 clip_contents = false**
   ```gdscript
   func _ready():
       clip_contents = false  # 允许绘制内容超出边界
   ```

3. **使用 canvas_offset 实现拖动**
   ```gdscript
   func _on_canvas_gui_input(event: InputEvent):
       if event is InputEventMouseButton:
           if event.button_index == MOUSE_BUTTON_LEFT:
               if event.pressed:
                   is_dragging = true
                   drag_start_position = event.position - canvas_offset
               else:
                   is_dragging = false
       elif event is InputEventMouseMotion:
           if is_dragging:
               canvas_offset = event.position - drag_start_position
               canvas.queue_redraw()
   ```

4. **绘制时应用 offset**
   ```gdscript
   func _on_canvas_draw():
       var canvas_x = pos.x - min_x + layer_padding + canvas_offset.x
       var canvas_y = pos.y - min_y + layer_padding + canvas_offset.y
       # 使用 canvas_x, canvas_y 绘制节点
   ```

### 为什么这样修复

1. **ScrollContainer 的问题**：
   - ScrollContainer 的滚动范围基于子节点尺寸
   - 当使用 `canvas_offset` 偏移绘制内容时，滚动范围不会自动更新
   - 导致可拖动区域（canvas 尺寸）与绘制内容（地图）不匹配

2. **直接使用 Control 的优势**：
   - `clip_contents = false` 允许绘制内容超出边界
   - `canvas_offset` 完全控制绘制位置
   - canvas 尺寸始终等于地图尺寸，可拖动区域与地图区域一致

3. **参考实现**：
   - `level_map_display.gd` 使用相同的模式
   - 拖动流畅无闪烁

### 文件位置
- `scripts/ui/destiny_dice_map_overlay.gd`

### 相关记忆
- 地图拖动使用 `canvas_offset` 模式，不要使用 ScrollContainer 的滚动功能

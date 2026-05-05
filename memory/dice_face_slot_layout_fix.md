---
name: dice_face_slot_layout_fix
description: 骰面插槽图标尺寸失控的根因和修复方案 - layout_mode 与 TextureRect 尺寸控制
type: feedback
originSessionId: f492ce46-13f4-4ad3-be87-1d866486c8d6
---
## 规则：layout_mode = 2 (VIEWPORT) 时 size_flags 被忽略，子节点无法获得正确尺寸

**为什么：** FaceSlot (ColorRect) 在 HBoxContainer 中，所有节点都设置了 `layout_mode = 2`。这导致：
1. FaceSlot 的 `size_flags_horizontal = 4` (EXPAND_FILL) 和 `size_flags_vertical = 4` 被忽略
2. FaceSlot 尺寸不由 HBoxContainer 自动分配，而是由 `custom_minimum_size` 或 `rect_size` 决定
3. TextureRect 子节点即使用 `PRESET_FULL_RECT` 锚点也无法跟随父节点尺寸
4. 技能图标 (128x128 原始纹理) 渲染时按原始尺寸显示，而不是缩放到 64x64 插槽

**修复方案：**
```tscn
# FaceSlot - 必须设置 layout_mode = 1 (PARENT) 才能让 size_flags 生效
custom_minimum_size = Vector2(64, 64)
layout_mode = 1  # 关键：从 VIEWPORT 改为 PARENT
size_flags_horizontal = 4  # EXPAND_FILL - 现在生效了
size_flags_vertical = 4    # EXPAND_FILL

# TopRow/BottomRow (HBoxContainer) - 也必须设置 layout_mode = 1
layout_mode = 1  # 关键：从 VIEWPORT 改为 PARENT
size_flags_horizontal = 4  # EXPAND_FILL
```

```gdscript
# TextureRect - 使用与技能列表一致的方式
texture_rect.stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
texture_rect.expand_mode = EXPAND_IGNORE_SIZE
texture_rect.size = Vector2(64, 64)  # 固定尺寸，与 custom_minimum_size 一致
```

**关键对比（工作 vs 不工作）：**

| 场景 | layout_mode | size_flags | 纹理尺寸控制 | 结果 |
|------|-------------|------------|-------------|------|
| 技能列表图标 (工作) | 代码创建，默认 layout_mode = 1 | 通过容器分配 | size = Vector2(50, 50) | ✓ 50x50 |
| 骰面插槽图标 (修复前) | layout_mode = 2 (VIEWPORT) | 被忽略 | STRETCH_SCALE + PRESET_FULL_RECT | ✗ 128x128 |
| 骰面插槽图标 (修复后) | layout_mode = 1 (PARENT) | 生效 | STRETCH_KEEP_ASPECT_CENTERED + size = 64x64 | ✓ 64x64 |

**Godot 4 容器布局核心规则：**
1. `layout_mode = 0` (INHERIT)：继承父节点的布局模式
2. `layout_mode = 1` (PARENT)：由父容器控制位置和尺寸，`size_flags` 生效
3. `layout_mode = 2` (VIEWPORT)：自己控制位置和尺寸，`size_flags` **被完全忽略**

**tscn 中的陷阱：**
- 在 Godot 4 中，`.tscn` 文件导出的节点**默认** `layout_mode = 2` (VIEWPORT)
- 这导致从场景文件创建的 UI 节点，即使设置了 `size_flags` 也不会被容器分配尺寸
- **必须显式设置** `layout_mode = 1` (PARENT) 才能让容器布局生效

**TextureRect 尺寸控制方式对比：**
| stretch_mode | expand_mode | 尺寸控制 | 适用场景 |
|--------------|-------------|---------|---------|
| STRETCH_SCALE | - | 由容器/锚点决定，强制拉伸 | 需要填满容器，不关心 aspect |
| STRETCH_KEEP_ASPECT | - | 由容器决定，保持 aspect | 需要适应容器且保持比例 |
| STRETCH_KEEP_ASPECT_CENTERED | EXPAND_IGNORE_SIZE | 由 `size` 属性决定 | **精确控制尺寸**（如 50x50、64x64）|
| STRETCH_KEEP_ASPECT_CENTERED | EXPAND_KEEP_WIDTH/HEIGHT | 由容器决定 | 单方向扩展 |

**如何应用：**
1. 在 `.tscn` 中使用 Container 布局子节点时，**必须设置** `layout_mode = 1`
2. 需要精确控制 TextureRect 尺寸时，使用 `STRETCH_KEEP_ASPECT_CENTERED + EXPAND_IGNORE_SIZE + size = Vector2(w, h)`
3. 发现子节点尺寸异常时，首先检查 `layout_mode` 是否为 1

**调试技巧：**
```gdscript
print("slot size=", slot.size, " custom_min_size=", slot.custom_minimum_size)
print("texture size=", texture_rect.size, " stretch_mode=", texture_rect.stretch_mode)
```

如果 `slot.size` 为 `(0, 0)` 或远大于预期，检查：
1. `layout_mode` 是否为 1
2. 父容器的 `layout_mode` 是否也为 1
3. 是否有足够的 `custom_minimum_size` 或 `size_flags`

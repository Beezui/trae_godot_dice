---
name: 2D 血条实现方案
description: 角色骰子血条使用 SubViewport + Sprite3D + Billboard 方案，始终水平面向摄像机
type: feedback
---

**血条实现方案**：使用 SubViewport + Sprite3D + Billboard 模式渲染 2D 血条，血条始终平行于屏幕，固定在骰子正上方，不跟随骰子旋转。

**Why**: 之前尝试过 3D 弧形血条和 3D 直线血条，但需要复杂的方向计算且效果不理想。2D 血条方案简单可靠，血条始终水平可见。

**How to apply**: 
- 血条脚本：`scripts/ui/dice_health_bar_2d.gd`
- 血条在骰子完全稳定后创建（`_on_final_wait_timeout()`）
- 使用 `BILLBOARD_ENABLED` 始终面向摄像机
- 位置：骰子正上方 `offset_y = 1.2` 单位
- Viewport 尺寸：180x16 像素，pixel_size: 0.012
- HP 字体：14 号，居中显示

---
name: 血条创建时机
description: 血条必须在骰子完全稳定（_on_final_wait_timeout）后创建，并通过 set_as_top_level 独立
type: feedback
---

**血条创建时机**：必须在角色骰子完全稳定后（`_on_final_wait_timeout()`）才创建血条，血条使用 `set_as_top_level(true)` 独立于骰子。

**Why**: 骰子在滚动和稳定过程中会旋转，如果血条作为骰子子节点或提前创建，会导致血条方向错误或位置偏移。

**How to apply**: 
- 在 `dice_6.gd` 的 `_on_final_wait_timeout()` 中调用 `create_health_bar()`
- 血条添加到 sandbox 而不是骰子本身
- 血条通过 `parent_dice` 引用跟踪骰子位置
- 每帧更新血条位置跟随骰子

---
name: 2D 血条参数配置
description: 2D 血条最终参数：Viewport 180x16, pixel_size 0.012, 字体 14 号，Y 偏移 -2
type: reference
---

**2D 血条最终配置参数**：
- Viewport 尺寸：180x16 像素
- pixel_size：0.012
- 血条长度：0.7 世界单位
- 血条高度：0.5 世界单位
- offset_y：1.2（骰子上方高度）
- 字体大小：14 号
- 字体 Y 偏移：-2（向上微调居中）
- 颜色：绿色 (0.2,0.8,0.2) → 黄色 (0.8,0.8,0.2) → 红色 (0.8,0.2,0.2)

**文件位置**: `scripts/ui/dice_health_bar_2d.gd`

---

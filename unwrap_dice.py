import bpy
import os

# 清除当前场景
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# 导入骰子模型
dice_path = 'models/dice_smooth.gltf'
bpy.ops.import_scene.gltf(filepath=dice_path)

# 选择导入的骰子模型
dice = bpy.context.active_object
dice.name = "dice"

# 进入编辑模式
bpy.ops.object.mode_set(mode='EDIT')

# 选择所有面
bpy.ops.mesh.select_all(action='SELECT')

# 执行智能UV展开
bpy.ops.uv.smart_project(angle_limit=66, island_margin=0.02)

# 进入UV编辑模式并导出UV布局
# 首先确保UV编辑器存在
bpy.ops.screen.area_split(direction='VERTICAL', factor=0.5)
area = bpy.context.screen.areas[-1]
area.type = 'IMAGE_EDITOR'

# 导出UV布局
uv_layout_path = 'textures/dice/uv_layout.png'
bpy.ops.uv.export_layout(filepath=uv_layout_path, size=(1024, 1024))

# 退出编辑模式
bpy.ops.object.mode_set(mode='OBJECT')

# 导出更新后的模型
export_path = 'models/dice_unwrapped.gltf'
bpy.ops.export_scene.gltf(filepath=export_path, export_format='GLTF_SEPARATE')

print(f"Dice UV unwrapped and exported to {export_path}")
print(f"UV layout exported to {uv_layout_path}")
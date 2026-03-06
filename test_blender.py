import bpy

# 打印当前场景信息
print("Current scene objects:", [obj.name for obj in bpy.context.scene.objects])

# 创建一个简单的立方体
bpy.ops.mesh.primitive_cube_add(size=1)
cube = bpy.context.active_object
cube.name = "test_cube"

# 进入编辑模式
bpy.ops.object.mode_set(mode='EDIT')

# 执行智能UV展开
bpy.ops.uv.smart_project(angle_limit=66, island_margin=0.02)

# 导出模型
bpy.ops.export_scene.gltf(filepath='models/test_cube.gltf', export_format='GLTF_SEPARATE')

print("Test cube created and UV unwrapped")

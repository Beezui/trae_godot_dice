#!/usr/bin/env python3
"""
使用Blender命令行工具来展开骰子模型的UV
"""
import subprocess
import os

# 确保textures/dice目录存在
os.makedirs('textures/dice', exist_ok=True)

# Blender脚本内容
blender_script = """
import bpy
import os

# 清除当前场景
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# 导入骰子模型
dice_path = 'models/dice_smooth.gltf'
bpy.ops.import_scene.gltf(filepath=dice_path)

# 选择导入的骰子模型
for obj in bpy.context.scene.objects:
    if 'dice' in obj.name.lower():
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        break

# 进入编辑模式
bpy.ops.object.mode_set(mode='EDIT')

# 选择所有面
bpy.ops.mesh.select_all(action='SELECT')

# 执行智能UV展开
bpy.ops.uv.smart_project(angle_limit=66, island_margin=0.02)

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
"""

# 保存Blender脚本到临时文件
with open('unwrap_dice_temp.py', 'w') as f:
    f.write(blender_script)

# 执行Blender命令
print("开始使用Blender处理骰子模型...")
try:
    # 尝试使用blender命令
    result = subprocess.run(
        ['blender', '--background', '--python', 'unwrap_dice_temp.py'],
        capture_output=True,
        text=True
    )
    print("Blender输出:")
    print(result.stdout)
    if result.stderr:
        print("错误输出:")
        print(result.stderr)
    print("处理完成!")
except FileNotFoundError:
    print("错误: 找不到Blender可执行文件。请确保Blender已安装并添加到系统路径中。")
except Exception as e:
    print(f"错误: {e}")
finally:
    # 清理临时文件
    if os.path.exists('unwrap_dice_temp.py'):
        os.remove('unwrap_dice_temp.py')

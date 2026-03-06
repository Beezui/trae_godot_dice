import json
import urllib.request

# Blender MCP 服务器地址
BLENDER_MCP_URL = "http://localhost:9876/api/command"

def send_blender_command(command, params=None):
    """发送命令到 Blender MCP"""
    payload = {
        "command": command,
        "params": params or {}
    }
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(BLENDER_MCP_URL, data=data, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode('utf-8'))

def main():
    print("开始处理骰子模型的UV展开...")
    
    # 1. 清除当前场景
    print("清除当前场景...")
    send_blender_command("clear_scene")
    
    # 2. 导入骰子模型
    print("导入骰子模型...")
    send_blender_command("import_gltf", {
        "filepath": "models/dice_smooth.gltf"
    })
    
    # 3. 选择骰子模型
    print("选择骰子模型...")
    send_blender_command("select_object", {
        "name": "dice"
    })
    
    # 4. 进入编辑模式
    print("进入编辑模式...")
    send_blender_command("enter_edit_mode")
    
    # 5. 选择所有面
    print("选择所有面...")
    send_blender_command("select_all")
    
    # 6. 执行智能UV展开
    print("执行智能UV展开...")
    send_blender_command("unwrap_uv", {
        "method": "smart_project",
        "angle_limit": 66,
        "island_margin": 0.02
    })
    
    # 7. 导出UV布局
    print("导出UV布局...")
    send_blender_command("export_uv_layout", {
        "filepath": "textures/dice/uv_layout.png",
        "size": [1024, 1024]
    })
    
    # 8. 退出编辑模式
    print("退出编辑模式...")
    send_blender_command("enter_object_mode")
    
    # 9. 导出更新后的模型
    print("导出更新后的模型...")
    send_blender_command("export_gltf", {
        "filepath": "models/dice_unwrapped.gltf",
        "export_format": "GLTF_SEPARATE"
    })
    
    print("骰子模型UV展开完成！")
    print("- 展开后的模型已导出到: models/dice_unwrapped.gltf")
    print("- UV布局图已导出到: textures/dice/uv_layout.png")

if __name__ == "__main__":
    main()
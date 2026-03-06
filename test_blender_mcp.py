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
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        print(f"命令执行失败: {e}")
        return None

def main():
    print("测试Blender MCP连接...")
    
    # 1. 测试基本命令
    print("测试基本命令...")
    response = send_blender_command("get_scene_info")
    print(f"场景信息: {response}")
    
    # 2. 清除当前场景
    print("清除当前场景...")
    response = send_blender_command("clear_scene")
    print(f"清除场景: {response}")
    
    # 3. 导入骰子模型
    print("导入骰子模型...")
    response = send_blender_command("import_gltf", {
        "filepath": "models/dice_smooth.gltf"
    })
    print(f"导入模型: {response}")
    
    # 4. 选择骰子模型
    print("选择骰子模型...")
    response = send_blender_command("select_object", {
        "name": "dice"
    })
    print(f"选择对象: {response}")
    
    print("测试完成!")

if __name__ == "__main__":
    main()
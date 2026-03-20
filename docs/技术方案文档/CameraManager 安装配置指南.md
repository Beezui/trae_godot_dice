# CameraManager 安装配置指南

## 问题说明

如果在使用 `CameraManager` 时遇到以下错误：

```
Parser Error: Identifier "CameraManager" not declared in the current scope.
```

这是因为 `CameraManager` 脚本还没有被添加为 Godot 的 Autoload 单例。

## 解决方案

### 方法 1：自动配置（推荐）

`CameraManager` 已经添加到 `project.godot` 文件中，只需重新加载项目即可：

1. **关闭并重新打开 Godot**
2. **或者重新加载项目**：点击菜单栏 `项目` → `重新加载当前项目`

### 方法 2：手动添加（如果自动配置不生效）

如果自动配置没有生效，可以手动添加：

1. **打开项目设置**
   - 点击菜单栏 `项目` → `项目设置`

2. **进入 Autoload 标签**
   - 在项目设置窗口中，点击 `Autoload` 标签

3. **添加 CameraManager**
   - 在 `Node` 栏位，点击文件夹图标
   - 选择 `res://scripts/camera_manager.gd`
   - `Node Name` 会自动填入 `CameraManager`（确保名称正确）
   - 点击 `Add` 按钮

4. **确认添加成功**
   - 在 Autoload 列表中应该能看到 `CameraManager`
   - 确保复选框已勾选

5. **保存并重新加载**
   - 关闭项目设置窗口
   - Godot 会自动重新加载脚本

## 验证安装

### 方法 1：检查项目文件

打开 `project.godot` 文件，确认有以下内容：

```ini
[autoload]

CameraManager="*res://scripts/camera_manager.gd"
```

### 方法 2：在代码中使用

在任意场景脚本中添加测试代码：

```gdscript
func _ready():
    # 如果安装成功，这行代码不会报错
    print("CameraManager 已安装：", CameraManager.get_instance() != null)
    print("摄像机配置：位置=%s, FOV=%.1f" % [
        CameraManager.camera_position, 
        CameraManager.camera_fov
    ])
```

运行场景，如果控制台输出类似信息，说明安装成功：

```
CameraManager 已安装：true
摄像机配置：位置=(0, 60, 0), FOV=15.0
```

### 方法 3：使用调试功能

```gdscript
func _ready():
    # 列出所有已注册的摄像机
    CameraManager.list_cameras()
```

## 常见问题

### Q1: 添加 Autoload 后仍然报错

**原因**: Godot 没有重新加载脚本

**解决方法**:
1. 保存所有场景和脚本
2. 关闭 Godot
3. 重新打开 Godot
4. 重新运行场景

### Q2: CameraManager 名称不正确

**原因**: Autoload 名称不是 `CameraManager`

**解决方法**:
1. 打开项目设置 → Autoload
2. 检查 Node Name 是否为 `CameraManager`
3. 如果不正确，删除后重新添加

### Q3: 路径不正确

**原因**: `camera_manager.gd` 文件路径不对

**解决方法**:
1. 确认文件位于 `res://scripts/camera_manager.gd`
2. 如果位置不同，修改 Autoload 中的路径

### Q4: 多个 Autoload 冲突

**原因**: 有多个同名的 Autoload

**解决方法**:
1. 打开项目设置 → Autoload
2. 检查是否有重复的 Autoload
3. 删除重复的，只保留一个 `CameraManager`

## 完整的 Autoload 列表

当前项目的 Autoload 列表应该包含：

```ini
[autoload]

SkillManager="*res://skills/skill_manager.gd"
DiceTextureManager="*res://scripts/dice/dice_texture_manager.gd"
DiceThrowController="*res://scripts/dice/dice_throw_controller.gd"
DiceResultDetector="*res://scripts/dice/dice_result_detector.gd"
CharacterManager="*res://scripts/character/CharacterManager.gd"
CameraManager="*res://scripts/camera_manager.gd"
```

## 使用示例

安装成功后，在任意场景中使用：

```gdscript
extends Node3D

@onready var camera = $Camera3D

func _ready():
    # 注册摄像机
    CameraManager.register_camera(camera)
    
    # 输出配置信息
    print("摄像机位置：%s" % CameraManager.camera_position)
    print("摄像机 FOV: %.1f" % CameraManager.camera_fov)

func _input(event):
    # 切换预设
    if event.is_action_pressed("ui_1"):
        CameraManager.set_preset("high")
        print("切换至高位视角")
```

## 更新日志

- **2026-03-20**: 添加 CameraManager 到 Autoload
  - 路径：`res://scripts/camera_manager.gd`
  - 名称：`CameraManager`
  - 类型：Node

## 相关文档

- [`摄像机管理器使用指南.md`](res://docs/技术方案文档/摄像机管理器使用指南.md) - 完整使用文档
- [`摄像机统一配置实现说明.md`](res://docs/技术方案文档/摄像机统一配置实现说明.md) - 实现说明

## 联系支持

如果以上方法都无法解决问题，请检查：

1. Godot 版本是否为 4.6+
2. `camera_manager.gd` 文件是否存在且完整
3. 项目文件是否有语法错误
4. 控制台是否有其他相关错误信息

# CameraManager 配置检查清单

## ✅ 已完成的配置

### 1. 文件创建
- [x] `res://scripts/camera_manager.gd` - 摄像机管理器脚本 ✅
- [x] `res://docs/技术方案文档/摄像机管理器使用指南.md` - 使用文档 ✅
- [x] `res://docs/技术方案文档/摄像机统一配置实现说明.md` - 实现说明 ✅
- [x] `res://docs/技术方案文档/CameraManager 安装配置指南.md` - 安装指南 ✅
- [x] `res://docs/技术方案文档/CameraManager 配置生效说明.md` - 配置说明 ✅

### 2. 项目配置
- [x] `project.godot` 已添加 CameraManager 到 Autoload ✅
  ```ini
  CameraManager="*res://scripts/camera_manager.gd"
  ```

### 3. 场景集成
- [x] `attr_dice_test.gd` 已集成 CameraManager ✅
  - 在 `_ready()` 中注册摄像机
  - 在 `_input()` 中添加键盘快捷键（1/2/3/0 键）

## 🔄 下一步操作

### 立即执行

1. **重新加载项目**
   ```
   Godot 编辑器 → 项目 → 重新加载当前项目
   ```
   或者关闭并重新打开 Godot

2. **验证配置**
   - 打开 `项目` → `项目设置` → `Autoload`
   - 确认列表中有 `CameraManager`
   - 确认复选框已勾选

3. **测试运行**
   - 运行 `attr_dice_test` 场景
   - 查看控制台输出：
     ```
     CameraManager 初始化完成
     【摄像机配置】位置：(0, 60, 0), FOV: 15.0
     【摄像机管理器】注册摄像机：Camera3D
     ```

4. **测试键盘控制**
   - 按 **Home 键**：切换高位视角
   - 按 **End 键**：切换低位视角
   - 按 **Page Up 键**：切换广角视角
   - 按 **Page Down 键**：重置默认视角

### 可选扩展

#### 更新其他场景（推荐）

如果需要统一其他场景的摄像机，可以按以下方式更新：

**场景 1: `skill_dice_test.gd`**
```gdscript
func _ready():
    # 添加这行
    CameraManager.register_camera($Camera3D)
```

**场景 2: `character_test_arena.gd`**
```gdscript
func _ready():
    # 添加这行
    CameraManager.register_camera($Camera3D)
```

**场景 3: `dice_demo_simple_final.gd`**
```gdscript
func _ready():
    # 添加这行
    CameraManager.register_camera($Camera3D)
```

#### 添加 UI 控制（可选）

如果需要 UI 界面控制摄像机，可以创建控制场景：

```gdscript
# camera_ui.gd
extends Control

func _on_high_button_pressed():
    CameraManager.set_preset("high")

func _on_low_button_pressed():
    CameraManager.set_preset("low")

func _on_wide_button_pressed():
    CameraManager.set_preset("wide")

func _on_reset_button_pressed():
    CameraManager.reset_to_default()
```

## 📋 配置验证测试

### 测试 1: 基本功能
```gdscript
# 在任何场景的 _ready() 中添加
func _ready():
    print("=== CameraManager 测试 ===")
    print("是否存在：", CameraManager.get_instance() != null)
    print("位置：", CameraManager.camera_position)
    print("FOV: ", CameraManager.camera_fov)
    print("旋转：", CameraManager.camera_rotation)
```

**预期输出**：
```
=== CameraManager 测试 ===
是否存在：True
位置：(0, 60, 0)
FOV:  15.0
旋转：(-1.5708, 0, 0)
```

### 测试 2: 预设切换
```gdscript
func _ready():
    # 测试所有预设
    CameraManager.set_preset("high")
    print("高位：", CameraManager.camera_position)
    
    CameraManager.set_preset("low")
    print("低位：", CameraManager.camera_position)
    
    CameraManager.set_preset("wide")
    print("广角：", CameraManager.camera_fov)
    
    CameraManager.reset_to_default()
    print("默认：", CameraManager.camera_position)
```

**预期输出**：
```
高位：(0, 80, 0)
低位：(0, 40, 0)
广角：25.0
默认：(0, 60, 0)
```

### 测试 3: 动态调整
```gdscript
func _input(event):
    if event.is_action_pressed("ui_up"):
        CameraManager.update_fov(CameraManager.camera_fov + 5.0)
        print("FOV+: ", CameraManager.camera_fov)
    
    if event.is_action_pressed("ui_down"):
        CameraManager.update_fov(max(5.0, CameraManager.camera_fov - 5.0))
        print("FOV-: ", CameraManager.camera_fov)
```

### 测试 4: 多场景同步
```gdscript
# 在场景 A 中
func _on_fov_changed():
    CameraManager.update_fov(20.0)
    # 切换到场景 B，摄像机 FOV 也应该是 20.0
```

## 🐛 故障排查

### 问题 1: 仍然报错 "CameraManager not declared"

**解决方法**：
1. 保存所有文件
2. 关闭 Godot
3. 重新打开 Godot
4. 重新运行场景

### 问题 2: Autoload 列表中没有 CameraManager

**解决方法**：
1. 打开 `项目` → `项目设置` → `Autoload`
2. 点击 `+` 号
3. 选择 `res://scripts/camera_manager.gd`
4. 确认名称为 `CameraManager`
5. 点击 `Add`
6. 保存项目

### 问题 3: 控制台没有输出

**可能原因**：
- 摄像机没有注册
- 场景中没有调用 `_ready()`

**解决方法**：
```gdscript
func _ready():
    print("场景已加载")
    if has_node("Camera3D"):
        print("找到摄像机")
        CameraManager.register_camera($Camera3D)
    else:
        print("未找到摄像机节点")
```

### 问题 4: 键盘控制不生效

**可能原因**：
- 输入映射未配置
- `_input()` 方法未正确实现

**解决方法**：
1. 检查 `项目` → `项目设置` → `输入映射`
2. 确认有 `ui_0`, `ui_1`, `ui_2`, `ui_3` 映射
3. 如果没有，添加并绑定到数字键 0-3

## 📊 配置状态总览

| 组件 | 状态 | 说明 |
|------|------|------|
| **脚本文件** | ✅ 完成 | `camera_manager.gd` 已创建 |
| **项目配置** | ✅ 完成 | `project.godot` 已更新 |
| **文档** | ✅ 完成 | 4 份文档已创建 |
| **示例场景** | ✅ 完成 | `attr_dice_test.gd` 已集成 |
| **待更新场景** | ⏳ 可选 | `skill_dice_test.gd` 等 3 个场景 |

## 🎯 最终确认

完成所有步骤后，应该能够：

- ✅ 在编辑器中运行场景，CameraManager 正常工作
- ✅ 使用键盘 1/2/3/0 键切换摄像机视角
- ✅ 发布游戏后，CameraManager 仍然正常工作
- ✅ 所有注册的摄像机使用统一配置

## 📝 更新日志

- **2026-03-20**: 初始配置完成
  - 创建 CameraManager 脚本
  - 添加到项目 Autoload
  - 创建完整文档
  - 集成到示例场景

## 📚 相关文档索引

1. **[摄像机管理器使用指南.md](res://docs/技术方案文档/摄像机管理器使用指南.md)**
   - 完整的使用文档
   - 包含所有 API 说明
   - 丰富的使用示例

2. **[摄像机统一配置实现说明.md](res://docs/技术方案文档/摄像机统一配置实现说明.md)**
   - 实现细节说明
   - 迁移指南
   - 最佳实践

3. **[CameraManager 安装配置指南.md](res://docs/技术方案文档\CameraManager 安装配置指南.md)**
   - 安装步骤详解
   - 常见问题解答
   - 故障排查指南

4. **[CameraManager 配置生效说明.md](res://docs/技术方案文档\CameraManager 配置生效说明.md)**
   - 配置生效范围说明
   - 编辑器和发布版本一致性保证
   - 最佳实践建议

---

**配置已完成！请重新加载项目并测试运行。** 🎉

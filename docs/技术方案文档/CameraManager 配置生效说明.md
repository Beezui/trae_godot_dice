# CameraManager 配置生效说明

## ⚠️ 重要提示

### 当前配置状态

**`project.godot` 中的 Autoload 配置**：
- ✅ **在游戏和编辑器中都生效**
- ✅ **发布后也会生效**
- ✅ **是项目级别的配置**

### 配置的作用范围

```
┌─────────────────────────────────────┐
│         project.godot               │
│  (项目配置文件 - 最高优先级)         │
└─────────────────────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
         ▼                 ▼
┌─────────────────┐ ┌──────────────┐
│  编辑器运行时   │ │  发布后游戏  │
│  (测试/调试)    │ │  (独立运行)  │
└─────────────────┘ └──────────────┘
         │                 │
         └────────┬────────┘
                  │
                  ▼
         ✅ 都使用相同的配置
```

## 详细说明

### 1. `project.godot` 文件的性质

`project.godot` 是 **项目配置文件**，它：

- ✅ **存储在项目中**：文件位于项目根目录
- ✅ **版本控制友好**：可以提交到 Git 等版本控制系统
- ✅ **编辑器读取**：Godot 编辑器启动时读取此文件
- ✅ **游戏运行时读取**：发布的游戏启动时也读取此文件
- ✅ **永久生效**：除非手动修改，否则配置不会改变

### 2. Autoload 配置的生效时机

#### 在编辑器中运行时
```
启动 Godot 编辑器
    ↓
加载项目 (读取 project.godot)
    ↓
注册 Autoload 单例 (包括 CameraManager)
    ↓
运行场景
    ↓
CameraManager 可用 ✅
```

#### 发布后游戏运行时
```
启动发布的游戏 (.exe)
    ↓
加载项目数据 (包含 project.godot)
    ↓
注册 Autoload 单例 (包括 CameraManager)
    ↓
运行主场景
    ↓
CameraManager 可用 ✅
```

### 3. 会不会出现编辑器生效但发布不生效？

**答案：不会！**

原因：
1. **同一份配置**：编辑器和游戏都使用同一个 `project.godot` 文件
2. **打包时包含**：发布游戏时，`project.godot` 会被打包到游戏数据中
3. **运行时读取**：游戏启动时会读取并应用所有配置

### 4. 什么情况下会出现不一致？

#### ❌ 情况 1：只在编辑器中手动添加 Autoload

如果在编辑器中添加 Autoload 但**没有保存项目**：
- 编辑器中：临时生效
- 发布后：**不生效**（因为 `project.godot` 没有更新）

**解决方法**：
- 在编辑器中添加 Autoload 后，**必须保存项目**
- 或者直接编辑 `project.godot` 文件（推荐）

#### ❌ 情况 2：使用本地覆盖配置

Godot 允许在 `editor_settings.cfg` 中设置编辑器特定的配置，但这**不影响游戏运行**。

**注意**：我们修改的是 `project.godot`，不是 `editor_settings.cfg`，所以不会出现这个问题。

#### ❌ 情况 3：发布时没有包含最新配置

如果 `project.godot` 已更新，但发布时使用了旧版本的项目文件：
- 编辑器中：生效（使用最新文件）
- 发布后：**不生效**（使用了旧文件）

**解决方法**：
- 发布前确认 `project.godot` 已保存最新版本
- 使用版本控制（Git）管理项目文件

## 当前配置确认

### 已注册的 Autoload 列表

```ini
[autoload]

SkillManager="*res://skills/skill_manager.gd"
DiceTextureManager="*res://scripts/dice/dice_texture_manager.gd"
DiceThrowController="*res://scripts/dice/dice_throw_controller.gd"
DiceResultDetector="*res://scripts/dice/dice_result_detector.gd"
CharacterManager="*res://scripts/character/CharacterManager.gd"
CameraManager="*res://scripts/camera_manager.gd"  ← 新增
```

### 配置验证

#### 方法 1：检查文件内容
```bash
# 在项目根目录执行
grep "CameraManager" project.godot
```

应该输出：
```
CameraManager="*res://scripts/camera_manager.gd"
```

#### 方法 2：在编辑器中查看
1. 打开 Godot 编辑器
2. 点击 `项目` → `项目设置`
3. 选择 `Autoload` 标签
4. 检查列表中是否有 `CameraManager`

#### 方法 3：运行时测试
```gdscript
func _ready():
    print("CameraManager 是否存在：", CameraManager.get_instance() != null)
    # 如果输出 true，说明配置生效
```

## 发布流程确认

### 正确的发布步骤

1. **确认配置已保存**
   - 保存所有场景和脚本
   - 确认 `project.godot` 已更新

2. **在编辑器中测试**
   - 运行场景，确认 CameraManager 正常工作
   - 检查控制台输出

3. **导出游戏**
   - `项目` → `导出`
   - 选择目标平台（Windows/Linux/macOS）
   - 点击 `导出项目`

4. **验证发布版本**
   - 运行导出的 .exe 文件
   - 确认 CameraManager 仍然可用

### 发布包内容

导出的游戏会包含：
```
游戏文件夹/
├── game.exe              # 游戏可执行文件
├── data.pck             # 游戏数据（包含 project.godot）
├── scripts/             # 脚本文件
│   └── camera_manager.gd
└── ...
```

**`data.pck` 中包含了 `project.godot` 的所有配置**，所以 CameraManager 会在发布版本中正常工作。

## 配置修改方式对比

### 方式 1：直接编辑 `project.godot`（推荐）✅

**优点**：
- ✅ 配置立即生效
- ✅ 版本控制友好
- ✅ 编辑器和游戏都生效
- ✅ 不会有遗漏

**缺点**：
- ⚠️ 需要手动编辑文本文件

**操作**：
```ini
[autoload]
CameraManager="*res://scripts/camera_manager.gd"
```

### 方式 2：通过编辑器 UI 添加

**优点**：
- ✅ 图形界面，操作简单

**缺点**：
- ⚠️ 可能忘记保存项目
- ⚠️ 配置可能只保存在编辑器设置中

**操作**：
1. `项目` → `项目设置` → `Autoload`
2. 选择 `camera_manager.gd`
3. 点击 `Add`
4. **保存项目**（重要！）

## 常见问题

### Q1: 我在编辑器中添加了 CameraManager，发布后会生效吗？

**A**: 如果你**保存了项目**（`project.godot` 已更新），就会生效。如果没有保存，就**不会生效**。

**确认方法**：
打开 `project.godot` 文件，检查是否有：
```ini
CameraManager="*res://scripts/camera_manager.gd"
```

### Q2: 我直接编辑了 `project.godot`，需要重启编辑器吗？

**A**: **需要**。Godot 会在检测到 `project.godot` 变化时自动重新加载项目，但最好手动重启编辑器确保配置正确加载。

### Q3: 如果我在不同电脑上开发，配置会同步吗？

**A**: **会**。`project.godot` 是项目文件，应该提交到版本控制系统（如 Git）。所有开发者都会使用相同的配置。

### Q4: 导出游戏时，需要特别设置什么吗？

**A**: **不需要**。Autoload 配置会自动包含在导出的游戏中，无需额外设置。

### Q5: 如何确认发布版本中 CameraManager 是否生效？

**A**: 在发布版本中添加调试输出：
```gdscript
func _ready():
    print("【发布版本测试】CameraManager 是否存在：", CameraManager.get_instance() != null)
```

运行发布的 .exe 文件，查看控制台输出。

## 最佳实践

### ✅ 推荐做法

1. **直接编辑 `project.godot`**
   - 使用文本编辑器修改
   - 修改后提交到版本控制

2. **在编辑器中验证**
   - 修改后重启编辑器
   - 运行场景测试功能

3. **发布前检查**
   - 确认 `project.godot` 已更新
   - 在编辑器中完整测试所有功能

4. **版本控制**
   - 将 `project.godot` 提交到 Git
   - 确保团队成员使用相同配置

### ❌ 不推荐做法

1. **只在编辑器中添加，不保存项目**
   - 容易遗漏
   - 发布后不生效

2. **使用编辑器特定配置**
   - `editor_settings.cfg` 不应该提交到版本控制
   - 不同开发者可能有不同配置

3. **发布前不验证**
   - 可能导致配置缺失
   - 影响游戏体验

## 总结

| 配置方式 | 编辑器生效 | 发布后生效 | 推荐度 |
|---------|-----------|-----------|--------|
| 编辑 `project.godot` | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| 编辑器添加并保存 | ✅ | ✅ | ⭐⭐⭐⭐ |
| 编辑器添加不保存 | ✅ | ❌ | ⭐ |

**当前我们使用的是第一种方式（编辑 `project.godot`），所以编辑器和发布版本都会生效！** ✅

## 相关文档

- [`摄像机管理器使用指南.md`](res://docs/技术方案文档/摄像机管理器使用指南.md) - 使用文档
- [`摄像机统一配置实现说明.md`](res://docs/技术方案文档/摄像机统一配置实现说明.md) - 实现说明
- [`CameraManager 安装配置指南.md`](res://docs/技术方案文档\CameraManager 安装配置指南.md) - 安装指南

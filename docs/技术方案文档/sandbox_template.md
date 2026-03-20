# 沙盘战斗模板配置

## 基本信息
- **创建日期**: 2026-03-03
- **修改日期**: 2026-03-20（修复 PhysicsMaterial 赋值和墙体可见网格说明）
- **场景文件**: `res://scenes/dice_demo_simple_final.tscn`
- **用途**: 作为日后创建新场景的标准模板

## 摄像机配置

### 位置与旋转
- **Transform**: `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 60, 0)`
- **位置**: (0, 60, 0) （进一步拉高摄像机，确保能看到整个放大后的沙盘）
- **旋转角度**: 90度俯视角（从正上方看向场景）
- **Godot坐标系重点**: 相机旋转为 `Vector3(-PI/2, 0, 0)`，确保从正上方看向场景，符合Godot的3D坐标系

### 投影设置
- **投影模式**: 透视投影 (`projection = 0`)
- **FOV**: 15.0度（进一步缩小视角，使画面更扁平，接近2D效果）
- **效果**: 更接近2D的扁平化效果，同时确保沙盘完全充满屏幕

## 沙盘配置

### 基本设置
- **类型**: StaticBody3D
- **Transform**: `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)` (默认坐标系)

### 地面
- **尺寸**: 固定尺寸（16:9比例）
- **碰撞形状**: BoxShape3D(size = Vector3(sandbox_width, 0.1, sandbox_height))
- **网格缩放**: Vector3(sandbox_width, 0.1, sandbox_height)
- **材质**: 灰色 (albedo_color = Color(0.5, 0.5, 0.5, 1))

### 墙壁

#### 北墙（屏幕上方）
- **碰撞节点**: CollisionShape3D（在场景文件中定义）
- **碰撞形状**: BoxShape3D(size = Vector3(sandbox_width, 50, 0.1))
- **场景文件预设 transform**: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, -6.75)
- **代码设置**: 只需设置 shape 属性
- **可见网格**: 在代码中创建 MeshInstance3D
  - 位置：Vector3(0, -2.5, -sandbox_height/2)
  - 尺寸：Vector3(sandbox_width, 3, 0.1)
  - 材质：蓝色 (albedo_color = Color(0.3, 0.3, 0.7, 1))
- **Godot 坐标系重点**: 北墙位于 z 轴负方向，对应屏幕上方

#### 南墙（屏幕下方）
- **碰撞节点**: CollisionShape3D
- **碰撞形状**: BoxShape3D(size = Vector3(sandbox_width, 50, 0.1))
- **场景文件预设 transform**: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 6.75)
- **代码设置**: 只需设置 shape 属性
- **可见网格**: 在代码中创建 MeshInstance3D
  - 位置：Vector3(0, -2.5, sandbox_height/2)
  - 尺寸：Vector3(sandbox_width, 3, 0.1)
  - 材质：红色 (albedo_color = Color(0.7, 0.3, 0.3, 1))
- **Godot 坐标系重点**: 南墙位于 z 轴正方向，对应屏幕下方

#### 东墙（屏幕右侧）
- **碰撞节点**: CollisionShape3D
- **碰撞形状**: BoxShape3D(size = Vector3(0.1, 50, sandbox_height))
- **场景文件预设 transform**: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 12, -4, 0)
- **代码设置**: 只需设置 shape 属性
- **可见网格**: 在代码中创建 MeshInstance3D
  - 位置：Vector3(sandbox_width/2, -2.5, 0)
  - 尺寸：Vector3(0.1, 3, sandbox_height)
  - 材质：黄色 (albedo_color = Color(0.7, 0.7, 0.3, 1))
- **Godot 坐标系重点**: 东墙位于 x 轴正方向，对应屏幕右侧

#### 西墙（屏幕左侧）
- **碰撞节点**: CollisionShape3D
- **碰撞形状**: BoxShape3D(size = Vector3(0.1, 50, sandbox_height))
- **场景文件预设 transform**: Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -12, -4, 0)
- **代码设置**: 只需设置 shape 属性
- **可见网格**: 在代码中创建 MeshInstance3D
  - 位置：Vector3(-sandbox_width/2, -2.5, 0)
  - 尺寸：Vector3(0.1, 3, sandbox_height)
  - 材质：绿色 (albedo_color = Color(0.3, 0.7, 0.3, 1))
- **Godot 坐标系重点**: 西墙位于 x 轴负方向，对应屏幕左侧

#### 顶部碰撞
- **说明**：已移除顶部碰撞形状，避免阻挡骰子下落
- **原因**：顶部碰撞会阻挡骰子正常落到地面
- **代码位置**：在场景脚本中已实现

### 碰撞区域
- **碰撞高度**: 50 (墙壁碰撞形状高度)
- **可见高度**: 3 (墙壁网格可见部分高度)
- **边界范围**: 固定比例 16:9（宽度 24，深度 13.5，放大 1.5 倍）
- **顶部碰撞**: 已移除，避免阻挡骰子下落

## 光照设置
- **类型**: DirectionalLight3D
- **位置**: (10, 10, 10)
- **旋转**: Transform3D(0.7071, 0.5, 0.5, 0, 0.7071, -0.7071, -0.7071, 0.5, 0.5)
- **效果**: 提供良好的阴影和光照效果

## 骰子设置

### 投掷区域标准（统一标准）
**所有场景的骰子投掷位置必须遵循以下标准**：

- **投掷区域**：屏幕下方，靠近南墙（z 轴正方向），但不超出南墙
- **南墙位置**：z = sandbox_height/2 = 6.75
- **投掷区域 z 坐标**：z = sandbox_height/2 - 2 = 4.75（距离南墙 2 个单位）
- **投掷区域范围**：
  - x 轴：-12 到 12（沙盘宽度范围内）
  - y 轴：4（悬浮高度）
  - z 轴：4.75（固定值，靠近南墙）

### 骰子位置配置
- **默认投掷位置**：(0, 4, 4.75) - 屏幕下方中间，靠近南墙
- **多骰子布局**：
  - 单个骰子：(0, 4, 4.75)
  - 三个骰子并排：
    - 左侧骰子：(-4, 4, 4.75)
    - 中间骰子：(0, 4, 4.75)
    - 右侧骰子：(4, 4, 4.75)
  - **更多骰子并排（支持最多 10 个）**：
    - 使用 `DiceThrowController.calculate_dice_positions()` 自动计算居中位置
    - 或参考下方的多骰子布局表
  - **骰子间距**：标准间距 2.0，超出边界时自动调整

### 多骰子布局参考表（标准间距 2.0）

| 骰子数量 | 布局说明 | x 坐标（从左到右） | 总宽度 | 是否居中 |
|---------|---------|------------------|--------|---------|
| **1** | 单个骰子 | 0 | 0 | ✅ |
| **2** | 对称分布 | -1, 1 | 2 | ✅ |
| **3** | 对称分布 | -2, 0, 2 | 4 | ✅ |
| **4** | 对称分布 | -3, -1, 1, 3 | 6 | ✅ |
| **5** | 对称分布 | -4, -2, 0, 2, 4 | 8 | ✅ |
| **6** | 对称分布 | -5, -3, -1, 1, 3, 5 | 10 | ✅ |
| **7** | 对称分布 | -6, -4, -2, 0, 2, 4, 6 | 12 | ✅ |
| **8** | 对称分布 | -7, -5, -3, -1, 1, 3, 5, 7 | 14 | ✅ |
| **9** | 对称分布 | -8, -6, -4, -2, 0, 2, 4, 6, 8 | 16 | ✅ |
| **10** | 对称分布 | -9, -7, -5, -3, -1, 1, 3, 5, 7, 9 | 18 | ✅ |

**说明**：
- 所有布局都自动居中（x=0 为中心）
- 沙盘可用宽度：24.0 - 2×1.5（安全边距）= 21.0
- 10 个骰子总宽度 18，小于 21.0，不会超出沙盘
- 如果间距调整为 2.5，最多支持 8 个骰子（总宽度 17.5）
- 如果间距调整为 3.0，最多支持 7 个骰子（总宽度 18.0）

### 边界自动调整

当骰子数量过多或间距过大时，系统会自动调整：

```gdscript
# 示例：10 个骰子，间距 2.5（总宽度 22.5，接近边界）
# 系统会自动缩小间距到安全范围
var positions = DiceThrowController.calculate_dice_positions(10, 4.75, 2.5)
# 实际间距会调整为约 2.1，确保不超出沙盘
```

**自动调整规则**：
1. 计算理论总宽度：`(dice_count - 1) * spacing`
2. 检查是否超出沙盘边界（考虑安全边距 1.5）
3. 如果超出，自动缩小间距：`spacing = (24.0 - 2*1.5) / (dice_count - 1)`
4. 重新计算起始位置，确保居中
- **投掷位置**：(0, 5, 4.75) - 离地面 5 个骰子高度
- **Godot 坐标系重点**：骰子初始位置靠近南墙（z 轴正方向），投掷方向朝向北墙（z 轴负方向）

### 投掷力
- **蓄力投掷**：根据蓄力时间计算，最大力度 20
- **方向**：随机 -45°到 45°，朝向屏幕上方（z 轴负方向）
- **统一控制器**：所有场景使用 `DiceThrowController` 进行投掷

### 代码实现
```gdscript
# 在 DiceThrowController 中定义的统一标准
@export var default_start_position: Vector3 = Vector3(0, 4, 4.75)  # 默认投掷位置
@export var dice_spacing: float = 2.0  # 多骰子之间的间距

# 场景脚本中使用统一位置
var initial_z = sandbox_height / 2 - 2  # 4.75
str_dice.position = Vector3(-4, 4, initial_z)
agi_dice.position = Vector3(0, 4, initial_z)
int_dice.position = Vector3(4, 4, initial_z)

# 使用自动布局（推荐，支持任意数量骰子）
var dice_array = [dice1, dice2, dice3, dice4, dice5]
DiceThrowController.apply_centered_layout(dice_array, 4.75, 2.0)

# 或手动计算位置
var positions = DiceThrowController.calculate_dice_positions(5, 4.75, 2.0)
for i in range(dice_array.size()):
    dice_array[i].position = positions[i]

# 自定义间距（例如 10 个骰子，间距 1.5）
var many_dices = [dice1, dice2, dice3, dice4, dice5, dice6, dice7, dice8, dice9, dice10]
DiceThrowController.apply_centered_layout(many_dices, 4.75, 1.5)
# 系统会自动检查边界，如果超出会自动调整间距
```

## 视窗设置
- **分辨率**: 固定比例 16:9
- **与沙盘比例**: 固定保持 16:9 比例
- **比例计算**: sandbox_height = 13.5 (固定深度，放大1.5倍)
- **base_width**: 24.0（固定宽度，放大1.5倍）
- **比例关系**: 沙盘宽度 : 沙盘深度 = 16 : 9

## 控制设置
- **空格键**: 蓄力投掷骰子（根据按下时间增加力度）
- **R键**: 恢复骰子初始状态（悬浮在屏幕靠下位置）

## 使用说明
1. 此模板使用固定的 16:9 比例，不再自动调整沙盘尺寸
2. 摄像机角度已优化，提供良好的 3D 俯视视角，视角固定
3. 墙壁可见高度为 3，增强视觉效果
4. 碰撞区域保持完整，确保游戏机制正常
5. 顶部碰撞形状已移除，确保骰子能正常落到地面
6. 可基于此模板创建不同的战斗场景
7. 墙壁颜色已按照屏幕方向标准化：北（上）- 蓝色，南（下）- 红色，西（左）- 绿色，东（右）- 黄色

## 注意事项
- 沙盘使用固定的 16:9 比例，不再自动适配窗口大小
- 摄像机视角固定，确保沙盘显示效果一致
- 如需调整摄像机，建议保持类似的倾斜角度以维持 3D 效果
- 墙壁碰撞区域高度为 50，确保骰子无法跳出
- 可根据需要调整 FOV 和摄像机高度以获得最佳视角
- 墙壁底部已与地面完全连接，确保无间隙
- 骰子模型已使用圆滑边缘设计，提升滚动效果
- 顶部碰撞已移除，确保骰子能正常落到地面
- 参考正确做法：查看 dice_demo_simple_final.tscn 和 dice_demo_script.gd

## Godot坐标系说明

### 坐标系定义
- **x轴**: 水平方向，向右为正
- **y轴**: 垂直方向，向上为正
- **z轴**: 前后方向，向前为正（从相机看向场景）

### 屏幕映射关系
- **屏幕水平方向**: 对应x轴
- **屏幕竖直方向**: 对应z轴
- **屏幕上方**: 对应z轴负方向
- **屏幕下方**: 对应z轴正方向
- **屏幕左侧**: 对应x轴负方向
- **屏幕右侧**: 对应x轴正方向

### 坐标系使用要点
1. **相机设置**: 相机位置为(0, 60, 0)，旋转为Vector3(-PI/2, 0, 0)，确保从正上方看向场景
2. **墙体位置**: 
   - 北墙（上）: z轴负方向，y=-4（与地面对齐）
   - 南墙（下）: z轴正方向，y=-4（与地面对齐）
   - 东墙（右）: x轴正方向，y=-4（与地面对齐）
   - 西墙（左）: x轴负方向，y=-4（与地面对齐）
3. **骰子位置**: 初始位置靠近南墙（z轴正方向），投掷方向朝向北墙（z轴负方向）
4. **物理计算**: 所有物理计算（如投掷力方向）都应基于此坐标系

### 坐标系一致性
- 确保所有场景和脚本都使用相同的坐标系约定
- 当修改相机角度或墙体位置时，需要相应调整其他相关设置
- 在添加新功能时，应参考此坐标系说明，确保坐标计算的一致性

## 模型信息
- **骰子模型**: `res://models/dice_smooth.gltf`
- **模型特点**: 边缘圆滑，倒角宽度0.2，段数5
- **材质**: 白色，粗糙度0.8

## 代码结构
- **主场景脚本**: `res://scenes/dice_demo_script.gd`
- **骰子脚本**: `res://scenes/dice_6.gd`
- **技能系统**: `res://scripts/skill_system.gd`
- **粒子系统**: `res://scripts/particle_system.gd`

## 核心配置代码

### 摄像机配置代码

```gdscript
# 摄像机配置
@onready var camera = $Camera3D

func _ready():
	# 调整摄像机位置和FOV，使其拉远并更接近2D效果
	if camera:
		# 设置摄像机位置，进一步拉高镜头以看到整个沙盘
		camera.position = Vector3(0, 60, 0)  # 进一步拉高摄像机
		# 进一步减小FOV，更贴近俯视2D效果
		camera.fov = 15.0  # 进一步减小FOV值
		# 直接设置相机旋转，避免look_at的共线问题
		camera.rotation = Vector3(-PI/2, 0, 0)

	# 确保光照正确指向原点
	@onready var light = $DirectionalLight3D
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))
```

### 沙盘配置代码

```gdscript
# 沙盘配置
@onready var sandbox = $Sandbox

var base_width = 24.0  # 基础宽度（屏幕水平方向），放大1.5倍
var base_height = 13.5   # 基础高度（屏幕竖直方向），放大1.5倍

func _ready():
	# 计算基础尺寸，保持16:9比例
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width  # 屏幕水平方向（x轴）
	var sandbox_height = sandbox_width / base_ratio  # 屏幕竖直方向（z轴），保持16:9比例
	
	# 创建沙盘碰撞形状和网格
	if sandbox:
		# 创建地面碰撞形状
		var ground_collision = sandbox.get_node("Ground")
		if ground_collision:
			var ground_shape = BoxShape3D.new()
			ground_shape.size = Vector3(sandbox_width, 0.1, sandbox_height)
			ground_collision.shape = ground_shape
			
		# 为地面添加物理材质，提升反弹系数 50%
		var ground_physics_material = PhysicsMaterial.new()
		ground_physics_material.bounce = 0.3  # 提升反弹效果 50%
		ground_physics_material.friction = 0.8  # 增加摩擦力
		# 为地面设置物理材质（注意：必须设置在地面节点上，而不是 sandbox 容器上）
		var ground = sandbox.get_node("Ground")
		if ground:
			ground.physics_material_override = ground_physics_material
		
		# 创建地面网格
		var ground_mesh = sandbox.get_node("GroundMesh")
		if ground_mesh:
			var ground_mesh_resource = BoxMesh.new()
			ground_mesh_resource.size = Vector3(sandbox_width, 0.1, sandbox_height)
			ground_mesh.mesh = ground_mesh_resource
			
			# 创建地面材质
			var ground_material = StandardMaterial3D.new()
			ground_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
			ground_mesh.material_override = ground_material
		
		# 创建北墙碰撞形状（屏幕上方，z 轴负方向）
		var wall_north = sandbox.get_node("WallNorth")
		if wall_north:
			var wall_north_shape = BoxShape3D.new()
			wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
			wall_north.shape = wall_north_shape
			# 注意：墙体的位置已经在场景文件的 transform 中预设，不需要在代码中设置 position
		
		# 创建北墙可见网格（重要：必须创建可见网格，否则墙体不会显示）
		var wall_north_mesh = MeshInstance3D.new()
		wall_north_mesh.name = "WallNorthMesh"
		wall_north_mesh.position = Vector3(0, -2.5, -sandbox_height/2)
		var wall_north_mesh_resource = BoxMesh.new()
		wall_north_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
		wall_north_mesh.mesh = wall_north_mesh_resource
		var north_wall_material = StandardMaterial3D.new()
		north_wall_material.albedo_color = Color(0.3, 0.3, 0.7, 1)  # 北墙（屏幕上方）：蓝色
		wall_north_mesh.material_override = north_wall_material
		sandbox.add_child(wall_north_mesh)
		
		# 创建南墙碰撞形状（屏幕下方，z 轴正方向）
		var wall_south = sandbox.get_node("WallSouth")
		if wall_south:
			var wall_south_shape = BoxShape3D.new()
			wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
			wall_south.shape = wall_south_shape
		
		# 创建南墙可见网格
		var wall_south_mesh = MeshInstance3D.new()
		wall_south_mesh.name = "WallSouthMesh"
		wall_south_mesh.position = Vector3(0, -2.5, sandbox_height/2)
		var wall_south_mesh_resource = BoxMesh.new()
		wall_south_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
		wall_south_mesh.mesh = wall_south_mesh_resource
		var south_wall_material = StandardMaterial3D.new()
		south_wall_material.albedo_color = Color(0.7, 0.3, 0.3, 1)  # 南墙（屏幕下方）：红色
		wall_south_mesh.material_override = south_wall_material
		sandbox.add_child(wall_south_mesh)
		
		# 创建东墙碰撞形状（屏幕右侧，x 轴正方向）
		var wall_east = sandbox.get_node("WallEast")
		if wall_east:
			var wall_east_shape = BoxShape3D.new()
			wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
			wall_east.shape = wall_east_shape
		
		# 创建东墙可见网格
		var wall_east_mesh = MeshInstance3D.new()
		wall_east_mesh.name = "WallEastMesh"
		wall_east_mesh.position = Vector3(sandbox_width/2, -2.5, 0)
		var wall_east_mesh_resource = BoxMesh.new()
		wall_east_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
		wall_east_mesh.mesh = wall_east_mesh_resource
		var east_wall_material = StandardMaterial3D.new()
		east_wall_material.albedo_color = Color(0.7, 0.7, 0.3, 1)  # 东墙（屏幕右侧）：黄色
		wall_east_mesh.material_override = east_wall_material
		sandbox.add_child(wall_east_mesh)
		
		# 创建西墙碰撞形状（屏幕左侧，x 轴负方向）
		var wall_west = sandbox.get_node("WallWest")
		if wall_west:
			var wall_west_shape = BoxShape3D.new()
			wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
			wall_west.shape = wall_west_shape
		
		# 创建西墙可见网格
		var wall_west_mesh = MeshInstance3D.new()
		wall_west_mesh.name = "WallWestMesh"
		wall_west_mesh.position = Vector3(-sandbox_width/2, -2.5, 0)
		var wall_west_mesh_resource = BoxMesh.new()
		wall_west_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
		wall_west_mesh.mesh = wall_west_mesh_resource
		var west_wall_material = StandardMaterial3D.new()
		west_wall_material.albedo_color = Color(0.3, 0.7, 0.3, 1)  # 西墙（屏幕左侧）：绿色
		wall_west_mesh.material_override = west_wall_material
		sandbox.add_child(wall_west_mesh)

	# 增加重力加速度，加快骰子下落速度
	# 在Godot 4中，通过ProjectSettings来设置重力
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)  # 4倍重力加速度，加快下落速度
```

## 场景文件结构

### 基础节点结构
```
- Node3D (主节点)
  - Camera3D (摄像机)
  - DirectionalLight3D (光源)
  - Sandbox (StaticBody3D)
    - Ground (CollisionShape3D) - transform: (0, -4, 0)
    - GroundMesh (MeshInstance3D) - transform: (0, -4, 0)
    - WallNorth (CollisionShape3D) - transform: (0, -4, -6.75)
    - WallSouth (CollisionShape3D) - transform: (0, -4, 6.75)
    - WallEast (CollisionShape3D) - transform: (12, -4, 0)
    - WallWest (CollisionShape3D) - transform: (-12, -4, 0)
  - DiceManager (Node3D)
```

### 场景文件配置
- **摄像机**: 位置 (0, 60, 0), 旋转 (-PI/2, 0, 0), FOV 15.0
- **光源**: 位置 (10, 10, 10), 旋转 Transform3D(0.7071, 0.5, 0.5, 0, 0.7071, -0.7071, -0.7071, 0.5, 0.5)
- **地面**: transform (0, -4, 0), 碰撞形状在代码中设置
- **墙体**: transform 在场景文件中预设，代码中只需设置 shape 属性
- **重要**: 墙体节点必须在场景文件中定义，不能在代码中动态创建

## 继承方法

### 创建新场景步骤
1. 复制 `dice_demo_simple_final.tscn` 作为基础
2. 修改场景名称和主节点脚本
3. 保留相同的节点结构和配置
4. 根据需要添加特定功能的节点

### 脚本继承
- 新场景脚本应继承 `Node3D`
- 保留摄像机、灯光、沙盘的配置代码
- 根据场景功能添加特定逻辑
- 确保骰子初始化位置和投掷逻辑与模板一致

## 优化建议
1. 可根据不同场景需求调整摄像机位置和FOV
2. 可根据游戏风格调整墙壁和地面材质
3. 可添加环境光和其他光源以增强视觉效果
4. 可根据需要调整骰子物理参数以获得更佳的滚动效果
5. 可添加音效和粒子效果以增强用户体验
6. 确保所有新场景都遵循此模板的坐标系和配置规范

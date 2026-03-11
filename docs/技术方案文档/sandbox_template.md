# 沙盘战斗模板配置

## 基本信息
- **创建日期**: 2026-03-03
- **修改日期**: 2026-03-04
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
- **碰撞形状**: BoxShape3D(size = Vector3(sandbox_width, 50, 0.1))
- **碰撞位置**: (0, 21, -sandbox_height/2) (在 Sandbox 局部坐标系中，碰撞形状高度 50)
- **网格位置**: (0, -2.5, -sandbox_height/2) (在 Sandbox 局部坐标系中，与地面对齐)
- **网格缩放**: Vector3(sandbox_width, 3, 0.1) (可见高度 3)
- **材质**: 蓝色 (albedo_color = Color(0.3, 0.3, 0.7, 1))
- **Godot 坐标系重点**: 北墙位于 z 轴负方向，对应屏幕上方

#### 南墙（屏幕下方）
- **碰撞形状**: BoxShape3D(size = Vector3(sandbox_width, 50, 0.1))
- **碰撞位置**: (0, 21, sandbox_height/2) (在 Sandbox 局部坐标系中，碰撞形状高度 50)
- **网格位置**: (0, -2.5, sandbox_height/2) (在 Sandbox 局部坐标系中，与地面对齐)
- **网格缩放**: Vector3(sandbox_width, 3, 0.1) (可见高度 3)
- **材质**: 红色 (albedo_color = Color(0.7, 0.3, 0.3, 1))
- **Godot 坐标系重点**: 南墙位于 z 轴正方向，对应屏幕下方

#### 东墙（屏幕右侧）
- **碰撞形状**: BoxShape3D(size = Vector3(0.1, 50, sandbox_height))
- **碰撞位置**: (sandbox_width/2, 21, 0) (在 Sandbox 局部坐标系中，碰撞形状高度 50)
- **网格位置**: (sandbox_width/2, -2.5, 0) (在 Sandbox 局部坐标系中，与地面对齐)
- **网格缩放**: Vector3(0.1, 3, sandbox_height) (可见高度 3)
- **材质**: 黄色 (albedo_color = Color(0.7, 0.7, 0.3, 1))
- **Godot 坐标系重点**: 东墙位于 x 轴正方向，对应屏幕右侧

#### 西墙（屏幕左侧）
- **碰撞形状**: BoxShape3D(size = Vector3(0.1, 50, sandbox_height))
- **碰撞位置**: (-sandbox_width/2, 21, 0) (在 Sandbox 局部坐标系中，碰撞形状高度 50)
- **网格位置**: (-sandbox_width/2, -2.5, 0) (在 Sandbox 局部坐标系中，与地面对齐)
- **网格缩放**: Vector3(0.1, 3, sandbox_height) (可见高度 3)
- **材质**: 绿色 (albedo_color = Color(0.3, 0.7, 0.3, 1))
- **Godot 坐标系重点**: 西墙位于 x 轴负方向，对应屏幕左侧

#### 顶部碰撞
- **说明**：已移除顶部碰撞形状，避免阻挡骰子下落
- **原因**：顶部碰撞会阻挡骰子正常落到地面
- **代码位置**：在 `dice_demo_script.gd` 第 160-162 行已注释掉

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
- **初始位置**: (0, 4, sandbox_height/2 - 2) (水平方向屏幕中间，靠近下方墙体（南墙），悬浮状态)
- **投掷位置**: (0, 5, sandbox_height/2 - 2) (水平方向屏幕中间，靠近下方墙体（南墙），离地面5个骰子高度)
- **类型**: 实例化的骰子场景
- **投掷力**: 
  - 蓄力投掷：根据蓄力时间计算，最大力度20
  - 方向：随机-45°到45°，朝向屏幕上方（z轴负方向）
- **Godot坐标系重点**: 骰子初始位置靠近南墙（z轴正方向），投掷方向朝向北墙（z轴负方向）

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
			
		# 为地面添加物理材质，提升反弹系数50%
		var ground_physics_material = PhysicsMaterial.new()
		ground_physics_material.bounce = 0.3  # 提升反弹效果50%
		ground_physics_material.friction = 0.8  # 增加摩擦力
		# 为沙盒静态体设置物理材质
		if sandbox:
			sandbox.physics_material_override = ground_physics_material
		
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
		
		# 创建北墙碰撞形状（屏幕上方，z轴负方向）
		var wall_north = sandbox.get_node("WallNorth")
		if wall_north:
			var wall_north_collision = wall_north.get_node("CollisionShape3D")
			if wall_north_collision:
				var wall_north_shape = BoxShape3D.new()
				wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
				wall_north.position = Vector3(0, 21, -sandbox_height/2)
				wall_north_collision.shape = wall_north_shape
		
		# 创建北墙网格
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
		
		# 创建南墙碰撞形状（屏幕下方，z轴正方向）
		var wall_south = sandbox.get_node("WallSouth")
		if wall_south:
			var wall_south_collision = wall_south.get_node("CollisionShape3D")
			if wall_south_collision:
				var wall_south_shape = BoxShape3D.new()
				wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
				wall_south.position = Vector3(0, 21, sandbox_height/2)
				wall_south_collision.shape = wall_south_shape
		
		# 创建南墙网格
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
		
		# 创建东墙碰撞形状（屏幕右侧，x轴正方向）
		var wall_east = sandbox.get_node("WallEast")
		if wall_east:
			var wall_east_collision = wall_east.get_node("CollisionShape3D")
			if wall_east_collision:
				var wall_east_shape = BoxShape3D.new()
				wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
				wall_east.position = Vector3(sandbox_width/2, 21, 0)
				wall_east_collision.shape = wall_east_shape
		
		# 创建东墙网格
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
		
		# 创建西墙碰撞形状（屏幕左侧，x轴负方向）
		var wall_west = sandbox.get_node("WallWest")
		if wall_west:
			var wall_west_collision = wall_west.get_node("CollisionShape3D")
			if wall_west_collision:
				var wall_west_shape = BoxShape3D.new()
				wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
				wall_west.position = Vector3(-sandbox_width/2, 21, 0)
				wall_west_collision.shape = wall_west_shape
		
		# 创建西墙网格
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

## 优化建议
1. 可根据不同场景需求调整摄像机位置和FOV
2. 可根据游戏风格调整墙壁和地面材质
3. 可添加环境光和其他光源以增强视觉效果
4. 可根据需要调整骰子物理参数以获得更佳的滚动效果
5. 可添加音效和粒子效果以增强用户体验
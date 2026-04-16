extends Node3D

## 关卡场景模板脚本
## 所有关卡场景都应继承此脚本或遵循相同的结构

@onready var camera = $Camera3D
@onready var light = $DirectionalLight3D
@onready var boundary = $BoundarySystem
@onready var visual = $VisualSystem
@onready var game_manager = $GameManager

# 场景配置参数
var base_width = 24.0  # 基础宽度（16:9 比例）
var base_height = 13.5  # 基础高度
var sandbox_width = 24.0
var sandbox_height = 13.5

# 场景差异化配置（子类可覆盖）
var ground_color = Color(0.5, 0.5, 0.5, 1)  # 地面颜色
var wall_north_color = Color(0.3, 0.3, 0.7, 1)  # 北墙颜色（默认蓝色）
var wall_south_color = Color(0.7, 0.3, 0.3, 1)  # 南墙颜色（默认红色）
var wall_east_color = Color(0.7, 0.7, 0.3, 1)  # 东墙颜色（默认黄色）
var wall_west_color = Color(0.3, 0.7, 0.3, 1)  # 西墙颜色（默认绿色）
var light_color = Color(1.0, 1.0, 1.0, 1)  # 光照颜色


func _ready():
	# 打印场景初始化信息
	print("=== 关卡场景初始化 ===")
	print("场景名称：%s" % name)
	
	# 1. 注册摄像机到 CameraManager
	_setup_camera()
	
	# 2. 配置光照
	_setup_light()
	
	# 3. 配置碰撞边界
	_setup_boundary()
	
	# 4. 配置可视系统
	_setup_visual()
	
	# 5. 增加重力加速度（加快骰子下落）
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)
	
	print("场景初始化完成")
	print("======================")


## 配置摄像机
func _setup_camera():
	if camera:
		CameraManager.register_camera(camera)
		print("【摄像机】已注册到 CameraManager，使用统一配置")


## 配置光照
func _setup_light():
	if light:
		# 设置光照颜色
		if light.light_color != light_color:
			light.light_color = light_color
		
		# 确保光照指向原点
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))
		print("【光照】已配置，颜色：%s" % light_color)


## 配置碰撞边界系统
func _setup_boundary():
	var sandbox_width = base_width
	var sandbox_height = base_height
	
	# 地面碰撞
	var ground_collision = boundary.get_node("Ground")
	if ground_collision:
		var ground_shape = BoxShape3D.new()
		ground_shape.size = Vector3(sandbox_width, 0.1, sandbox_height)
		ground_collision.shape = ground_shape
		
		# 为地面添加物理材质
		var ground_physics_material = PhysicsMaterial.new()
		ground_physics_material.bounce = 0.3  # 反弹效果
		ground_physics_material.friction = 0.8  # 摩擦力
		boundary.physics_material_override = ground_physics_material
	
	# 北墙碰撞（屏幕上方，z 轴负方向）
	var wall_north = boundary.get_node("WallNorth")
	if wall_north:
		var wall_north_shape = BoxShape3D.new()
		wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_north.shape = wall_north_shape
		# 设置墙的位置：移动到场景边缘，中心高度 25 米（范围 y=0 到 y=50）
		wall_north.position = Vector3(0, 25, -sandbox_height / 2)

	# 南墙碰撞（屏幕下方，z 轴正方向）
	var wall_south = boundary.get_node("WallSouth")
	if wall_south:
		var wall_south_shape = BoxShape3D.new()
		wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_south.shape = wall_south_shape
		wall_south.position = Vector3(0, 25, sandbox_height / 2)

	# 东墙碰撞（屏幕右侧，x 轴正方向）
	var wall_east = boundary.get_node("WallEast")
	if wall_east:
		var wall_east_shape = BoxShape3D.new()
		wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_east.shape = wall_east_shape
		wall_east.position = Vector3(sandbox_width / 2, 25, 0)

	# 西墙碰撞（屏幕左侧，x 轴负方向）
	var wall_west = boundary.get_node("WallWest")
	if wall_west:
		var wall_west_shape = BoxShape3D.new()
		wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_west.shape = wall_west_shape
		wall_west.position = Vector3(-sandbox_width / 2, 25, 0)
	
	print("【碰撞边界】已配置，尺寸：%.1f x %.1f" % [sandbox_width, sandbox_height])


## 配置可视系统
func _setup_visual():
	var sandbox_width = base_width
	var sandbox_height = base_height
	
	# 地面网格
	var ground_mesh = visual.get_node("GroundMesh")
	if ground_mesh:
		var ground_mesh_resource = BoxMesh.new()
		ground_mesh_resource.size = Vector3(sandbox_width, 0.1, sandbox_height)
		ground_mesh.mesh = ground_mesh_resource
		
		var ground_material = StandardMaterial3D.new()
		ground_material.albedo_color = ground_color
		ground_mesh.material_override = ground_material
	
	# 北墙可见网格（屏幕上方）
	var wall_north_mesh = MeshInstance3D.new()
	wall_north_mesh.name = "WallNorthMesh"
	wall_north_mesh.position = Vector3(0, -2.5, -sandbox_height/2)
	var wall_north_mesh_resource = BoxMesh.new()
	wall_north_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
	wall_north_mesh.mesh = wall_north_mesh_resource
	var north_wall_material = StandardMaterial3D.new()
	north_wall_material.albedo_color = wall_north_color
	wall_north_mesh.material_override = north_wall_material
	visual.add_child(wall_north_mesh)
	
	# 南墙可见网格（屏幕下方）
	var wall_south_mesh = MeshInstance3D.new()
	wall_south_mesh.name = "WallSouthMesh"
	wall_south_mesh.position = Vector3(0, -2.5, sandbox_height/2)
	var wall_south_mesh_resource = BoxMesh.new()
	wall_south_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
	wall_south_mesh.mesh = wall_south_mesh_resource
	var south_wall_material = StandardMaterial3D.new()
	south_wall_material.albedo_color = wall_south_color
	wall_south_mesh.material_override = south_wall_material
	visual.add_child(wall_south_mesh)
	
	# 东墙可见网格（屏幕右侧）
	var wall_east_mesh = MeshInstance3D.new()
	wall_east_mesh.name = "WallEastMesh"
	wall_east_mesh.position = Vector3(sandbox_width/2, -2.5, 0)
	var wall_east_mesh_resource = BoxMesh.new()
	wall_east_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
	wall_east_mesh.mesh = wall_east_mesh_resource
	var east_wall_material = StandardMaterial3D.new()
	east_wall_material.albedo_color = wall_east_color
	wall_east_mesh.material_override = east_wall_material
	visual.add_child(wall_east_mesh)
	
	# 西墙可见网格（屏幕左侧）
	var wall_west_mesh = MeshInstance3D.new()
	wall_west_mesh.name = "WallWestMesh"
	wall_west_mesh.position = Vector3(-sandbox_width/2, -2.5, 0)
	var wall_west_mesh_resource = BoxMesh.new()
	wall_west_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
	wall_west_mesh.mesh = wall_west_mesh_resource
	var west_wall_material = StandardMaterial3D.new()
	west_wall_material.albedo_color = wall_west_color
	wall_west_mesh.material_override = west_wall_material
	visual.add_child(wall_west_mesh)
	
	print("【可视系统】已配置（临时四面墙）")


## 动态创建骰子（由 GameManager 调用）
## @param dice_scene_path 骰子场景路径
## @param count 骰子数量
## @return Array 骰子数组
func create_dices(dice_scene_path: String, count: int) -> Array:
	var dices = []
	var dice_scene = load(dice_scene_path)
	
	if not dice_scene:
		print("【错误】无法加载骰子场景：%s" % dice_scene_path)
		return dices
	
	for i in range(count):
		var dice = dice_scene.instantiate()
		game_manager.add_child(dice)
		dices.append(dice)
	
	# 使用 DiceThrowController 自动布局
	if dices.size() > 0:
		DiceThrowController.apply_centered_layout(dices, 4.75, 2.0)
	
	print("【骰子】创建了 %d 个骰子" % count)
	return dices


## 清除所有骰子
func clear_dices():
	for child in game_manager.get_children():
		if child is RigidBody3D:
			child.queue_free()
	print("【骰子】已清除所有骰子")


## 获取所有骰子
func get_all_dices() -> Array:
	var dices = []
	for child in game_manager.get_children():
		if child is RigidBody3D:
			dices.append(child)
	return dices


## 输入处理（可选，子类可覆盖）
func _input(_event):
	pass


## 重置场景（可选，子类可覆盖）
func reset_scene():
	print("【场景】重置场景")
	clear_dices()

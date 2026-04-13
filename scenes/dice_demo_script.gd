extends Node3D

@onready var dice_manager = $DiceManager
@onready var camera = $Camera3D
@onready var light = $DirectionalLight3D
@onready var sandbox = $Sandbox
@onready var charge_label = $ChargeLabel
var start_timer: Timer
var throw_timer: Timer
var is_charging = false
var original_positions = {}  # 存储每个骰子的原始位置
var base_width = 24.0  # 基础宽度（屏幕水平方向），放大 1.5 倍
var base_height = 13.5   # 基础高度（屏幕竖直方向），放大 1.5 倍
var is_in_initial_state = true  # 标记是否处于初始状态
var global_time = 0.0  # 全局时间

func _ready():
	# 打印场景初始化信息
	print("=== Dice Demo Simple Final Scene Initializing ===")
	
	# ✅ 使用 CameraManager 统一管理摄像机配置
	if camera:
		CameraManager.register_camera(camera)
		print("【摄像机】已注册到 CameraManager，使用统一配置")

	# 确保光照正确指向原点
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))
	
	# 计算沙盘尺寸
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width
	var sandbox_height = sandbox_width / base_ratio
	
	# 创建沙盘碰撞形状和网格
	if sandbox:
		_setup_sandbox(sandbox_width, sandbox_height)
	
	# 增加重力加速度
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)
	
	# 创建启动计时器
	start_timer = Timer.new()
	start_timer.wait_time = 1.0
	start_timer.one_shot = true
	start_timer.timeout.connect(start_demo)
	add_child(start_timer)
	start_timer.start()
	
	print("Dice demo scene initialized")
	print("=== Initialization Complete ===")

func _setup_sandbox(sandbox_width: float, sandbox_height: float):
	# 创建地面碰撞形状
	var ground_collision = sandbox.get_node("Ground")
	if ground_collision:
		var ground_shape = BoxShape3D.new()
		ground_shape.size = Vector3(sandbox_width, 0.1, sandbox_height)
		ground_collision.shape = ground_shape
		
	# 为地面添加物理材质
	var ground_physics_material = PhysicsMaterial.new()
	ground_physics_material.bounce = 0.3
	ground_physics_material.friction = 0.8
	sandbox.physics_material_override = ground_physics_material
	
	# 创建地面网格
	var ground_mesh = sandbox.get_node("GroundMesh")
	if ground_mesh:
		var ground_mesh_resource = BoxMesh.new()
		ground_mesh_resource.size = Vector3(sandbox_width, 0.1, sandbox_height)
		ground_mesh.mesh = ground_mesh_resource
		
		var ground_material = StandardMaterial3D.new()
		ground_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
		ground_mesh.material_override = ground_material
	
	# 创建北墙（屏幕上方，z 轴负方向）
	var wall_north = sandbox.get_node("WallNorth")
	if wall_north:
		var wall_north_shape = BoxShape3D.new()
		wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_north.position = Vector3(0, 21, -sandbox_height/2)
		wall_north.shape = wall_north_shape
	
	var wall_north_mesh = MeshInstance3D.new()
	wall_north_mesh.name = "WallNorthMesh"
	wall_north_mesh.position = Vector3(0, -2.5, -sandbox_height/2)
	var wall_north_mesh_resource = BoxMesh.new()
	wall_north_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
	wall_north_mesh.mesh = wall_north_mesh_resource
	var north_wall_material = StandardMaterial3D.new()
	north_wall_material.albedo_color = Color(0.3, 0.3, 0.7, 1)
	wall_north_mesh.material_override = north_wall_material
	sandbox.add_child(wall_north_mesh)
	
	# 创建南墙（屏幕下方，z 轴正方向）
	var wall_south = sandbox.get_node("WallSouth")
	if wall_south:
		var wall_south_shape = BoxShape3D.new()
		wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_south.position = Vector3(0, 21, sandbox_height/2)
		wall_south.shape = wall_south_shape
	
	var wall_south_mesh = MeshInstance3D.new()
	wall_south_mesh.name = "WallSouthMesh"
	wall_south_mesh.position = Vector3(0, -2.5, sandbox_height/2)
	var wall_south_mesh_resource = BoxMesh.new()
	wall_south_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
	wall_south_mesh.mesh = wall_south_mesh_resource
	var south_wall_material = StandardMaterial3D.new()
	south_wall_material.albedo_color = Color(0.7, 0.3, 0.3, 1)
	wall_south_mesh.material_override = south_wall_material
	sandbox.add_child(wall_south_mesh)
	
	# 创建东墙（屏幕右侧，x 轴正方向）
	var wall_east = sandbox.get_node("WallEast")
	if wall_east:
		var wall_east_shape = BoxShape3D.new()
		wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_east.position = Vector3(sandbox_width/2, 21, 0)
		wall_east.shape = wall_east_shape
	
	var wall_east_mesh = MeshInstance3D.new()
	wall_east_mesh.name = "WallEastMesh"
	wall_east_mesh.position = Vector3(sandbox_width/2, -2.5, 0)
	var wall_east_mesh_resource = BoxMesh.new()
	wall_east_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
	wall_east_mesh.mesh = wall_east_mesh_resource
	var east_wall_material = StandardMaterial3D.new()
	east_wall_material.albedo_color = Color(0.7, 0.7, 0.3, 1)
	wall_east_mesh.material_override = east_wall_material
	sandbox.add_child(wall_east_mesh)
	
	# 创建西墙（屏幕左侧，x 轴负方向）
	var wall_west = sandbox.get_node("WallWest")
	if wall_west:
		var wall_west_shape = BoxShape3D.new()
		wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_west.position = Vector3(-sandbox_width/2, 21, 0)
		wall_west.shape = wall_west_shape
	
	var wall_west_mesh = MeshInstance3D.new()
	wall_west_mesh.name = "WallWestMesh"
	wall_west_mesh.position = Vector3(-sandbox_width/2, -2.5, 0)
	var wall_west_mesh_resource = BoxMesh.new()
	wall_west_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
	wall_west_mesh.mesh = wall_west_mesh_resource
	var west_wall_material = StandardMaterial3D.new()
	west_wall_material.albedo_color = Color(0.3, 0.7, 0.3, 1)
	wall_west_mesh.material_override = west_wall_material
	sandbox.add_child(wall_west_mesh)

func start_demo():
	is_in_initial_state = true
	print("Demo started with dice in initial position")

func _process(delta):
	global_time += delta
	if throw_timer and not throw_timer.is_stopped():
		return
	
	if is_charging:
		# ✅ 使用统一的投掷控制器更新蓄力
		var charge_ratio = DiceThrowController.update_charge(delta)
		
		# ✅ 使用统一的震动效果
		var dices = get_all_dices()
		DiceThrowController.apply_shake(dices, original_positions, charge_ratio, delta)
		
		# 更新 UI 显示
		if charge_label:
			charge_label.text = "蓄力：%d%%" % (charge_ratio * 100)
	else:
		# 非蓄力状态下，清空原始位置
		original_positions.clear()

func get_all_dices() -> Array:
	var dices = []
	if dice_manager:
		for i in range(dice_manager.get_dice_count()):
			var dice = dice_manager.get_dice(i)
			if dice and is_instance_valid(dice):
				dices.append(dice)
	return dices

func _input(event):
	# 空格键开始蓄力
	if event.is_action_pressed("ui_accept") and is_in_initial_state:
		is_charging = true
		# ✅ 使用统一的投掷控制器开始蓄力
		DiceThrowController.start_charge()
		
		# 记录骰子的初始位置
		original_positions.clear()
		if dice_manager:
			for i in range(dice_manager.get_dice_count()):
				var dice = dice_manager.get_dice(i)
				if dice and is_instance_valid(dice):
					original_positions[dice] = dice.position
		print("开始蓄力...")
	
	# 空格键松开，投掷骰子
	elif event.is_action_released("ui_accept") and is_charging:
		is_charging = false
		# ✅ 使用统一的投掷控制器结束蓄力并投掷
		var dices = get_all_dices()
		DiceThrowController.end_charge(dices)
		
		# 清空原始位置
		original_positions.clear()
		print("投掷骰子！")
		is_in_initial_state = false
	
	# R 键恢复骰子初始状态
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_dice()
	
	# A 键增加骰子
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
		if dice_manager:
			dice_manager.add_dice()
	
	# S 键减少骰子
	if event is InputEventKey and event.pressed and event.keycode == KEY_S:
		if dice_manager:
			dice_manager.remove_dice()
	
	# ✅ 摄像机控制快捷键
	if event.is_action_pressed("ui_home"):
		CameraManager.set_preset("high")
		print("【摄像机】切换至高位视角")
	elif event.is_action_pressed("ui_end"):
		CameraManager.set_preset("low")
		print("【摄像机】切换至低位视角")
	elif event.is_action_pressed("ui_page_up"):
		CameraManager.set_preset("wide")
		print("【摄像机】切换至广角视角")
	elif event.is_action_pressed("ui_page_down"):
		CameraManager.reset_to_default()
		print("【摄像机】重置为默认视角")

func reset_dice():
	if dice_manager:
		dice_manager.reset_dice()
	is_in_initial_state = true
	print("Dice reset to initial state")

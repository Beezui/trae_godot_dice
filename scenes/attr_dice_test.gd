extends Node3D

@onready var attr_dice_manager = $attr_dice_manager
@onready var camera = $Camera3D
@onready var light = $DirectionalLight3D
@onready var sandbox = $Sandbox
var attr_dices = []
var roll_timer = null
var test_hero_id = 1
var start_timer: Timer
var is_in_initial_state = true
var base_width = 24.0  # 基础宽度（屏幕水平方向）
var base_height = 13.5   # 基础高度（屏幕竖直方向）
var is_charging: bool = false  # 是否正在蓄力
var original_positions: Dictionary = {}  # 存储骰子原始位置用于震动
var global_time: float = 0.0  # 添加全局时间变量

func _ready():
	# 打印场景初始化信息
	print("=== Attribute Dice Test Scene Initializing ===")
	
	# ✅ 使用 CameraManager 统一管理摄像机配置
	if camera:
		CameraManager.register_camera(camera)
		print("【摄像机】已注册到 CameraManager，使用统一配置")

	# 确保光照正确指向原点
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))
	
	# 获取窗口比例并调整沙盘尺寸，保持16:9比例
	var window_size = DisplayServer.window_get_size()
	var window_ratio = float(window_size.x) / float(window_size.y)
	print("窗口尺寸: %s, 比例: %.2f" % [window_size, window_ratio])
	
	# 计算基础尺寸，保持16:9比例
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width  # 屏幕水平方向（x轴）
	var sandbox_height = sandbox_width / base_ratio  # 屏幕竖直方向（z轴），保持16:9比例
	print("调整后沙盘尺寸 - 宽度: %.2f, 高度: %.2f, 比例: %.2f" % [sandbox_width, sandbox_height, sandbox_width / sandbox_height])
	
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
			var wall_north_shape = BoxShape3D.new()
			wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
			wall_north.position = Vector3(0, 21, -sandbox_height/2)
			wall_north.shape = wall_north_shape
		
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
			var wall_south_shape = BoxShape3D.new()
			wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
			wall_south.position = Vector3(0, 21, sandbox_height/2)
			wall_south.shape = wall_south_shape
		
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
			var wall_east_shape = BoxShape3D.new()
			wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
			wall_east.position = Vector3(sandbox_width/2, 21, 0)
			wall_east.shape = wall_east_shape
		
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
			var wall_west_shape = BoxShape3D.new()
			wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
			wall_west.position = Vector3(-sandbox_width/2, 21, 0)
			wall_west.shape = wall_west_shape
		
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
		
		# 打印墙体信息
		print("墙体信息:")
		print("北墙 - 名称: WallNorthMesh, 颜色: 蓝色, 位置: ", wall_north_mesh.position)
		print("南墙 - 名称: WallSouthMesh, 颜色: 红色, 位置: ", wall_south_mesh.position)
		print("东墙 - 名称: WallEastMesh, 颜色: 黄色, 位置: ", wall_east_mesh.position)
		print("西墙 - 名称: WallWestMesh, 颜色: 绿色, 位置: ", wall_west_mesh.position)

	# 增加重力加速度，加快骰子下落速度
	# 在Godot 4中，通过ProjectSettings来设置重力
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)  # 4倍重力加速度，加快下落速度
	print("Gravity set to 4x real-world acceleration: 39.2 m/s²")

	# 获取属性骰子管理器
	print("Looking for attr_dice_manager node...")
	if not attr_dice_manager:
		print("Error: attr_dice_manager not found")
		return
	
	# 创建属性骰子
	print("Creating attribute dices...")
	create_attribute_dices()
	
	# 创建启动计时器
	start_timer = Timer.new()
	start_timer.wait_time = 1.0
	start_timer.one_shot = true
	start_timer.timeout.connect(start_demo)
	add_child(start_timer)
	start_timer.start()
	
	print("Attribute dice test scene initialized")
	print("=== Initialization Complete ===")

func start_demo():
	# 标记为初始状态
	is_in_initial_state = true
	print("Demo started with dice in initial position")

func create_attribute_dices():
	# 创建力量、敏捷、智力三种属性骰子
	var scene = self

	# 根据文档设置骰子初始位置
	var initial_z = base_height / 2 - 2

	# 力量骰子
	var str_dice = attr_dice_manager.create_attribute_dice(test_hero_id, "str", scene)
	if str_dice:
		str_dice.position = Vector3(-4, 4, initial_z)
		str_dice.gravity_scale = 0.0  # 初始时禁用重力，使骰子悬浮
		attr_dices.append(str_dice)

	# 敏捷骰子
	var agi_dice = attr_dice_manager.create_attribute_dice(test_hero_id, "agi", scene)
	if agi_dice:
		agi_dice.position = Vector3(0, 4, initial_z)
		agi_dice.gravity_scale = 0.0  # 初始时禁用重力，使骰子悬浮
		attr_dices.append(agi_dice)

	# 智力骰子
	var int_dice = attr_dice_manager.create_attribute_dice(test_hero_id, "int", scene)
	if int_dice:
		int_dice.position = Vector3(4, 4, initial_z)
		int_dice.gravity_scale = 0.0  # 初始时禁用重力，使骰子悬浮
		attr_dices.append(int_dice)

	print("Created ", attr_dices.size(), " attribute dices")

func throw_dice():
	# ✅ 使用统一的投掷控制器进行普通投掷
	var dices = attr_dices
	DiceThrowController.throw_normal(dices, 1.0)
	
	# 3 秒后检查结果
	var result_timer = Timer.new()
	result_timer.wait_time = 3.0
	result_timer.one_shot = true
	result_timer.timeout.connect(_on_check_results)
	add_child(result_timer)
	result_timer.start()

func _on_check_results():
	# 检查所有属性骰子的结果
	print("=== Attribute Dice Results ===")
	for dice in attr_dices:
		if dice and is_instance_valid(dice):
			var attr_type = dice.get_attr_type()
			var attr_value = dice.get_attribute_value()
			var hero_id = dice.get_hero_id()
			print("Hero ", hero_id, " - ", attr_type, ": ", attr_value)

func reset_dice():
	# 重置骰子位置
	# 根据文档设置骰子初始位置
	var initial_z = base_height / 2 - 2
	
	for i in range(attr_dices.size()):
		var dice = attr_dices[i]
		if dice and is_instance_valid(dice):
			var positions = [-4, 0, 4]
			dice.position = Vector3(positions[i], 4, initial_z)
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			dice.gravity_scale = 0.0
	
	# 标记为初始状态
	is_in_initial_state = true
	print("Dices reset to initial state")

func update_hero_attributes():
	# 测试更新英雄属性
	attr_dice_manager.update_hero_attributes(test_hero_id)
	print("Updated hero attributes for hero ", test_hero_id)

func _process(delta):
	# 更新全局时间 (如果需要)
	global_time += delta

	# 蓄力阶段的提示更新（震动效果由 DiceThrowController._process 自动处理）
	if is_charging and is_in_initial_state:
		var charge_ratio = DiceThrowController.charge_ratio
		print("\r蓄力中... %d%%" % int(charge_ratio * 100))

func _input(event):
	# 空格键开始蓄力
	if event.is_action_pressed("ui_accept") and is_in_initial_state:
		is_charging = true
		# ✅ 使用统一的投掷控制器开始蓄力（传入骰子数组，自动处理震动）
		DiceThrowController.start_charge(attr_dices)
		print("开始蓄力...")

	# 空格键松开，投掷骰子
	elif event.is_action_released("ui_accept") and is_charging:
		is_charging = false
		# ✅ 使用统一的投掷控制器结束蓄力并投掷（不传参数，使用 start_charge 时记录的骰子）
		DiceThrowController.end_charge()

		# 清空原始位置
		original_positions.clear()
		print("投掷属性骰子！")
		is_in_initial_state = false
	
	# ✅ 按 Q 键切换高位视角
	if event.is_action_pressed("ui_home"):
		CameraManager.set_preset("high")
		print("【摄像机】切换至高位视角")
	
	# ✅ 按 End 键切换低位视角
	if event.is_action_pressed("ui_end"):
		CameraManager.set_preset("low")
		print("【摄像机】切换至低位视角")
	
	# ✅ 按 Page Up 键切换广角视角
	if event.is_action_pressed("ui_page_up"):
		CameraManager.set_preset("wide")
		print("【摄像机】切换至广角视角")
	
	# ✅ 按 Page Down 键重置为默认视角
	if event.is_action_pressed("ui_page_down"):
		CameraManager.reset_to_default()
		print("【摄像机】重置为默认视角")
	
	# 按 R 键重置骰子
	if event.is_action_pressed("ui_cancel"):
		reset_dice()
	# 按 U 键更新英雄属性
	if event.is_action_pressed("ui_up"):
		update_hero_attributes()

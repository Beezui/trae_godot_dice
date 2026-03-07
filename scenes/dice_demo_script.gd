extends Node3D

@onready var dice_manager = $DiceManager
@onready var camera = $Camera3D
@onready var light = $DirectionalLight3D
@onready var sandbox = $Sandbox
var start_timer: Timer
var throw_timer: Timer
var is_charging = false
var charge_time = 0.0
var max_charge_time = 2.0  # 最大蓄力时间（秒）
var max_force = 20.0  # 最大投掷力度增加到20
var original_positions = {}  # 存储每个骰子的原始位置
var global_time = 0.0  # 全局时间，用于持续震动
var base_width = 24.0  # 基础宽度（屏幕水平方向），放大1.5倍
var base_height = 13.5   # 基础高度（屏幕竖直方向），放大1.5倍
var is_in_initial_state = true  # 标记是否处于初始状态

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
		
		# 移除顶部碰撞形状，避免阻挡骰子下落
		# 注释掉顶部碰撞形状的创建代码，确保骰子能正常落到地面
		
		# 初始化骰子管理器
		if dice_manager:
			# 设置骰子数量为2（默认值）
			dice_manager.initialize_dice_pool()
			print("Dice manager initialized with %d dice" % dice_manager.get_dice_count())

	# 增加重力加速度，加快骰子下落速度
	# 在Godot 4中，通过ProjectSettings来设置重力
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)  # 4倍重力加速度，加快下落速度
	print("Gravity set to 4x real-world acceleration: 39.2 m/s²")

	# 创建启动计时器
	start_timer = Timer.new()
	start_timer.wait_time = 1.0
	start_timer.one_shot = true
	start_timer.timeout.connect(start_demo)
	add_child(start_timer)
	start_timer.start()

func start_demo():
	# 重置蓄力状态
	is_charging = false
	charge_time = 0.0
	original_positions.clear()  # 重置原始位置
	
	# 标记为初始状态
	is_in_initial_state = true
	
	# 初始化动态贴图系统
	initialize_dynamic_textures()
	
	print("Demo started with dice in initial position")

func initialize_dynamic_textures():
	# 初始化动态贴图系统
	if dice_manager:
		# 设置默认场景配置为 1001
		dice_manager.set_scene_config("1001")
		print("Dynamic textures initialized with 1001 scene config")

func set_scene_config(scene_name: String):
	# 切换场景配置
	if dice_manager:
		dice_manager.set_scene_config(scene_name)
		print("Set scene config to: " + scene_name)

func throw_dice():
	# 使用骰子管理器投掷所有骰子
	if dice_manager:
		dice_manager.throw_all_dice()
		# 标记为非初始状态
		is_in_initial_state = false

func throw_dice_with_charge():
	# 使用骰子管理器蓄力投掷所有骰子
	if dice_manager:
		var charge_ratio = charge_time / max_charge_time
		# 打印蓄力信息，用于调试
		print("蓄力比例: %.2f" % charge_ratio)
		dice_manager.throw_all_dice_with_charge(charge_ratio)
		# 标记为非初始状态
		is_in_initial_state = false

func _input(event):
	# 按空格键开始蓄力（只有在初始状态下才能蓄力）
	if event.is_action_pressed("ui_accept") and is_in_initial_state:
		is_charging = true
		charge_time = 0.0
		# 存储所有骰子的原始位置
		original_positions.clear()
		if dice_manager:
			for i in range(dice_manager.get_dice_count()):
				var dice = dice_manager.get_dice(i)
				if dice and is_instance_valid(dice):
					original_positions[dice.get_path()] = dice.position
		print("开始蓄力...")
	# 松开空格键投掷骰子
	elif event.is_action_released("ui_accept") and is_charging:
		is_charging = false
		# 重置原始位置，避免震动效果继续应用
		original_positions.clear()
		throw_dice_with_charge()
		print("投掷骰子！蓄力时间: %.2f秒" % charge_time)
	# 按R键恢复骰子初始状态
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_dice()
	# 按a键增加骰子（只有在初始状态下才能调整）
	if event is InputEventKey and event.pressed and event.keycode == KEY_A and is_in_initial_state:
		if dice_manager:
			var current_count = dice_manager.get_dice_count()
			if current_count < 6:
				dice_manager.set_dice_count(current_count + 1)
				print("增加骰子，当前数量: %d" % dice_manager.get_dice_count())
			else:
				print("已达到最大骰子数量: 6")
	# 按s键减少骰子（只有在初始状态下才能调整）
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and is_in_initial_state:
		if dice_manager:
			var current_count = dice_manager.get_dice_count()
			if current_count > 1:
				dice_manager.set_dice_count(current_count - 1)
				print("减少骰子，当前数量: %d" % dice_manager.get_dice_count())
			else:
				print("已达到最小骰子数量: 1")
	# 按1键切换到 1001 场景配置
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		set_scene_config("1001")
	# 按2键切换到 1002 场景配置
	if event is InputEventKey and event.pressed and event.keycode == KEY_2:
		set_scene_config("1002")

func _process(delta):
	# 跟踪全局时间
	global_time += delta
	
	# 跟踪蓄力时间
	if is_charging:
		charge_time += delta
		# 限制最大蓄力时间
		if charge_time > max_charge_time:
			charge_time = max_charge_time
			print("已达到最大蓄力！")
		
		# 计算蓄力比例
		var charge_ratio = charge_time / max_charge_time
		# 进一步减小震动幅度
		var shake_amplitude = charge_ratio * 0.05  # 最大震动幅度进一步减小为0.05
		# 增加震动频率（随蓄力时间增加）
		var shake_frequency = 15.0 + (charge_ratio * 25.0)  # 频率从15增加到40
		
		# 对所有骰子应用震动效果
		if dice_manager:
			for i in range(dice_manager.get_dice_count()):
				var dice = dice_manager.get_dice(i)
				if dice and is_instance_valid(dice):
					var dice_path = dice.get_path()
					if original_positions.has(dice_path):
						# 使用全局时间和频率生成持续震动
						var time = global_time * shake_frequency
						var shake_offset = Vector3(
							sin(time * 3.14159) * shake_amplitude,
							sin(time * 3.14159 * 1.5) * shake_amplitude,
							sin(time * 3.14159 * 2.0) * shake_amplitude
						)
						# 应用震动偏移
						dice.position = original_positions[dice_path] + shake_offset
	else:
		# 非蓄力状态下，清空原始位置
		original_positions.clear()
	
	# 更新骰子管理器
	if dice_manager:
		dice_manager.update(delta)

func reset_dice():
	# 重置蓄力状态
	is_charging = false
	charge_time = 0.0
	original_positions.clear()  # 重置原始位置
	
	# 使用骰子管理器重置所有骰子
	if dice_manager:
		dice_manager.reset_all_dice()
	
	# 标记为初始状态
	is_in_initial_state = true
	
	print("Dice reset to initial state")

func update_result_display(results: Array):
	# 显示骰子结果
	print("=== DICE RESULTS ===")
	print("Sorted results: ", results)
	print("Total dice: ", results.size())
	print("===================")

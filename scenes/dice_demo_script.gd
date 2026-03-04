extends Node3D

@onready var dice = $Dice
@onready var camera = $Camera3D
@onready var light = $DirectionalLight3D
@onready var sandbox = $Sandbox
var start_timer: Timer
var throw_timer: Timer
var is_charging = false
var charge_time = 0.0
var max_charge_time = 2.0  # 最大蓄力时间（秒）
var max_force = 20.0  # 最大投掷力度增加到20
var original_position = Vector3()  # 骰子原始位置
var global_time = 0.0  # 全局时间，用于持续震动
var base_width = 16.0  # 基础宽度（屏幕水平方向）
var base_height = 9.0   # 基础高度（屏幕竖直方向）

func _ready():
	# 调整摄像机位置和FOV，使其拉远并更接近2D效果
	if camera:
		# 设置摄像机位置，进一步拉远以看到墙体
		camera.position = Vector3(0, 30, 0)  # 进一步拉远摄像机
		# 保持当前FOV设置
		camera.fov = 30.0  # 保持当前FOV值
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
			wall_north_shape.size = Vector3(sandbox_width, 10, 0.1)
			wall_north.position = Vector3(0, 0, -sandbox_height/2)
			wall_north.shape = wall_north_shape
		
		# 创建北墙网格
		var wall_north_mesh = MeshInstance3D.new()
		wall_north_mesh.name = "WallNorthMesh"
		wall_north_mesh.position = Vector3(0, 1.5, -sandbox_height/2)
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
			wall_south_shape.size = Vector3(sandbox_width, 10, 0.1)
			wall_south.position = Vector3(0, 0, sandbox_height/2)
			wall_south.shape = wall_south_shape
		
		# 创建南墙网格
		var wall_south_mesh = MeshInstance3D.new()
		wall_south_mesh.name = "WallSouthMesh"
		wall_south_mesh.position = Vector3(0, 1.5, sandbox_height/2)
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
			wall_east_shape.size = Vector3(0.1, 10, sandbox_height)
			wall_east.position = Vector3(sandbox_width/2, 0, 0)
			wall_east.shape = wall_east_shape
		
		# 创建东墙网格
		var wall_east_mesh = MeshInstance3D.new()
		wall_east_mesh.name = "WallEastMesh"
		wall_east_mesh.position = Vector3(sandbox_width/2, 1.5, 0)
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
			wall_west_shape.size = Vector3(0.1, 10, sandbox_height)
			wall_west.position = Vector3(-sandbox_width/2, 0, 0)
			wall_west.shape = wall_west_shape
		
		# 创建西墙网格
		var wall_west_mesh = MeshInstance3D.new()
		wall_west_mesh.name = "WallWestMesh"
		wall_west_mesh.position = Vector3(-sandbox_width/2, 1.5, 0)
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
		
		# 创建顶部碰撞形状（防止骰子跳出摄像机视野）
		var wall_top = CollisionShape3D.new()
		wall_top.name = "WallTop"
		wall_top.position = Vector3(0, 8, 0)
		var wall_top_shape = BoxShape3D.new()
		wall_top_shape.size = Vector3(sandbox_width, 0.5, sandbox_height)
		wall_top.shape = wall_top_shape
		sandbox.add_child(wall_top)
		
		# 调整骰子初始位置（保持在沙盒内）
		if dice:
			# 设置初始位置（屏幕水平方向中心，靠近屏幕下方南墙）
			dice.position = Vector3(0, 4, sandbox_height/2 - 2)  # 靠近屏幕下方南墙，屏幕水平方向中心，向上提高2单位

	# 设置物理世界
	# 暂时注释掉，使用默认重力
	# var world = get_world_3d()
	# if world:
	# 	# 物理世界的访问方式在Godot 4中可能有所不同
	# 	# var physics_world = world.physics_world_3d
	# 	# if physics_world:
	# 	# 	physics_world.gravity = Vector3(0, -9.8, 0)

	# 创建启动计时器
	start_timer = Timer.new()
	start_timer.wait_time = 1.0
	start_timer.one_shot = true
	start_timer.timeout.connect(start_demo)
	add_child(start_timer)
	start_timer.start()

func start_demo():
	# 设置骰子初始状态：屏幕水平方向中心，靠近屏幕下方南墙
	if dice:
		# 计算16:9比例的沙盘高度
		var base_ratio = 16.0 / 9.0
		var sandbox_width = base_width  # 屏幕水平方向（x轴）
		var sandbox_height = sandbox_width / base_ratio  # 屏幕竖直方向（z轴），保持16:9比例
		# 设置初始位置（屏幕水平方向中心，靠近屏幕下方南墙）
		dice.position = Vector3(0, 4, sandbox_height/2 - 2)  # 靠近屏幕下方南墙，屏幕水平方向中心，向上提高2单位
		dice.rotation = Vector3()

	# 取消自动投掷计时器
	# throw_timer = Timer.new()
	# throw_timer.wait_time = 3.0
	# throw_timer.autostart = true
	# throw_timer.timeout.connect(throw_dice)
	# add_child(throw_timer)

func throw_dice():
	# 检查骰子节点是否存在
	if not dice:
		print("Error: Dice node not found")
		return
	
	# 检查骰子节点是否有roll方法
	if not dice.has_method("roll"):
		print("Error: Dice node does not have roll method")
		print("Dice node type:", dice.get_class())
		return
	
	# 计算16:9比例的沙盘高度
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width  # 屏幕水平方向（x轴）
	var sandbox_height = sandbox_width / base_ratio  # 屏幕竖直方向（z轴），保持16:9比例
	
	# 重置骰子位置（离地面5个骰子高度）
	dice.position = Vector3(0, 5, sandbox_height/2 - 2)  # 靠近屏幕下方南墙，屏幕水平方向中心
	dice.rotation = Vector3()
	
	# 生成随机投掷力，朝向屏幕上方的北墙
	var force = Vector3(
		randf_range(-2, 2),  # 较小的X方向随机力
		randf_range(5, 7.5),  # 向上的力
		randf_range(-10, -5)     # 朝向屏幕上方的力（Z负方向，北墙方向）
	)
	
	# 投掷骰子
	dice.roll(force)

func throw_dice_with_charge():
	# 检查骰子节点是否存在
	if not dice:
		print("Error: Dice node not found")
		return
	
	# 检查骰子节点是否有roll方法
	if not dice.has_method("roll"):
		print("Error: Dice node does not have roll method")
		return
	
	# 计算16:9比例的沙盘高度
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width  # 屏幕水平方向（x轴）
	var sandbox_height = sandbox_width / base_ratio  # 屏幕竖直方向（z轴），保持16:9比例
	
	# 重置骰子位置（离地面5个骰子高度）
	dice.position = Vector3(0, 5, sandbox_height/2 - 2)  # 靠近屏幕下方南墙，屏幕水平方向中心
	dice.rotation = Vector3()
	
	# 根据蓄力时间计算投掷力度
	var charge_ratio = charge_time / max_charge_time
	var force_magnitude = charge_ratio * max_force
	
	# 生成朝向屏幕上方的力，角度在-45到45度之间
	var angle = deg_to_rad(randf_range(-45, 45))
	var force = Vector3(
		sin(angle),  # X方向随角度变化
		0.5,  # 固定的向上力
		-1.0   # 朝向屏幕上方的Z负方向（北墙方向）
	).normalized() * force_magnitude
	
	# 投掷骰子
	dice.roll(force)

func _input(event):
	# 按空格键开始蓄力
	if event.is_action_pressed("ui_accept"):
		is_charging = true
		charge_time = 0.0
		# 记录骰子的原始位置
		if dice:
			original_position = dice.position
		print("开始蓄力...")
	# 松开空格键投掷骰子
	elif event.is_action_released("ui_accept") and is_charging:
		is_charging = false
		# 恢复骰子到原始位置
		if dice:
			dice.position = original_position
		throw_dice_with_charge()
		print("投掷骰子！蓄力时间: %.2f秒" % charge_time)
	# 按R键恢复骰子初始状态
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_dice()

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
		
		# 应用震动效果
		if dice and original_position != Vector3():
			# 使用全局时间和频率生成持续震动
			var time = global_time * shake_frequency
			var shake_offset = Vector3(
				sin(time * 3.14159) * shake_amplitude,
				sin(time * 3.14159 * 1.5) * shake_amplitude,
				sin(time * 3.14159 * 2.0) * shake_amplitude
			)
			# 应用震动偏移
			dice.position = original_position + shake_offset

func reset_dice():
	# 重置骰子到初始状态
	if dice:
		# 计算16:9比例的沙盘高度
		var base_ratio = 16.0 / 9.0
		var sandbox_width = base_width  # 屏幕水平方向（x轴）
		var sandbox_height = sandbox_width / base_ratio  # 屏幕竖直方向（z轴），保持16:9比例
		# 设置初始位置（屏幕水平方向中心，靠近屏幕下方南墙）
		dice.position = Vector3(0, 4, sandbox_height/2 - 2)  # 靠近屏幕下方南墙，屏幕水平方向中心，向上提高2单位
		dice.rotation = Vector3()
		# 确保骰子静止
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO
		# 禁用重力，使骰子悬浮
		dice.gravity_scale = 0.0
		print("Dice reset to initial state")

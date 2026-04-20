extends Node3D
## 命运骰子测试场景
## 集成 3D 沙盘、命运骰子系统和 2D 地图 UI

# Camera3D
@onready var camera = $Camera3D

# Sandbox
@onready var sandbox = $Sandbox

# DiceManager (autoload)
var dice_manager: Node = null

# 命运骰子管理器（autoload）
@onready var destiny_dice_manager = DestinyDiceManager.get_instance()

# 关卡转换控制器（autoload）
@onready var level_transition_controller = LevelTransitionController.get_instance()

# 地图 UI 覆盖层
var map_overlay: Control = null

# 当前关卡数据
var level_data: LevelData = null

# 当前所在节点
var current_node: LevelNode = null

# 蓄力状态
var is_charging: bool = false
var charge_start_time: float = 0.0
var original_dice_positions: Dictionary = {}

# 沙盘尺寸
var base_width = 24.0
var base_height = 13.5

# 投掷区域 z 坐标（靠近南墙）
var initial_z = 4.75


func _ready():
	print("=== 命运骰子测试场景初始化 ===")

	# 0. 获取 DiceManager 实例（autoload）
	dice_manager = DiceManager.get_instance()

	# 1. 注册摄像机到 CameraManager
	if camera:
		CameraManager.register_camera(camera)
		print("【摄像机】已注册到 CameraManager")

	# 2. 设置沙盘
	_setup_sandbox()

	# 3. 增加重力加速度
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)

	# 4. 生成关卡数据
	_generate_level_data()

	# 5. 创建地图 UI
	_create_map_overlay()

	# 6. 初始化命运骰子管理器
	_initialize_destiny_dice()

	# 7. 连接信号
	_connect_signals()

	print("=== 初始化完成 ===")


## 设置沙盘
func _setup_sandbox():
	var sandbox_width = base_width
	var sandbox_height = base_width / (16.0 / 9.0)

	# 创建地面碰撞
	var ground_collision = sandbox.get_node("Ground")
	if ground_collision:
		var ground_shape = BoxShape3D.new()
		ground_shape.size = Vector3(sandbox_width, 0.1, sandbox_height)
		ground_collision.shape = ground_shape

	# 地面物理材质
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

	print("【沙盘】创建完成，尺寸：", sandbox_width, " x ", sandbox_height)


## 生成关卡数据
func _generate_level_data():
	# LevelGenerator 是 autoload，使用实例调用
	var seed_value = Time.get_ticks_msec()
	var level_gen = LevelGenerator.get_instance()
	if level_gen:
		level_data = level_gen.generate_level(1, seed_value)
		if level_data:
			print("【关卡】生成成功，节点数：", level_data.total_nodes)
			# 设置起始节点
			if level_data.start_node_id:
				current_node = level_data.get_node(level_data.start_node_id)
				print("【关卡】起始节点：", current_node.id, " - ", current_node.name)
		else:
			push_error("【关卡】LevelGenerator 生成失败")
			# 创建测试数据
			level_data = _create_test_level_data()
	else:
		push_error("【关卡】LevelGenerator 未初始化")
		# 创建测试数据
		level_data = _create_test_level_data()


## 创建测试关卡数据（备用方案）
func _create_test_level_data() -> LevelData:
	var data = LevelData.new(1, 12345)

	# 创建起点
	var start_node = LevelNode.new("1", "起点", 2)
	start_node.is_start = true
	start_node.layer = 0
	data.add_node(start_node)

	# 创建连接的节点
	var node2 = LevelNode.new("2", "战斗 1", 1)
	node2.layer = 1
	data.add_node(node2)

	var node3 = LevelNode.new("3", "奇遇 1", 2)
	node3.layer = 1
	data.add_node(node3)

	var node4 = LevelNode.new("4", "交易 1", 3)
	node4.layer = 1
	data.add_node(node4)

	# 创建连接
	start_node.connections.append("2")
	start_node.connections.append("3")
	start_node.connections.append("4")

	node2.previous_nodes.append("1")
	node3.previous_nodes.append("1")
	node4.previous_nodes.append("1")

	# 创建终点
	var end_node = LevelNode.new("5", "终点", 1)
	end_node.is_end = true
	end_node.layer = 2
	data.add_node(end_node)

	node2.connections.append("5")
	node3.connections.append("5")
	node4.connections.append("5")

	print("【关卡】创建测试数据，节点数：5")
	return data


## 创建地图 UI 覆盖层
func _create_map_overlay():
	var map_overlay_scene = load("res://scripts/ui/destiny_dice_map_overlay.gd")
	if map_overlay_scene:
		var overlay_script = map_overlay_scene
		map_overlay = Control.new()
		map_overlay.name = "MapOverlay"
		map_overlay.set_script(overlay_script)
		add_child(map_overlay)

		# 初始化地图
		if map_overlay.has_method("initialize"):
			map_overlay.initialize(level_data, current_node)

		print("【地图 UI】创建成功")
	else:
		push_error("【地图 UI】无法加载地图脚本")
		# 创建简易地图
		_create_simple_map_overlay()


## 创建简易地图覆盖层（备用方案）
func _create_simple_map_overlay():
	map_overlay = Control.new()
	map_overlay.name = "MapOverlay"

	# 设置覆盖层布局（Godot 4.x）
	map_overlay.anchors_preset = Control.PRESET_FULL_RECT
	map_overlay.grow_horizontal = 2  # GROW_BOTH_ENDS
	map_overlay.grow_vertical = 2  # GROW_BOTH_ENDS

	# 创建地图绘制面板
	var map_panel = Panel.new()
	map_panel.name = "MapPanel"
	map_panel.position = Vector2(10, 10)
	map_panel.size = Vector2(400, 300)
	map_overlay.add_child(map_panel)

	# 创建信息标签
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.position = Vector2(20, 20)
	info_label.size = Vector2(380, 60)
	info_label.text = "命运骰子测试\n按 M 键切换地图\n按空格蓄力投掷"
	info_label.add_theme_font_size_override("font_size", 16)
	map_overlay.add_child(info_label)

	add_child(map_overlay)
	print("【地图 UI】创建简易版本")


## 初始化命运骰子
func _initialize_destiny_dice():
	if not destiny_dice_manager:
		push_error("【命运骰子】DestinyDiceManager 不存在")
		return

	# 设置 DiceManager 配置
	dice_manager.dice_scene = load("res://scenes/dice_6.tscn")
	dice_manager.dice_count = 1
	dice_manager.max_dice_count = 1

	# 初始化命运骰子管理器
	if current_node and level_data:
		var success = destiny_dice_manager.initialize(current_node, level_data)
		if success:
			print("【命运骰子】初始化成功")

			# 创建骰子实例（由 DestinyDiceManager 管理）
			destiny_dice_manager.create_destiny_dice(self)

			# 设置骰子位置（使用投掷区域标准位置）
			var dice_array = destiny_dice_manager.destiny_dice_instances
			if dice_array.size() > 0:
				for dice in dice_array:
					if dice and is_instance_valid(dice):
						dice.position = Vector3(0, 4, initial_z)
		else:
			push_error("【命运骰子】初始化失败")


## 连接信号
func _connect_signals():
	if destiny_dice_manager:
		if not destiny_dice_manager.on_destiny_dice_roll_completed.is_connected(_on_roll_completed):
			destiny_dice_manager.on_destiny_dice_roll_completed.connect(_on_roll_completed)


## 输入处理
func _process(_delta):
	# 处理蓄力状态更新和震动效果（震动由 DiceThrowController._process 自动处理）
	if is_charging and DiceThrowController:
		var charge_ratio = DiceThrowController.charge_ratio

		# 更新 UI 显示蓄力
		if map_overlay and map_overlay.has_method("update_charge"):
			map_overlay.update_charge(charge_ratio)


## 输入处理
func _input(event):
	# M 键切换地图
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_toggle_map()

	# 空格键开始蓄力
	if event.is_action_pressed("ui_accept") and not is_charging:
		is_charging = true
		_start_charge()

	# 空格键松开，投掷骰子
	if event.is_action_released("ui_accept") and is_charging:
		is_charging = false
		_end_charge_and_throw()

	# R 键重置骰子
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_dice()

	# 摄像机快捷键
	if event.is_action_pressed("ui_home"):
		CameraManager.set_preset("high")
	elif event.is_action_pressed("ui_end"):
		CameraManager.set_preset("low")
	elif event.is_action_pressed("ui_page_up"):
		CameraManager.set_preset("wide")
	elif event.is_action_pressed("ui_page_down"):
		CameraManager.reset_to_default()


## 切换地图显示
func _toggle_map():
	if map_overlay:
		map_overlay.visible = not map_overlay.visible
		print("【地图】", "显示" if map_overlay.visible else "隐藏")


## 开始蓄力
func _start_charge():
	if DiceThrowController:
		# 获取命运骰子实例
		var dices = destiny_dice_manager.destiny_dice_instances if destiny_dice_manager else []

		# 开始蓄力（传入骰子数组，自动处理震动）
		DiceThrowController.start_charge(dices)

		print("【蓄力】开始蓄力")


## 结束蓄力并投掷
func _end_charge_and_throw():
	if DiceThrowController and destiny_dice_manager:
		# 使用统一控制器结束蓄力并投掷（不传参数，使用 start_charge 时记录的骰子）
		DiceThrowController.end_charge()
		print("【投掷】投掷完成，等待骰子稳定...")

		# 等待骰子稳定（使用定时器，简单方案）
		var dices = destiny_dice_manager.destiny_dice_instances
		await _wait_for_dice_stable(dices)
		_process_roll_result()


## 等待骰子稳定
func _wait_for_dice_stable(dices: Array) -> void:
	# 等待骰子自身检测完成（包含 1.5 秒余韵时间）
	print("【投掷】等待骰子稳定（包含余韵 1.5 秒）...")

	# 轮询检查所有骰子的 is_rolling 状态
	var max_wait_frames = 300  # 约 5 秒（60fps）
	var wait_frames = 0

	while wait_frames < max_wait_frames:
		var all_stopped = true
		for dice in dices:
			if dice and is_instance_valid(dice):
				# 检查骰子是否还在滚动
				if dice.has_method("get_is_rolling"):
					if dice.get_is_rolling():
						all_stopped = false
						break
				elif dice.has_method("_on_roll_timer_timeout"):
					# 没有 get_is_rolling 方法，检查计时器
					if dice.has_node("roll_timer"):
						var timer = dice.get_node("roll_timer")
						if timer and not timer.is_stopped():
							all_stopped = false
							break

		if all_stopped:
			break

		await get_tree().process_frame
		wait_frames += 1

	if wait_frames >= max_wait_frames:
		print("【投掷】等待超时（", max_wait_frames / 60.0, "秒）")
	else:
		print("【投掷】骰子已稳定（耗时：", wait_frames / 60.0, "秒）")


## 处理投掷结果
func _process_roll_result():
	if destiny_dice_manager:
		print("【投掷】处理投掷结果")
		destiny_dice_manager.on_roll_completed()


## 投掷命运骰子（备用方法）
func _throw_destiny_dice():
	if destiny_dice_manager and destiny_dice_manager.destiny_dice_instances.size() > 0:
		print("【投掷】开始投掷命运骰子")
		destiny_dice_manager.throw_destiny_dice()


## 投掷完成回调
func _on_roll_completed(selected_node: LevelNode):
	print("【投掷完成】选择节点：", selected_node.id, " - ", selected_node.name)

	# 更新当前节点
	current_node = selected_node

	# 更新地图显示
	if map_overlay:
		print("【地图】准备更新地图显示")
		if map_overlay.has_method("update_current_node"):
			map_overlay.update_current_node(selected_node)
			print("【地图】已调用 update_current_node")
		else:
			print("【地图】map_overlay 没有 update_current_node 方法")
	else:
		print("【地图】map_overlay 为空")

	# 移动到目标节点（模拟关卡转换）
	_transition_to_node(selected_node)


## 关卡转换到目标节点
func _transition_to_node(target_node: LevelNode):
	if level_transition_controller:
		level_transition_controller.set_current_node(target_node)
		print("【关卡转换】已移动到节点：", target_node.name)

		# 重新初始化命运骰子（准备下一次投掷）
		call_deferred("_reinitialize_destiny_dice")


## 重新初始化命运骰子
func _reinitialize_destiny_dice():
	if destiny_dice_manager and level_data and current_node:
		# 清理旧骰子
		destiny_dice_manager.clear_dice_instances()

		# 重新初始化
		var success = destiny_dice_manager.initialize(current_node, level_data)
		if success:
			destiny_dice_manager.create_destiny_dice(dice_manager)

			# 设置骰子位置
			var dice_array = destiny_dice_manager.destiny_dice_instances
			if dice_array.size() > 0:
				for dice in dice_array:
					if dice and is_instance_valid(dice):
						dice.position = Vector3(0, 4, initial_z)

			print("【命运骰子】重新初始化完成")


## 重置骰子
func _reset_dice():
	if destiny_dice_manager:
		destiny_dice_manager.clear_dice_instances()
		destiny_dice_manager.create_destiny_dice(dice_manager)

		# 设置骰子位置
		var dice_array = destiny_dice_manager.destiny_dice_instances
		if dice_array.size() > 0:
			for dice in dice_array:
				if dice and is_instance_valid(dice):
					dice.position = Vector3(0, 4, initial_z)

		print("【骰子】已重置")

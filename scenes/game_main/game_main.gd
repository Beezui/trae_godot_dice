extends Node3D
## 游戏主入口场景
## 负责协调全局游戏流程，作为关卡网的初始入口

# 信号：游戏开始
signal on_game_started()
# 信号：游戏结束
signal on_game_ended(victory: bool)

# 场景节点
@onready var camera = $Camera3D
@onready var sandbox = $Sandbox
@onready var spawn_point = $SpawnPoint

# 管理器引用
var dice_manager: Node = null
var destiny_dice_manager: Node = null
var level_transition_controller: Node = null
var level_stage: Node = null

# 游戏数据
var level_data: LevelData = null
var current_node: LevelNode = null
var player_party: Array[int] = []  # 玩家选择的英雄 ID 列表

# 地图 UI 覆盖层
var map_overlay: Control = null

# 沙盘尺寸
var base_width: float = 24.0
var base_height: float = 13.5
var initial_z: float = 4.75  # 投掷区域 z 坐标

# 状态标记
var is_scene_loaded: bool = false
var is_player_spawned: bool = false
var is_dice_available: bool = false


func _ready():
	print("=== 游戏主入口场景初始化 ===")

	# 1. 获取单例管理器
	dice_manager = DiceManager.get_instance()
	destiny_dice_manager = DestinyDiceManager.get_instance()
	level_transition_controller = LevelTransitionController.get_instance()
	level_stage = LevelStage.get_instance()

	# 2. 注册摄像机
	if camera:
		CameraManager.register_camera(camera)

	# 3. 设置沙盘
	_setup_sandbox()

	# 4. 增加重力
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)

	# 5. 从 LevelTransitionController 获取玩家队伍
	# （角色选择后应该已经设置）
	_get_player_party()

	# 6. 生成关卡数据
	_generate_level_data()

	# 7. 设置初始节点（奖励关卡）
	_setup_start_node()

	# 8. 创建地图 UI（需要在 current_node 设置后初始化）
	_create_map_overlay()

	# 9. 连接信号
	_connect_signals()

	print("=== 游戏主入口场景初始化完成 ===")


## 获取玩家队伍
func _get_player_party():
	# 尝试从 GameManager 或其他全局管理器获取
	# 暂时从 LevelTransitionController 获取
	if level_transition_controller and level_transition_controller.has_meta("player_party"):
		player_party = level_transition_controller.get_meta("player_party")

	# 如果没有，使用测试数据
	if player_party.is_empty():
		player_party = [1]  # 默认使用英雄 ID=1
		print("【角色】未找到玩家队伍，使用测试数据：英雄 ID=1")
	else:
		print("【角色】玩家队伍：", player_party)


## 生成关卡数据
func _generate_level_data():
	var seed_value = Time.get_ticks_msec()
	var level_gen = level_generator  # 使用 autoload 直接访问

	if level_gen:
		level_data = level_gen.generate_level(1, seed_value)
		if level_data:
			print("【关卡】生成成功，节点数：", level_data.total_nodes)
		else:
			push_error("【关卡】生成失败")
			level_data = _create_test_level_data()
	else:
		push_error("【关卡】LevelGenerator 未初始化")
		level_data = _create_test_level_data()


## 创建测试关卡数据（备用方案）
func _create_test_level_data() -> LevelData:
	var data = LevelData.new(1, 12345)

	# 创建起点（奖励关卡）
	var start_node = LevelNode.new("1", "初始奖励", 4)
	start_node.is_start = true
	start_node.layer = 0
	data.add_node(start_node)

	# 创建战斗节点
	var node2 = LevelNode.new("2", "战斗 1", 1)
	node2.layer = 1
	data.add_node(node2)

	# 创建连接
	start_node.connections.append("2")
	node2.previous_nodes.append("1")

	# 创建终点
	var end_node = LevelNode.new("3", "终点", 1)
	end_node.is_end = true
	end_node.layer = 2
	data.add_node(end_node)

	node2.connections.append("3")

	print("【关卡】创建测试数据，节点数：3")
	return data


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

	# 创建四面墙
	_create_walls(sandbox_width, sandbox_height)

	print("【沙盘】创建完成，尺寸：", sandbox_width, " x ", sandbox_height)


## 创建围墙
func _create_walls(sandbox_width: float, sandbox_height: float):
	# 北墙
	var wall_north = sandbox.get_node("WallNorth")
	if wall_north:
		var wall_shape = BoxShape3D.new()
		wall_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_north.position = Vector3(0, 21, -sandbox_height/2)
		wall_north.shape = wall_shape

	var wall_north_mesh = MeshInstance3D.new()
	wall_north_mesh.name = "WallNorthMesh"
	wall_north_mesh.position = Vector3(0, -2.5, -sandbox_height/2)
	var wall_mesh = BoxMesh.new()
	wall_mesh.size = Vector3(sandbox_width, 3, 0.1)
	wall_north_mesh.mesh = wall_mesh
	var wall_material = StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.3, 0.3, 0.7, 1)
	wall_north_mesh.material_override = wall_material
	sandbox.add_child(wall_north_mesh)

	# 南墙
	var wall_south = sandbox.get_node("WallSouth")
	if wall_south:
		var wall_shape = BoxShape3D.new()
		wall_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_south.position = Vector3(0, 21, sandbox_height/2)
		wall_south.shape = wall_shape

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

	# 东墙
	var wall_east = sandbox.get_node("WallEast")
	if wall_east:
		var wall_shape = BoxShape3D.new()
		wall_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_east.position = Vector3(sandbox_width/2, 21, 0)
		wall_east.shape = wall_shape

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

	# 西墙
	var wall_west = sandbox.get_node("WallWest")
	if wall_west:
		var wall_shape = BoxShape3D.new()
		wall_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_west.position = Vector3(-sandbox_width/2, 21, 0)
		wall_west.shape = wall_shape

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


## 设置初始节点
func _setup_start_node():
	if not level_data:
		push_error("【关卡】关卡数据为空")
		return

	# 获取起始节点（奖励关卡）
	var start_node = level_data.get_node(level_data.start_node_id)
	if start_node:
		current_node = start_node
		print("【关卡】初始节点：", current_node.id, " - ", current_node.name)

		# 初始化 LevelTransitionController
		level_transition_controller.initialize(level_data)
		level_transition_controller.set_current_node(current_node)

		# 初始化 LevelStage
		level_stage.level_data = level_data

		# 玩家入场
		_spawn_player()
	else:
		push_error("【关卡】未找到起始节点")


## 玩家入场
func _spawn_player():
	print("【角色】玩家入场...")

	# 使用 CharacterManager 创建玩家角色
	var characters: Array[BaseCharacter] = []
	for hero_id in player_party:
		var character = CharacterManager.create_character(hero_id, "player")
		if character:
			characters.append(character)
			print("【角色】创建玩家角色：英雄 ID=", hero_id)

	# 使用 CharacterEnterManager 统一处理角色投掷入场
	var enter_manager = Engine.get_main_loop().root.get_node_or_null("CharacterEnterManager")
	if enter_manager:
		print("【角色入场】使用 CharacterEnterManager 处理入场")
		var results = await enter_manager.player_batch_enter(characters, sandbox)

		# 检查入场结果
		var success_count = 0
		for result in results:
			if result.get("success", false):
				success_count += 1

		print("【角色入场】入场完成，成功：", success_count, "/", characters.size())
	else:
		push_error("【角色入场】CharacterEnterManager 不可用，使用备用方案")
		_spawn_player_fallback()

	is_player_spawned = true

	# 玩家入场后，延迟生成命运骰子
	await get_tree().create_timer(1.0).timeout
	_spawn_destiny_dice()


## 玩家入场（备用方案）
func _spawn_player_fallback():
	print("【角色入场】备用方案：直接创建角色骰子")

	for hero_id in player_party:
		var character = CharacterManager.get_character(hero_id)
		if character:
			var dice_position = Vector3(0, 1.5, initial_z - 3)  # 靠近南侧
			var dice = DiceManager.create_character_dice(character, sandbox, dice_position)
			if dice:
				print("【角色】角色骰子已创建（备用方案）")


## 生成命运骰子
func _spawn_destiny_dice():
	print("【命运骰子】生成命运骰子...")

	# 设置 DestinyDiceManager 配置
	destiny_dice_manager.destiny_dice_scene = load("res://scenes/dice_6.tscn")
	destiny_dice_manager.dice_count = 1

	# 初始化命运骰子管理器
	var success = destiny_dice_manager.initialize(current_node, level_data)
	if success:
		print("【命运骰子】初始化成功")

		# 创建命运骰子实例
		destiny_dice_manager.create_destiny_dice(self)

		# 设置骰子位置（投掷区域）
		var dice_array = destiny_dice_manager.destiny_dice_instances
		if dice_array.size() > 0:
			for dice in dice_array:
				if dice and is_instance_valid(dice):
					dice.position = Vector3(0, 4, initial_z)

		is_dice_available = true
		print("【命运骰子】生成完成，可投掷")
	else:
		push_error("【命运骰子】初始化失败")


## 创建地图 UI 覆盖层
func _create_map_overlay():
	var map_overlay_script = load("res://scripts/ui/destiny_dice_map_overlay.gd")
	if map_overlay_script:
		map_overlay = Control.new()
		map_overlay.name = "MapOverlay"
		map_overlay.set_script(map_overlay_script)
		add_child(map_overlay)

		# 初始化地图
		if map_overlay.has_method("initialize"):
			map_overlay.initialize(level_data, current_node)

		print("【地图 UI】创建成功")
	else:
		push_error("【地图 UI】脚本加载失败")


## 连接信号
func _connect_signals():
	# 连接命运骰子投掷完成信号
	if destiny_dice_manager:
		if not destiny_dice_manager.on_destiny_dice_roll_completed.is_connected(_on_destiny_roll_completed):
			destiny_dice_manager.on_destiny_dice_roll_completed.connect(_on_destiny_roll_completed)

	# 连接关卡转换完成信号
	if level_transition_controller:
		if not level_transition_controller.on_transition_completed.is_connected(_on_transition_completed):
			level_transition_controller.on_transition_completed.connect(_on_transition_completed)


## 输入处理
func _input(event):
	# M 键切换地图
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_toggle_map()

	# 空格键投掷命运骰子
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if is_dice_available and not is_charging:
			_start_throw()

	if event is InputEventKey and not event.pressed and event.keycode == KEY_SPACE:
		if is_charging:
			_end_throw()


# 投掷相关变量
var is_charging: bool = false
var charge_start_time: float = 0.0


## 开始蓄力
func _start_throw():
	if not destiny_dice_manager:
		return

	is_charging = true
	charge_start_time = Time.get_ticks_msec()

	# 获取命运骰子实例
	var dices = destiny_dice_manager.destiny_dice_instances

	# 开始蓄力（使用 DiceThrowController）
	if DiceThrowController:
		DiceThrowController.start_charge(dices)

	print("【投掷】开始蓄力")


## 结束蓄力并投掷
func _end_throw():
	if not DiceThrowController or not destiny_dice_manager:
		return

	is_charging = false

	# 结束蓄力并投掷
	DiceThrowController.end_charge()

	print("【投掷】投掷完成，等待骰子稳定...")

	# 等待骰子稳定
	var dices = destiny_dice_manager.destiny_dice_instances
	await _wait_for_dice_stable(dices)

	# 处理投掷结果
	_process_roll_result()


## 等待骰子稳定
func _wait_for_dice_stable(dices: Array) -> void:
	print("【投掷】等待骰子稳定...")

	var max_wait_frames = 300  # 约 5 秒
	var wait_frames = 0

	while wait_frames < max_wait_frames:
		var all_stopped = true
		for dice in dices:
			if dice and is_instance_valid(dice):
				if dice.has_method("get_is_rolling"):
					if dice.get_is_rolling():
						all_stopped = false
						break

		if all_stopped:
			break

		await get_tree().process_frame
		wait_frames += 1

	print("【投掷】骰子已稳定（耗时：", wait_frames / 60.0, "秒）")


## 处理投掷结果
func _process_roll_result():
	if destiny_dice_manager:
		print("【投掷】处理投掷结果")
		destiny_dice_manager.on_roll_completed()


## 命运骰子投掷完成回调
func _on_destiny_roll_completed(selected_node: LevelNode):
	print("【投掷完成】选择节点：", selected_node.id, " - ", selected_node.name)

	# 更新当前节点
	current_node = selected_node

	# 更新地图显示
	if map_overlay and map_overlay.has_method("update_current_node"):
		map_overlay.update_current_node(selected_node)

	# 触发关卡转换
	_transition_to_node(selected_node)


## 关卡转换到目标节点
func _transition_to_node(target_node: LevelNode):
	if level_transition_controller:
		level_transition_controller.set_current_node(target_node)
		print("【关卡转换】目标节点：", target_node.name)

		# 使用 LoadingOverlay 进行场景切换
		_transition_with_loading(target_node)


## 使用加载动画进行场景转换
func _transition_with_loading(target_node: LevelNode):
	# 淡入黑色蒙版
	if LoadingOverlay:
		LoadingOverlay.fade_in(0.3)
		await LoadingOverlay.wait_fade_in()

	# 加载新场景（由 LevelStage 处理）
	var level_stage_node = LevelStage.get_instance()
	if level_stage_node:
		level_stage_node.transition_to_node(target_node)

	# 淡出黑色蒙版
	if LoadingOverlay:
		LoadingOverlay.fade_out(0.3)
		await LoadingOverlay.wait_fade_out()

	# 转换完成
	_on_transition_completed(target_node)


## 关卡转换完成回调
func _on_transition_completed(target_node: LevelNode):
	print("【关卡转换】完成，当前节点：", target_node.name)


## 切换地图显示
func _toggle_map():
	if map_overlay:
		map_overlay.visible = not map_overlay.visible
		print("【地图】", "显示" if map_overlay.visible else "隐藏")

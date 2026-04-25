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

# 贸易阶段状态
var is_trade_phase: bool = false
var is_discount_charging: bool = false


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


## 清理 Sandbox 中的角色骰子（贸易/战斗结束后调用）
func _cleanup_sandbox_characters():
	var enter_manager = Engine.get_main_loop().root.get_node_or_null("CharacterEnterManager")
	if enter_manager and enter_manager.has_method("cleanup_all_characters"):
		enter_manager.cleanup_all_characters(sandbox)
		print("【清理】Sandbox 角色骰子已清理")
	else:
		push_warning("【清理】CharacterEnterManager 不可用，尝试手动清理")
		_cleanup_sandbox_manual()


## 手动清理 Sandbox（CharacterEnterManager 不可用时）
func _cleanup_sandbox_manual():
	var dice_to_remove = []
	var hb_to_remove = []
	var hb_script = null
	if ResourceLoader.exists("res://scripts/ui/dice_health_bar_2d.gd"):
		hb_script = load("res://scripts/ui/dice_health_bar_2d.gd")
	for child in sandbox.get_children():
		if not is_instance_valid(child):
			continue
		# 识别血条节点（通过脚本匹配）
		if hb_script and child.get_script() == hb_script:
			hb_to_remove.append(child)
			continue
		if child is RigidBody3D:
			var dtype = child.get("dice_type")
			if str(dtype) == "character":
				for sub_child in child.get_children():
					if sub_child is Timer:
						sub_child.stop()
						for conn in sub_child.timeout.get_connections():
							sub_child.timeout.disconnect(conn.callable)
				child.set("is_rolling", false)
				dice_to_remove.append(child)
	for hb in hb_to_remove:
		hb.queue_free()
	for dice in dice_to_remove:
		dice.queue_free()
	print("【清理】手动清理了 ", dice_to_remove.size(), " 个角色骰子，", hb_to_remove.size(), " 个血条")


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

	# 安全清理：确保 Sandbox 没有残留骰子
	_cleanup_sandbox_characters()

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


## 生成命运骰子（通过 LevelTransitionController 统一启动）
func _spawn_destiny_dice():
	print("【命运骰子】启动命运骰子流程...")
	print("【命运骰子】level_transition_controller=", level_transition_controller, ", current_node=", current_node)
	print("【命运骰子】当前 destiny_dice_instances.size()=", destiny_dice_manager.destiny_dice_instances.size())
	print("【命运骰子】DestinyDiceManager 实例 ID=", destiny_dice_manager.get_instance_id() if destiny_dice_manager else "null")

	# 通过 LevelTransitionController 启动命运骰子流程
	var success = level_transition_controller.start_destiny_dice_flow(self)
	print("【命运骰子】start_destiny_dice_flow 结果: ", success)
	print("【命运骰子】创建后 destiny_dice_instances.size()=", destiny_dice_manager.destiny_dice_instances.size())
	print("【命运骰子】DestinyDiceManager 实例 ID=", destiny_dice_manager.get_instance_id() if destiny_dice_manager else "null")
	if success:
		# 调整骰子位置（覆盖默认位置）
		var dice_array = destiny_dice_manager.destiny_dice_instances
		if dice_array.size() > 0:
			for dice in dice_array:
				if dice and is_instance_valid(dice):
					dice.position = Vector3(0, 4, initial_z)

		is_dice_available = true
		print("【命运骰子】创建完成，可投掷")
	else:
		push_error("【命运骰子】启动失败")


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
	# 连接关卡转换完成信号（用于更新 UI 等后续处理）
	if level_transition_controller:
		if not level_transition_controller.on_transition_completed.is_connected(_on_transition_completed):
			level_transition_controller.on_transition_completed.connect(_on_transition_completed)
		if not level_transition_controller.on_game_clear_triggered.is_connected(_on_game_clear_triggered):
			level_transition_controller.on_game_clear_triggered.connect(_on_game_clear_triggered)


## 输入处理
func _input(event):
	# M 键切换地图
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_toggle_map()

	# 贸易阶段：空格键投掷折扣骰子
	if is_trade_phase and event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not is_discount_charging:
			_start_discount_throw()
			is_discount_charging = true
		elif not event.pressed and is_discount_charging:
			_execute_discount_throw()
			is_discount_charging = false
		return  # 贸易阶段不处理命运骰子投掷

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
	if not DiceThrowController:
		return

	is_charging = false

	# 结束蓄力并投掷
	DiceThrowController.end_charge()

	print("【投掷】投掷完成，命运骰子停止后自动处理结果")


## 关卡转换完成回调
func _on_transition_completed(target_node: LevelNode):
	print("【关卡转换】完成，当前节点：", target_node.name)

	# 更新当前节点引用
	current_node = target_node

	# 更新地图显示
	if map_overlay and map_overlay.has_method("update_current_node"):
		map_overlay.update_current_node(target_node)

	# 根据节点类型触发不同后续动作
	match target_node.type:
		LevelNodeType.Type.COMBAT, 5:  # 战斗 / 精英战斗
			print("【战斗】检测到战斗节点，启动 BattleManager")
			await _start_battle(target_node)
		LevelNodeType.Type.ADVENTURE:  # 奇遇
			print("【奇遇】检测到奇遇节点，等待后续实现")
			# TODO: 奇遇事件系统
		LevelNodeType.Type.TRADE:  # 交易
			print("【交易】检测到交易节点，启动贸易流程")
			await _start_trade(target_node)
		LevelNodeType.Type.REWARD:  # 奖励
			print("【奖励】检测到奖励节点，等待后续实现")
			# TODO: 奖励系统
		_:
			print("【未知】未知节点类型：", target_node.type)

	# 检查是否还有下一轮投掷
	if level_transition_controller.can_throw_again():
		await get_tree().create_timer(1.0).timeout
		_spawn_destiny_dice()
	else:
		print("【游戏】当前节点无连接，流程结束")
		_on_game_clear_triggered()


## 启动战斗流程
func _start_battle(node: LevelNode):
	print("【战斗】开始战斗流程，节点：", node.name)

	var battle_manager = BattleManager  # Autoload 单例
	if not battle_manager:
		push_error("【战斗】BattleManager 不可用")
		return

	# 初始化战斗
	var success = battle_manager.initialize_battle(node, player_party)
	if not success:
		push_error("【战斗】初始化失败")
		return

	# 开始战斗流程（使用 await 等待战斗完成）
	await battle_manager.start_battle()

	# 等待战斗结束信号
	await battle_manager.on_battle_finished
	print("【战斗】战斗结束，继续游戏流程")


## 启动贸易流程
func _start_trade(node: LevelNode):
	print("【贸易】开始贸易流程，节点：", node.name)

	is_trade_phase = true

	# 1. 商人优先入场
	await _trade_merchant_enter(node)

	# 2. 玩家入场
	await _trade_player_enter()

	# 3. 等待短暂延迟
	await get_tree().create_timer(1.0).timeout

	# 4. 生成折扣骰子（悬浮待投掷状态）
	_generate_discount_dice()

	# 5. 连接折扣骰子停止信号
	if not ShopManager.on_discount_dice_stopped.is_connected(_on_discount_dice_finished):
		ShopManager.on_discount_dice_stopped.connect(_on_discount_dice_finished)

	# 6. 初始化商店会话（加载道具、随机选择）
	var stage = node.data.get("stage", 1)
	ShopManager.initialize_trade_session(stage, CharacterManager.player_characters)

	# 7. 等待玩家投掷折扣骰子（通过 _input 处理），然后等待商店关闭
	print("【贸易】等待玩家投掷折扣骰子...")
	var discount_result = await _wait_for_discount_result()
	print("【贸易】折扣骰子结果：%d%%" % discount_result)

	# 8. 打开商店
	ShopManager.set_discount(discount_result)
	ShopManager.open_shop()

	# 9. 等待玩家点击前进（ShopManager 发射 on_trade_completed 信号）
	print("【贸易】等待玩家完成交易...")
	await ShopManager.on_trade_completed
	print("【贸易】交易结束，继续命运骰子流程")


## 等待折扣骰子结果
var _discount_result_ready: bool = false
var _discount_result_value: int = 0

func _on_discount_dice_finished(discount: int):
	_discount_result_ready = true
	_discount_result_value = discount
	print("【贸易】折扣骰子结果已就绪：", discount)


func _wait_for_discount_result() -> int:
	_discount_result_ready = false
	_discount_result_value = 0

	# 等待骰子停止
	while not _discount_result_ready:
		await get_tree().create_timer(0.2).timeout

	return _discount_result_value


## 贸易 - 商人入场
func _trade_merchant_enter(node: LevelNode):
	print("【贸易】商人入场...")

	# 从 EnemySelector 选择商人
	var stage = node.data.get("stage", 1)
	var merchant_data = EnemySelector.select_merchant(stage)
	if merchant_data.is_empty():
		push_warning("【贸易】没有找到商人，使用默认商人")
		merchant_data = {"id": "4", "name": "商人"}

	var merchant_id = int(merchant_data.get("id", "4"))

	# 使用 CharacterManager 创建商人角色
	var merchant = CharacterManager.create_character(merchant_id, "enemy")
	if not merchant:
		push_error("【贸易】商人创建失败")
		return

	# 使用 CharacterEnterManager 入场（从北侧，类似敌方）
	var enter_manager = Engine.get_main_loop().root.get_node_or_null("CharacterEnterManager")
	if enter_manager:
		var results = await enter_manager.enemy_batch_enter([merchant], sandbox)
		print("【贸易】商人入场完成")
	else:
		push_warning("【贸易】CharacterEnterManager 不可用，使用备用方案")
		_spawn_merchant_fallback(merchant)


## 贸易 - 商人入场备用方案
func _spawn_merchant_fallback(merchant):
	var dice = DiceManager.create_character_dice(merchant, sandbox, Vector3(0, 4, -6))
	if dice:
		print("【贸易】商人骰子已创建（备用方案）")


## 贸易 - 玩家入场
func _trade_player_enter():
	print("【贸易】玩家入场...")

	var characters: Array[BaseCharacter] = []
	for hero_id in player_party:
		var character = CharacterManager.create_character(hero_id, "player")
		if character:
			characters.append(character)

	var enter_manager = Engine.get_main_loop().root.get_node_or_null("CharacterEnterManager")
	if enter_manager:
		var results = await enter_manager.player_batch_enter(characters, sandbox)
		print("【贸易】玩家入场完成")


## 生成折扣骰子
var _discount_dice: RigidBody3D = null

func _generate_discount_dice():
	print("【贸易】生成折扣骰子...")

	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		push_error("【贸易】无法加载骰子场景")
		return

	var dice = dice_scene.instantiate()
	dice.name = "DiscountDice"
	dice.dice_type = "discount"
	dice.position = Vector3(4.0, 4.0, 6.0)

	# 应用折扣骰子贴图（百分比文字）
	var discount_values = ["0%", "10%", "10%", "15%", "20%", "50%"]
	var texture_config = {}
	for i in range(6):
		texture_config[i] = "discount_" + discount_values[i]

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, {})

	# 设置为悬浮状态
	dice.freeze = true
	dice.gravity_scale = 0.0
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.sleeping = true

	sandbox.add_child(dice)
	_discount_dice = dice

	print("【贸易】折扣骰子已生成，等待玩家投掷")


## 投掷折扣骰子（蓄力）
func _start_discount_throw():
	if not _discount_dice or not is_instance_valid(_discount_dice):
		return

	# 解除悬浮，开始蓄力
	_discount_dice.freeze = false
	_discount_dice.gravity_scale = 0.0
	_discount_dice.sleeping = false
	_discount_dice.is_rolling = true

	if DiceThrowController:
		DiceThrowController.start_charge([_discount_dice])


## 投掷折扣骰子（松开蓄力）
func _execute_discount_throw():
	if not _discount_dice or not is_instance_valid(_discount_dice):
		return

	if DiceThrowController:
		DiceThrowController.end_charge()

	# 等待骰子停止
	print("【贸易】等待折扣骰子停止...")
	if DiceResultDetector and _discount_dice:
		var is_stable = await DiceResultDetector.wait_for_dice_stable([_discount_dice], 5.0)
		if not is_stable:
			print("【贸易】等待折扣骰子稳定超时")

	# 获取结果
	var result = _get_discount_dice_result()
	print("【贸易】折扣骰子结果：", result)

	# 清理骰子
	if _discount_dice and is_instance_valid(_discount_dice):
		_discount_dice.queue_free()
	_discount_dice = null

	# 通知 ShopManager
	is_trade_phase = false
	ShopManager.set_discount(result)
	ShopManager.on_discount_dice_stopped.emit(result)


## 获取折扣骰子结果（使用统一检测器）
func _get_discount_dice_result() -> int:
	if not _discount_dice or not is_instance_valid(_discount_dice):
		return 0

	var discount_values = [0, 10, 10, 15, 20, 50]
	# 使用统一检测器计算朝上的面
	if DiceResultDetector:
		var face_value = DiceResultDetector.check_dice_value(_discount_dice)
		var face_index = face_value - 1
		if face_index >= 0 and face_index < 6:
			return discount_values[face_index]
	return 0


## 结算/通关触发
func _on_game_clear_triggered():
	print("【游戏】触发结算/通关")
	# TODO: 显示结算界面


## 切换地图显示
func _toggle_map():
	if map_overlay:
		map_overlay.visible = not map_overlay.visible
		print("【地图】", "显示" if map_overlay.visible else "隐藏")

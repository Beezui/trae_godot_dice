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
# HUD 工具栏（地图、技能装配等按钮）
var hud_toolbar: Control = null
# 技能装配 UI 覆盖层
var skill_equip_ui: Control = null

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

# 奇遇阶段状态
var is_adventure_phase: bool = false
var is_adventure_charging: bool = false
var adventure_dice_result_ready: bool = false
var adventure_dice_result_value: int = 0

# 奖励阶段状态
var is_reward_phase: bool = false
var is_reward_charging: bool = false
var reward_dice_result_ready: bool = false
var reward_dice_result_value: int = 0


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
	# 9. 创建 HUD 工具栏
	_create_hud_toolbar()

	# 10. 创建技能装配 UI
	_create_skill_equip_ui()

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


## 创建 HUD 工具栏
func _create_hud_toolbar():
	print("【HUD】开始创建工具栏...")
	var hud_scene = load("res://scenes/ui/main_hud.tscn")
	if hud_scene:
		print("【HUD】场景加载成功")
		hud_toolbar = hud_scene.instantiate()
		if hud_toolbar:
			# 显式设置位置和尺寸（Node3D 父节点下锚点布局不会自动计算）
			hud_toolbar.position = Vector2.ZERO
			hud_toolbar.size = get_viewport_rect().size
			hud_toolbar.visible = true
			add_child(hud_toolbar)
			print("【HUD】已添加到场景树，可见=", hud_toolbar.visible, " 尺寸=", hud_toolbar.size)
			# 连接信号
			if hud_toolbar.has_signal("on_map_toggled"):
				hud_toolbar.on_map_toggled.connect(_toggle_map)
			if hud_toolbar.has_signal("on_skill_equip_toggled"):
				hud_toolbar.on_skill_equip_toggled.connect(_toggle_skill_equip_ui)
			print("【HUD】工具栏创建成功")
		else:
			push_error("【HUD】工具栏实例化失败")
	else:
		push_error("【HUD】无法加载工具栏场景，路径: res://scenes/ui/main_hud.tscn")


## 创建技能装配 UI
func _create_skill_equip_ui():
	var equip_scene = load("res://scenes/ui/skill_equip_ui_new.tscn")
	if equip_scene:
		skill_equip_ui = equip_scene.instantiate()
		if skill_equip_ui:
			add_child(skill_equip_ui)
			skill_equip_ui.visible = false
			print("【HUD】技能装配 UI 创建成功")
		else:
			push_error("【HUD】技能装配 UI 实例化失败")
	else:
		push_error("【HUD】无法加载技能装配 UI 场景")


## 切换技能装配 UI
func _toggle_skill_equip_ui():
	if skill_equip_ui:
		if skill_equip_ui.visible:
			skill_equip_ui.close()
		else:
			skill_equip_ui.open()


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

	# 奇遇阶段：空格键投掷奇遇骰子
	if is_adventure_phase and event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not is_adventure_charging:
			_start_adventure_dice_throw()
			is_adventure_charging = true
		elif not event.pressed and is_adventure_charging:
			_execute_adventure_dice_throw()
			is_adventure_charging = false
		return  # 奇遇阶段不处理命运骰子投掷

	# 奖励阶段：空格键投掷奖励骰子
	if is_reward_phase and event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not is_reward_charging:
			_start_reward_dice_throw()
			is_reward_charging = true
		elif not event.pressed and is_reward_charging:
			_execute_reward_dice_throw()
			is_reward_charging = false
		return  # 奖励阶段不处理命运骰子投掷

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

	# 清理上一关卡的奇遇面板和奖励面板
	_cleanup_adventure_board()
	_cleanup_reward_board()

	# 根据节点类型触发不同后续动作
	match target_node.type:
		LevelNodeType.Type.COMBAT, 5:  # 战斗 / 精英战斗
			print("【战斗】检测到战斗节点，启动 BattleManager")
			await _start_battle(target_node)
		LevelNodeType.Type.ADVENTURE:  # 奇遇
			print("【奇遇】检测到奇遇节点，启动奇遇流程")
			await _start_adventure(target_node)
		LevelNodeType.Type.TRADE:  # 交易
			print("【交易】检测到交易节点，启动贸易流程")
			await _start_trade(target_node)
		LevelNodeType.Type.REWARD:  # 奖励
			print("【奖励】检测到奖励节点，启动奖励流程")
			await _start_reward(target_node)
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
	dice.position = Vector3(4.0, BattleManager.DICE_THROW_Y, BattleManager.PLAYER_DICE_Z)

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


# ==================== 奇遇流程 ====================

## 奇遇骰子实例
var _adventure_dice: RigidBody3D = null
var _adventure_board: Node3D = null


## 启动奇遇流程
func _start_adventure(node: LevelNode):
	print("【奇遇】开始奇遇流程，节点：", node.name)

	is_adventure_phase = true

	# 1. 清理 Sandbox 中的残留骰子
	_cleanup_sandbox_characters()

	# 2. 玩家入场
	await _adventure_player_enter(node)

	# 3. 获取奇遇事件配置（从节点数据中获取事件 ID）
	var event_id = _get_adventure_event_id(node)
	print("【奇遇】事件 ID: ", event_id)

	if event_id.is_empty():
		push_error("【奇遇】无法获取事件 ID")
		is_adventure_phase = false
		return

	# 4. 加载奇遇数据
	var success = AdventureManager.start_adventure(event_id)
	if not success:
		push_error("【奇遇】加载奇遇数据失败")
		is_adventure_phase = false
		return

	# 5. 显示奇遇界面
	_show_adventure_ui(event_id)

	# 6. 等待玩家阅读（延迟 2 秒）
	await get_tree().create_timer(2.0).timeout

	# 7. 生成奇遇骰子（面板保持可见，不隐藏）
	_generate_adventure_dice()

	# 10. 等待玩家投掷奇遇骰子（通过 _input 处理）
	print("【奇遇】等待玩家投掷奇遇骰子...")
	var dice_result = await _wait_for_adventure_dice_result()
	print("【奇遇】骰子结果：", dice_result)

	# 11. 根据骰子结果获取选项
	var result = AdventureManager.get_result_from_face(dice_result)
	if result.is_empty():
		push_error("【奇遇】无法获取结果")
		is_adventure_phase = false
		return

	print("【奇遇】选中选项：", result.get("name", ""), ", 效果：", result.get("des", ""))

	# 12. 执行效果
	var effect_result = AdventureManager.execute_effect(result.get("id", ""))
	if effect_result.get("success", false):
		print("【奇遇】效果执行成功：", effect_result.get("des", ""))
	else:
		push_warning("【奇遇】效果执行可能有问题")

	# 13. 显示效果描述（短暂停留）
	await get_tree().create_timer(1.5).timeout

	# 14. 清理
	_cleanup_adventure_dice()
	is_adventure_phase = false
	AdventureManager.end_adventure()

	print("【奇遇】奇遇流程结束，继续命运骰子流程")


## 获取奇遇事件 ID
func _get_adventure_event_id(node: LevelNode) -> String:
	# 优先从节点数据中获取 event_id
	if node.data.has("event_id"):
		return str(node.data["event_id"])

	# 备用：根据节点 ID 映射到默认事件 ID
	# TODO: 后续可以通过配置表映射
	var node_id = node.id
	# 简单的默认映射：循环使用现有事件
	var event_count = AdventureManager.adventure_events.size()
	if event_count > 0:
		var default_index = (int(node_id) % event_count) + 1
		return str(default_index)

	push_error("【奇遇】没有可用的奇遇事件")
	return ""


## 奇遇 - 玩家入场
func _adventure_player_enter(node: LevelNode):
	print("【奇遇】玩家入场...")

	var characters: Array[BaseCharacter] = []
	for hero_id in player_party:
		var character = CharacterManager.create_character(hero_id, "player")
		if character:
			characters.append(character)

	var enter_manager = Engine.get_main_loop().root.get_node_or_null("CharacterEnterManager")
	if enter_manager:
		var results = await enter_manager.player_batch_enter(characters, sandbox)
		print("【奇遇】玩家入场完成")


## 显示奇遇界面
func _show_adventure_ui(event_id: String):
	# 获取奇遇数据
	var event_data = AdventureManager.get_adventure_event(event_id)
	var results = AdventureManager.get_adventure_results(event_id)

	# 创建 3D 地面面板（先附加脚本和数据，再进入场景树）
	_adventure_board = Node3D.new()
	_adventure_board.name = "AdventureBoard"
	_adventure_board.position = Vector3(-5, 0.2, -1.5)
	var board_script = load("res://scripts/ui/adventure_board.gd")
	if board_script:
		_adventure_board.set_script(board_script)
	else:
		push_error("【奇遇】无法加载 adventure_board.gd")
		return
	sandbox.add_child(_adventure_board)

	# 显示面板（数据在 _ready 中用于构建 UI）
	_adventure_board.show_board(event_data, results)


## 隐藏奇遇3D面板
func _hide_adventure_ui():
	if _adventure_board and is_instance_valid(_adventure_board) and _adventure_board.has_method("hide_board"):
		await _adventure_board.hide_board()


## 清理奇遇3D面板
func _cleanup_adventure_board():
	if _adventure_board and is_instance_valid(_adventure_board):
		_adventure_board.queue_free()
	_adventure_board = null


## 生成奇遇骰子
func _generate_adventure_dice():
	print("【奇遇】生成奇遇骰子...")

	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		push_error("【奇遇】无法加载骰子场景")
		return

	var dice = dice_scene.instantiate()
	dice.name = "AdventureDice"
	dice.dice_type = "normal"
	dice.position = Vector3(0.0, BattleManager.DICE_THROW_Y, BattleManager.PLAYER_DICE_Z)

	# 获取奇遇骰子面配置（根据选项数量）
	var result_count = AdventureManager.current_results.size()
	var dice_config = AdventureManager.get_adventure_dice_config(result_count)
	var values = dice_config["values"] as Array
	var textures = dice_config["textures"] as Array

	# 创建贴图配置（使用 DiceTextureManager 的动态数字文字）
	var texture_config = {}
	var value_config = {}
	for i in range(6):
		value_config[i] = values[i] if i < values.size() else 1
		texture_config[i] = str(textures[i]) if i < textures.size() else "1"

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, value_config)

	# 设置为悬浮状态
	dice.freeze = true
	dice.gravity_scale = 0.0
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.sleeping = true

	sandbox.add_child(dice)
	_adventure_dice = dice

	print("【奇遇】奇遇骰子已生成，等待玩家投掷")


## 投掷奇遇骰子（蓄力）
func _start_adventure_dice_throw():
	if not _adventure_dice or not is_instance_valid(_adventure_dice):
		return

	# 解除悬浮，开始蓄力
	_adventure_dice.freeze = false
	_adventure_dice.gravity_scale = 0.0
	_adventure_dice.sleeping = false
	_adventure_dice.is_rolling = true

	if DiceThrowController:
		DiceThrowController.start_charge([_adventure_dice])


## 投掷奇遇骰子（松开蓄力）
func _execute_adventure_dice_throw():
	if not _adventure_dice or not is_instance_valid(_adventure_dice):
		return

	if DiceThrowController:
		DiceThrowController.end_charge()

	# 等待骰子停止
	print("【奇遇】等待奇遇骰子停止...")
	if DiceResultDetector and _adventure_dice:
		var is_stable = await DiceResultDetector.wait_for_dice_stable([_adventure_dice], 5.0)
		if not is_stable:
			print("【奇遇】等待奇遇骰子稳定超时")

	# 获取结果
	var result = _get_adventure_dice_result()
	print("【奇遇】骰子结果：", result)

	# 通知等待方
	adventure_dice_result_ready = true
	adventure_dice_result_value = result


## 等待奇遇骰子结果
func _wait_for_adventure_dice_result() -> int:
	adventure_dice_result_ready = false
	adventure_dice_result_value = 0

	# 等待骰子停止
	while not adventure_dice_result_ready:
		await get_tree().create_timer(0.2).timeout

	return adventure_dice_result_value


## 获取奇遇骰子结果
func _get_adventure_dice_result() -> int:
	if not _adventure_dice or not is_instance_valid(_adventure_dice):
		return 1

	# 使用统一检测器计算朝上的面
	if DiceResultDetector:
		var face_value = DiceResultDetector.check_dice_value(_adventure_dice)
		return face_value

	return 1


## 清理奇遇骰子
func _cleanup_adventure_dice():
	if _adventure_dice and is_instance_valid(_adventure_dice):
		_adventure_dice.queue_free()
	_adventure_dice = null


# ==================== 奖励流程 ====================

## 奖励骰子实例
var _reward_dice: RigidBody3D = null
var _reward_board: Node3D = null


## 启动奖励流程
func _start_reward(node: LevelNode):
	print("【奖励】开始奖励流程，节点：", node.name)

	is_reward_phase = true

	# 1. 清理 Sandbox 中的残留骰子
	_cleanup_sandbox_characters()

	# 2. 玩家入场
	await _reward_player_enter(node)

	# 3. 获取奖励事件配置（从节点数据中获取事件 ID）
	var event_id = _get_reward_event_id(node)
	print("【奖励】事件 ID: ", event_id)

	if event_id.is_empty():
		push_error("【奖励】无法获取事件 ID")
		is_reward_phase = false
		return

	# 4. 加载奖励数据
	var success = RewardManager.start_reward(event_id)
	if not success:
		push_error("【奖励】加载奖励数据失败")
		is_reward_phase = false
		return

	# 5. 显示奖励界面
	_show_reward_ui(event_id)

	# 6. 等待玩家阅读（延迟 2 秒）
	await get_tree().create_timer(2.0).timeout

	# 7. 生成奖励骰子（面板保持可见，不隐藏）
	_generate_reward_dice()

	# 8. 等待玩家投掷奖励骰子（通过 _input 处理）
	print("【奖励】等待玩家投掷奖励骰子...")
	var dice_result = await _wait_for_reward_dice_result()
	print("【奖励】骰子结果：", dice_result)

	# 9. 根据骰子结果获取选项
	var result = RewardManager.get_result_from_face(dice_result)
	if result.is_empty():
		push_error("【奖励】无法获取结果")
		is_reward_phase = false
		return

	print("【奖励】选中选项：", result.get("name", ""), ", 效果：", result.get("des", ""))

	# 10. 执行效果
	var effect_result = RewardManager.execute_effect(result.get("id", ""))
	if effect_result.get("success", false):
		print("【奖励】效果执行成功：", effect_result.get("des", ""))
	else:
		push_warning("【奖励】效果执行可能有问题")

	# 11. 显示效果描述（短暂停留）
	await get_tree().create_timer(1.5).timeout

	# 12. 清理
	_cleanup_reward_dice()
	is_reward_phase = false
	RewardManager.end_reward()

	print("【奖励】奖励流程结束，继续命运骰子流程")


## 获取奖励事件 ID
func _get_reward_event_id(node: LevelNode) -> String:
	# 优先从节点数据中获取 event_id
	if node.data.has("event_id"):
		return str(node.data["event_id"])

	# 备用：根据节点 ID 映射到默认事件 ID
	var node_id = node.id
	var event_count = RewardManager.reward_events.size()
	if event_count > 0:
		var default_index = (int(node_id) % event_count) + 1
		return str(default_index)

	push_error("【奖励】没有可用的奖励事件")
	return ""


## 奖励 - 玩家入场
func _reward_player_enter(node: LevelNode):
	print("【奖励】玩家入场...")

	var characters: Array[BaseCharacter] = []
	for hero_id in player_party:
		var character = CharacterManager.create_character(hero_id, "player")
		if character:
			characters.append(character)

	var enter_manager = Engine.get_main_loop().root.get_node_or_null("CharacterEnterManager")
	if enter_manager:
		var results = await enter_manager.player_batch_enter(characters, sandbox)
		print("【奖励】玩家入场完成")


## 显示奖励界面
func _show_reward_ui(event_id: String):
	# 获取奖励数据
	var event_data = RewardManager.get_reward_event(event_id)
	var results = RewardManager.get_reward_results(event_id)

	# 创建 3D 地面面板
	_reward_board = Node3D.new()
	_reward_board.name = "RewardBoard"
	_reward_board.position = Vector3(-5, 0.2, -1.5)
	var board_script = load("res://scripts/ui/reward_board.gd")
	if board_script:
		_reward_board.set_script(board_script)
	else:
		push_error("【奖励】无法加载 reward_board.gd")
		return
	sandbox.add_child(_reward_board)

	# 显示面板（数据在 _ready 中用于构建 UI）
	_reward_board.show_board(event_data, results)


## 隐藏奖励3D面板
func _hide_reward_ui():
	if _reward_board and is_instance_valid(_reward_board) and _reward_board.has_method("hide_board"):
		await _reward_board.hide_board()


## 清理奖励3D面板
func _cleanup_reward_board():
	if _reward_board and is_instance_valid(_reward_board):
		_reward_board.queue_free()
	_reward_board = null


## 生成奖励骰子
func _generate_reward_dice():
	print("【奖励】生成奖励骰子...")

	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		push_error("【奖励】无法加载骰子场景")
		return

	var dice = dice_scene.instantiate()
	dice.name = "RewardDice"
	dice.dice_type = "normal"
	dice.position = Vector3(0.0, BattleManager.DICE_THROW_Y, BattleManager.PLAYER_DICE_Z)

	# 获取奖励骰子面配置（根据选项数量）
	var result_count = RewardManager.current_results.size()
	var dice_config = RewardManager.get_reward_dice_config(result_count)
	var values = dice_config["values"] as Array
	var textures = dice_config["textures"] as Array

	# 创建贴图配置
	var texture_config = {}
	var value_config = {}
	for i in range(6):
		value_config[i] = values[i] if i < values.size() else 1
		texture_config[i] = str(textures[i]) if i < textures.size() else "1"

	if dice.has_method("set_dice_face_config"):
		dice.set_dice_face_config(texture_config, value_config)

	# 设置为悬浮状态
	dice.freeze = true
	dice.gravity_scale = 0.0
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.sleeping = true

	sandbox.add_child(dice)
	_reward_dice = dice

	print("【奖励】奖励骰子已生成，等待玩家投掷")


## 投掷奖励骰子（蓄力）
func _start_reward_dice_throw():
	if not _reward_dice or not is_instance_valid(_reward_dice):
		return

	# 解除悬浮，开始蓄力
	_reward_dice.freeze = false
	_reward_dice.gravity_scale = 0.0
	_reward_dice.sleeping = false
	_reward_dice.is_rolling = true

	if DiceThrowController:
		DiceThrowController.start_charge([_reward_dice])


## 投掷奖励骰子（松开蓄力）
func _execute_reward_dice_throw():
	if not _reward_dice or not is_instance_valid(_reward_dice):
		return

	if DiceThrowController:
		DiceThrowController.end_charge()

	# 等待骰子停止
	print("【奖励】等待奖励骰子停止...")
	if DiceResultDetector and _reward_dice:
		var is_stable = await DiceResultDetector.wait_for_dice_stable([_reward_dice], 5.0)
		if not is_stable:
			print("【奖励】等待奖励骰子稳定超时")

	# 获取结果
	var result = _get_reward_dice_result()
	print("【奖励】骰子结果：", result)

	# 通知等待方
	reward_dice_result_ready = true
	reward_dice_result_value = result


## 等待奖励骰子结果
func _wait_for_reward_dice_result() -> int:
	reward_dice_result_ready = false
	reward_dice_result_value = 0

	# 等待骰子停止
	while not reward_dice_result_ready:
		await get_tree().create_timer(0.2).timeout

	return reward_dice_result_value


## 获取奖励骰子结果
func _get_reward_dice_result() -> int:
	if not _reward_dice or not is_instance_valid(_reward_dice):
		return 1

	# 使用统一检测器计算朝上的面
	if DiceResultDetector:
		var face_value = DiceResultDetector.check_dice_value(_reward_dice)
		return face_value

	return 1


## 清理奖励骰子
func _cleanup_reward_dice():
	if _reward_dice and is_instance_valid(_reward_dice):
		_reward_dice.queue_free()
	_reward_dice = null

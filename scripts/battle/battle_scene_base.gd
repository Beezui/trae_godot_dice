class_name BattleSceneBase
extends Node3D
## 战斗场景基类
## 所有战斗场景都应继承此类

## 信号：战斗完成
signal on_battle_completed(victory: bool)

## 场景配置
@export var sandbox_width: float = 24.0
@export var sandbox_height: float = 13.5
@export var camera_height: float = 50.0
@export var camera_fov: float = 15.0

## 节点引用
@onready var camera: Camera3D = $Camera3D
@onready var light: DirectionalLight3D = $DirectionalLight3D
@onready var sandbox: Node3D = $Sandbox
@onready var battle_ui: Control = $BattleUI
@onready var skill_bar = $BattleUI/SkillBar  # BattleSkillBar 类型

## 当前关卡节点
var current_level_node: LevelNode = null
## 玩家队伍（英雄 ID 列表）
var player_party: Array[int] = []
## 战斗是否已结束
var battle_finished: bool = false


func _ready():
	print("【BattleSceneBase】战斗场景已就绪")
	_setup_camera()
	_setup_light()
	_setup_sandbox()
	_setup_battle_ui()

	# 注册摄像机到 CameraManager
	if CameraManager and camera:
		CameraManager.register_camera(camera)


func _setup_camera():
	if camera:
		camera.position = Vector3(1.3, camera_height, 14.1)
		camera.rotation = Vector3(-75 * PI/180, 5.1 * PI/180, -4.9 * PI/180)
		camera.fov = camera_fov
		print("【BattleSceneBase】摄像机已设置")


func _setup_light():
	if light:
		light.look_at_from_position(
			light.position,
			Vector3.ZERO,
			Vector3(0, 1, 0)
		)
		print("【BattleSceneBase】灯光已设置")


func _setup_sandbox():
	if not sandbox:
		sandbox = Node3D.new()
		sandbox.name = "Sandbox"
		add_child(sandbox)

	# 创建地面
	_create_sandbox_floor()
	# 创建墙壁
	_create_sandbox_walls()

	print("【BattleSceneBase】沙盘已设置")


func _create_sandbox_floor():
	var floor_mesh = BoxMesh.new()
	floor_mesh.size = Vector3(sandbox_width, 0.5, sandbox_height)

	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.2, 0.2, 0.2, 1.0)

	var floor = MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.material_override = floor_material
	floor.position = Vector3(0, -0.25, 0)
	floor.name = "Floor"

	sandbox.add_child(floor)

	# 添加碰撞体
	var floor_collision = StaticBody3D.new()
	floor_collision.name = "FloorCollision"

	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(sandbox_width, 0.5, sandbox_height)

	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = floor_shape
	floor_collision.add_child(collision_shape)
	floor_collision.position = Vector3(0, -0.25, 0)

	sandbox.add_child(floor_collision)


func _create_sandbox_walls():
	var wall_material_north = StandardMaterial3D.new()
	wall_material_north.albedo_color = Color(0.2, 0.4, 0.8, 1.0)

	var wall_material_south = StandardMaterial3D.new()
	wall_material_south.albedo_color = Color(0.8, 0.2, 0.2, 1.0)

	var wall_material_east = StandardMaterial3D.new()
	wall_material_east.albedo_color = Color(0.8, 0.8, 0.2, 1.0)

	var wall_material_west = StandardMaterial3D.new()
	wall_material_west.albedo_color = Color(0.2, 0.8, 0.2, 1.0)

	# 北墙
	var north_wall = _create_wall(
		Vector3(sandbox_width, 2, 0.5),
		Vector3(0, 1, -sandbox_height/2 - 0.25),
		wall_material_north,
		"NorthWall"
	)
	sandbox.add_child(north_wall)

	# 南墙
	var south_wall = _create_wall(
		Vector3(sandbox_width, 2, 0.5),
		Vector3(0, 1, sandbox_height/2 + 0.25),
		wall_material_south,
		"SouthWall"
	)
	sandbox.add_child(south_wall)

	# 东墙
	var east_wall = _create_wall(
		Vector3(0.5, 2, sandbox_height),
		Vector3(sandbox_width/2 + 0.25, 1, 0),
		wall_material_east,
		"EastWall"
	)
	sandbox.add_child(east_wall)

	# 西墙
	var west_wall = _create_wall(
		Vector3(0.5, 2, sandbox_height),
		Vector3(-sandbox_width/2 - 0.25, 1, 0),
		wall_material_west,
		"WestWall"
	)
	sandbox.add_child(west_wall)


func _create_wall(size: Vector3, position: Vector3, material: StandardMaterial3D, name: String) -> MeshInstance3D:
	var wall_mesh = BoxMesh.new()
	wall_mesh.size = size

	var wall = MeshInstance3D.new()
	wall.mesh = wall_mesh
	wall.material_override = material
	wall.position = position
	wall.name = name

	# 添加碰撞体
	var collision = StaticBody3D.new()
	collision.name = name + "Collision"
	wall.add_child(collision)

	var col_shape = BoxShape3D.new()
	col_shape.size = size

	var col_node = CollisionShape3D.new()
	col_node.shape = col_shape
	collision.add_child(col_node)

	return wall


func _setup_battle_ui():
	if not battle_ui:
		battle_ui = _create_battle_ui()
		add_child(battle_ui)

	# 获取技能栏引用
	if skill_bar:
		skill_bar.on_skill_selected.connect(_on_skill_selected)
		skill_bar.on_end_turn_pressed.connect(_on_end_turn_pressed)

	print("【BattleSceneBase】战斗 UI 已设置")


func _create_battle_ui() -> Control:
	var ui = Control.new()
	ui.name = "BattleUI"
	ui.anchors_preset = Control.PRESET_FULL_RECT

	# 创建技能栏容器
	var skill_bar_container = Control.new()
	skill_bar_container.name = "SkillBarContainer"
	skill_bar_container.anchors_preset = Control.PRESET_BOTTOM_WIDE
	skill_bar_container.anchor_bottom = 1.0
	skill_bar_container.offset_top = -100
	skill_bar_container.offset_left = 20
	skill_bar_container.offset_right = -20

	ui.add_child(skill_bar_container)

	return ui


## 初始化战斗
## @param level_node 关卡节点
## @param party 玩家队伍
func initialize_battle(level_node: LevelNode, party: Array[int]):
	print("【BattleSceneBase】初始化战斗...")
	current_level_node = level_node
	player_party = party

	# 初始化战斗管理器
	if BattleManager:
		var success = BattleManager.initialize_battle(level_node, party)
		if not success:
			push_error("【BattleSceneBase】战斗初始化失败")
			return

	# 连接战斗管理器信号
	_connect_battle_signals()


func _connect_battle_signals():
	if not BattleManager:
		return

	BattleManager.on_battle_started.connect(_on_battle_started)
	BattleManager.on_battle_finished.connect(_on_battle_finished)
	BattleManager.on_turn_started.connect(_on_turn_started)
	BattleManager.on_turn_ended.connect(_on_turn_ended)
	BattleManager.on_battle_phase_changed.connect(_on_battle_phase_changed)


func _on_battle_started():
	print("【BattleSceneBase】战斗开始")


func _on_battle_finished(winner: String):
	print("【BattleSceneBase】战斗结束，胜利者：", winner)
	battle_finished = true

	var victory = (winner == "player")
	on_battle_completed.emit(victory)

	# 显示战斗统计
	var stats = BattleManager.get_battle_stats()
	if skill_bar:
		skill_bar.show_battle_stats(stats)


func _on_turn_started(turn_owner: String):
	print("【BattleSceneBase】回合开始：", turn_owner)
	if skill_bar:
		skill_bar.show_turn_start(turn_owner)


func _on_turn_ended(turn_owner: String):
	print("【BattleSceneBase】回合结束：", turn_owner)
	if skill_bar:
		skill_bar.show_turn_end(turn_owner)


func _on_battle_phase_changed(old_phase: String, new_phase: String):
	print("【BattleSceneBase】战斗阶段变更：", old_phase, " -> ", new_phase)


func _on_skill_selected(skill_dice, character):
	print("【BattleSceneBase】技能被选择：", character.name)
	# 这里应该打开技能选择 UI 或直接使用技能
	# TODO: 实现技能使用逻辑


func _on_end_turn_pressed():
	print("【BattleSceneBase】玩家结束回合")
	if BattleManager:
		BattleManager.player_end_turn()


## 开始战斗流程
func start_battle_flow():
	if BattleManager:
		await BattleManager.start_battle()


## 清理战斗
func cleanup_battle():
	print("【BattleSceneBase】清理战斗...")

	# 断开信号
	_disconnect_battle_signals()

	# 清空角色
	if CharacterManager:
		CharacterManager.clear_all_characters()

	battle_finished = false


func _disconnect_battle_signals():
	if not BattleManager:
		return

	BattleManager.on_battle_started.disconnect(_on_battle_started)
	BattleManager.on_battle_finished.disconnect(_on_battle_finished)
	BattleManager.on_turn_started.disconnect(_on_turn_started)
	BattleManager.on_turn_ended.disconnect(_on_turn_ended)
	BattleManager.on_battle_phase_changed.disconnect(_on_battle_phase_changed)


## 虚拟方法（子类重写）

## 加载关卡配置
func load_level_config(_level_node: LevelNode):
	"""子类重写此方法加载特定关卡配置"""
	pass


## 生成敌人
func spawn_enemies():
	"""子类重写此方法生成敌人"""
	pass


## 生成玩家骰子
func spawn_player_dices():
	"""子类重写此方法生成玩家骰子"""
	pass


## 处理玩家输入
func _input(_event):
	pass


## 更新逻辑
func _process(_delta):
	pass


## 获取技能栏引用
func get_skill_bar() -> Control:
	"""获取技能栏 UI 引用"""
	return skill_bar

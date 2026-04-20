extends Node3D

## 角色测试场景
## 用于测试角色系统、投掷功能和结果检测

@onready var camera = $Camera3D
@onready var light = $DirectionalLight3D
@onready var sandbox = $Sandbox
@onready var charge_label = $ChargeLabel
@onready var hp_label = $HPLabel

var is_charging = false
var base_width = 24.0
var base_height = 13.5

# 玩家角色 (hero_id = 1)
var player_character: PlayerCharacter

# 角色骰子引用
var character_dice: RigidBody3D

# 属性骰子引用
var str_dice: RigidBody3D
var agi_dice: RigidBody3D
var int_dice: RigidBody3D

# 属性骰子管理器
var attr_dice_manager

# 技能骰子引用
var skill_dice: RigidBody3D


# 骰子 CSV 读取器
var dice_csv_reader


func _ready():
	print("=== 角色测试场景初始化 ===")
	
	# 初始化骰子 CSV 读取器
	dice_csv_reader = preload("res://scripts/dice_csv_reader.gd").new()
	
	# 初始化属性骰子管理器
	attr_dice_manager = preload("res://scenes/attr_dice_manager.gd").new()
	add_child(attr_dice_manager)
	
	# ✅ 使用 CameraManager 统一管理摄像机配置
	if camera:
		CameraManager.register_camera(camera)
		print("【摄像机】已注册到 CameraManager，使用统一配置")
	
	# 设置光源
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))
	
	# 计算沙盘尺寸
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width
	var sandbox_height = sandbox_width / base_ratio
	
	# 创建沙盘
	if sandbox:
		_setup_sandbox(sandbox_width, sandbox_height)
	
	# 设置重力
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)
	
	# 创建玩家角色 (使用 hero_id = 1)
	_create_player_character()
	
	# 创建 UI
	_setup_ui()
	
	# 启动延迟创建骰子
	var start_timer = Timer.new()
	start_timer.wait_time = 1.0
	start_timer.one_shot = true
	start_timer.timeout.connect(_on_start_timer_timeout)
	add_child(start_timer)
	start_timer.start()
	
	print("=== 角色测试场景初始化完成 ===")


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
	
	# 创建北墙碰撞形状（屏幕上方，z 轴负方向）
	var wall_north = sandbox.get_node("WallNorth")
	if wall_north:
		var wall_north_shape = BoxShape3D.new()
		wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
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
	
	# 创建南墙碰撞形状（屏幕下方，z 轴正方向）
	var wall_south = sandbox.get_node("WallSouth")
	if wall_south:
		var wall_south_shape = BoxShape3D.new()
		wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
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
	
	# 创建东墙碰撞形状（屏幕右侧，x 轴正方向）
	var wall_east = sandbox.get_node("WallEast")
	if wall_east:
		var wall_east_shape = BoxShape3D.new()
		wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
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
	
	# 创建西墙碰撞形状（屏幕左侧，x 轴负方向）
	var wall_west = sandbox.get_node("WallWest")
	if wall_west:
		var wall_west_shape = BoxShape3D.new()
		wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
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


func _create_player_character():
	# 使用 CharacterManager 创建玩家角色 (hero_id = 1)
	if CharacterManager:
		player_character = CharacterManager.create_character(1, "player")
		if player_character:
			print("【场景】玩家角色创建成功：", player_character.name)
			print("【场景】HP: ", player_character.current_hp, "/", player_character.attr_hp)
		else:
			printerr("【场景】玩家角色创建失败")
	else:
		printerr("【场景】CharacterManager 未加载")


func _setup_ui():
	# 创建蓄力标签
	if charge_label:
		charge_label.position = Vector2(20, 20)
		charge_label.text = "按空格键投掷骰子"
	
	# 创建 HP 标签
	if hp_label:
		hp_label.position = Vector2(20, 50)
		hp_label.text = "HP: 100/100"


func _on_start_timer_timeout():
	# 创建角色骰子
	_create_character_dice()
	
	# 注意：属性骰子和技能骰子会在角色骰子落地后自动生成（见 _on_character_dice_land）
	
	# 更新 HP 显示
	_update_hp_display()


func _create_character_dice():
	# 加载骰子场景
	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		printerr("【场景】无法加载骰子场景")
		return
	
	# 从 hero.json 读取角色贴图配置
	var hero_config = player_character.get_config()
	var hero_texture_ids = hero_config.get("hero_textures", [])
	var hero_id = hero_config.get("hero_id", 1)
	
	# 构建贴图配置：使用 hero.json 中的 hero_texture 字段
	var scene_config = {}
	for i in range(6):
		if i < hero_texture_ids.size():
			var texture_state = hero_texture_ids[i]
			var texture_path = "res://textures/hero/hero_" + str(hero_id) + "_" + texture_state + ".png"
			scene_config[i] = texture_path
			print("【场景】角色骰子面 ", i, " 贴图：", texture_path)
		else:
			var default_path = "res://textures/hero/hero_" + str(hero_id) + "_idle.png"
			scene_config[i] = default_path
			print("【场景】角色骰子面 ", i, " 使用默认贴图：", default_path)
	
	# 点数配置使用默认值 1-6
	var value_config = {0: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: 6}
	
	# 创建角色骰子
	character_dice = dice_scene.instantiate()
	
	# 玩家角色从屏幕下方（南墙内侧）投掷，NPC 从上方（北墙内侧）投掷
	# 初始位置必须在沙盘内，否则会被墙挡住
	var is_player = player_character.is_player_controlled
	var throw_start_z = (base_height/2 - 2) if is_player else (-base_height/2 + 2)  # 玩家：4.75（南墙内），NPC：-4.75（北墙内）
	var random_x = randf_range(-base_width/4, base_width/4)  # x 轴随机范围：-6 到 6
	character_dice.position = Vector3(random_x, 8, throw_start_z)  # y=8 从高处落下
	character_dice.scale = Vector3(1, 1, 1)
	sandbox.add_child(character_dice)
	
	# 启用重力
	character_dice.gravity_scale = 1.0
	
	# 设置骰子配置
	if character_dice.has_method("set_dice_face_config"):
		character_dice.set_dice_face_config(scene_config, value_config)
	
	# 设置骰子类型为角色骰子
	if character_dice.has_method("set_dice_type"):
		character_dice.set_dice_type("character")

	# 将角色骰子与角色关联（用于血条更新）
	if player_character:
		player_character.character_dice = character_dice
		# 设置骰子与角色的关联（用于血条更新）
		if character_dice.has_method("set_character"):
			character_dice.set_character(player_character)
			print("【场景】角色骰子已与角色关联，默认缩放：", player_character.dice_scale)
	
	# 自动投掷：玩家角色向前（z 负方向），NPC 向后（z 正方向）
	var throw_direction = -1 if is_player else 1  # 玩家：-1（向前），NPC: 1（向后）
	var throw_force = Vector3(0, -5, throw_direction * 20)  # 向前/后方投掷
	var angular_force = Vector3(
		randf_range(-10, 10),
		randf_range(-10, 10),
		randf_range(-10, 10)
	)
	
	if character_dice.has_method("roll"):
		# 延迟投掷，确保配置已应用
		var throw_timer = Timer.new()
		throw_timer.wait_time = 0.3
		throw_timer.one_shot = true
		throw_timer.timeout.connect(func():
			character_dice.roll(throw_force, angular_force)
			print("【场景】角色骰子自动投掷：力 =", throw_force, ", 旋转 =", angular_force)
			
			# 投掷后延迟生成属性骰子和技能骰子（等待角色骰子基本停止）
			var spawn_timer = Timer.new()
			spawn_timer.wait_time = 2.0  # 2 秒后生成
			spawn_timer.one_shot = true
			spawn_timer.timeout.connect(_on_character_dice_land)
			add_child(spawn_timer)
			spawn_timer.start()
		)
		add_child(throw_timer)
		throw_timer.start()
	
	print("【场景】角色骰子已创建，入场位置：", character_dice.position, ", 类型：", "玩家" if is_player else "NPC")


func _on_character_dice_land():
	"""角色骰子落地后生成属性骰子和技能骰子"""
	print("【场景】角色骰子已落地，开始生成属性骰子和技能骰子")
	_create_attribute_dices()
	_create_skill_dices()


func _create_attribute_dices():
	# 使用 AttrDiceManager 创建属性骰子（hero_id = 1）
	# 投掷区域标准：z = sandbox_height/2 - 2 = 4.75
	var initial_z = base_height / 2 - 2  # 4.75
	
	# 力量骰子
	str_dice = attr_dice_manager.create_attribute_dice(1, "str", sandbox)
	if str_dice:
		str_dice.position = Vector3(-1, 4, initial_z)  # 使用自动布局计算的位置
		print("【场景】力量骰子已创建，位置：", str_dice.position)
	
	# 敏捷骰子
	agi_dice = attr_dice_manager.create_attribute_dice(1, "agi", sandbox)
	if agi_dice:
		agi_dice.position = Vector3(1, 4, initial_z)  # 使用自动布局计算的位置
		print("【场景】敏捷骰子已创建，位置：", agi_dice.position)
	
	# 智力骰子
	int_dice = attr_dice_manager.create_attribute_dice(1, "int", sandbox)
	if int_dice:
		int_dice.position = Vector3(3, 4, initial_z)  # 使用自动布局计算的位置
		print("【场景】智力骰子已创建，位置：", int_dice.position)
	
	# 关联属性骰子到角色
	if player_character:
		player_character.attribute_dices["str"] = str_dice
		player_character.attribute_dices["agi"] = agi_dice
		player_character.attribute_dices["int"] = int_dice
	
	print("【场景】属性骰子已创建 (str, agi, int)，位于投掷区域")


func _create_skill_dices():
	print("\n=== 开始创建技能骰子 ===")
	print("【技能骰子】player_character = ", player_character)
	if player_character:
		print("【技能骰子】player_character.skill_slot = ", player_character.skill_slot)
	
	var dice_scene = load("res://scenes/dice_6.tscn")
	if not dice_scene:
		printerr("【技能骰子】无法加载骰子场景")
		return
	
	# 投掷区域标准：z = sandbox_height/2 - 2 = 4.75
	var initial_z = base_height / 2 - 2  # 4.75
	
	# 创建技能骰子 (根据 skill_slot)
	if player_character and player_character.skill_slot > 0:
		print("【技能骰子】开始创建技能骰子...")
		skill_dice = dice_scene.instantiate()
		skill_dice.position = Vector3(-3, 4, initial_z)  # 使用自动布局计算的位置（4 个骰子最左侧）
		sandbox.add_child(skill_dice)
		print("【技能骰子】骰子实例已创建，位置：", skill_dice.position)
		
		# 设置骰子类型为 skill
		if skill_dice.has_method("set_dice_type"):
			skill_dice.set_dice_type("skill")
			print("【技能骰子】已设置 dice_type = skill")
		
		# 从 CSV 读取技能骰子配置 (使用 skill_dice_id = 4001)
		var skill_config = dice_csv_reader.get_skill_dice_config("4001")
		print("【技能骰子】skill_config = ", skill_config)
		var skill_ids_array = skill_config.get("skill_ids", [])
		print("【技能骰子】skill_ids_array = ", skill_ids_array)
		
		# 技能骰子需要从 skill.json 获取贴图
		# 构建贴图配置和值配置（转换为字典格式）
		# 注意：value_config 必须是整数类型，因为 dice_value 是 int
		# 技能骰子的值使用面索引 (0-5)，技能 ID 通过贴图配置关联
		var scene_config = {}
		var value_config = {}
		if skill_ids_array.size() > 0:
			var skill_reader = preload("res://scripts/skill_csv_reader.gd").new()
			for i in range(6):
				if i < skill_ids_array.size():
					var skill_id = skill_ids_array[i]
					if skill_id and skill_id != "0":
						var skill_data = skill_reader.get_skill(skill_id)
						if skill_data and skill_data.has("icon"):
							# 注意：skill.json 的 icon 是 "10001"，但文件是 "skill_10001.png"
							scene_config[i] = "res://textures/skill/skill_" + skill_data["icon"] + ".png"
						# value_config 使用面索引（整数），而不是技能 ID（字符串）
						value_config[i] = i + 1  # 1-6
					else:
						value_config[i] = i + 1
				else:
					value_config[i] = i + 1
		
		print("【技能骰子】scene_config = ", scene_config)
		print("【技能骰子】value_config = ", value_config)
		
		# 设置技能骰子配置（使用统一的 set_dice_face_config 方法）
		if skill_dice.has_method("set_dice_face_config"):
			skill_dice.set_dice_face_config(scene_config, value_config)
			print("【技能骰子】已应用配置（通过 DiceTextureManager 统一管理）")
		
		# 关联技能骰子到角色
		player_character.skill_dices.append(skill_dice)
		
		print("【技能骰子】技能骰子已创建，使用配置 4001，位于投掷区域")
	else:
		print("【技能骰子】不满足创建条件：player_character = ", player_character, ", skill_slot = ", player_character.skill_slot if player_character else "N/A")


func _update_hp_display():
	if hp_label and player_character:
		hp_label.text = "HP: %d/%d" % [player_character.current_hp, player_character.attr_hp]


func _process(delta):
	if is_charging and DiceThrowController:
		var charge_ratio = DiceThrowController.charge_ratio
		if charge_label:
			charge_label.text = "蓄力：%d%%" % int(charge_ratio * 100)


func _input(event):
	if event.is_action_pressed("ui_accept"):  # 空格键
		is_charging = true
	if DiceThrowController:
		# 开始蓄力（传入骰子数组，自动处理震动）
		var throwable_dices = get_throwable_dices()
		DiceThrowController.start_charge(throwable_dices)
	if charge_label:
		charge_label.text = "开始蓄力..."

	elif event.is_action_released("ui_accept"):
		is_charging = false
		if charge_label:
			charge_label.text = "按空格键投掷骰子"

		# 投掷所有骰子（使用 start_charge 时记录的骰子）
		if DiceThrowController:
			DiceThrowController.end_charge()
	
	elif event.is_action_pressed("ui_home"):  # Home 键：测试受击
		if player_character:
			player_character.take_damage(10)
			_update_hp_display()
			print("【场景】玩家受到 10 点伤害")
	
	elif event.is_action_pressed("ui_end"):  # End 键：测试治疗
		if player_character:
			player_character.heal(10)
			_update_hp_display()
			print("【场景】玩家恢复 10 点 HP")
	
	# ✅ 摄像机控制快捷键
	elif event.is_action_pressed("ui_page_up"):
		CameraManager.set_preset("wide")
		print("【摄像机】切换至广角视角")
	elif event.is_action_pressed("ui_page_down"):
		CameraManager.reset_to_default()
		print("【摄像机】重置为默认视角")


func get_all_dices() -> Array:
	var dices = []
	if character_dice:
		dices.append(character_dice)
	if str_dice:
		dices.append(str_dice)
	if agi_dice:
		dices.append(agi_dice)
	if int_dice:
		dices.append(int_dice)
	if skill_dice:
		dices.append(skill_dice)
	return dices


func get_throwable_dices() -> Array:
	# 获取可投掷的骰子（排除角色骰子）
	var dices = []
	if str_dice:
		dices.append(str_dice)
	if agi_dice:
		dices.append(agi_dice)
	if int_dice:
		dices.append(int_dice)
	if skill_dice:
		dices.append(skill_dice)
	return dices


func on_dice_stopped():
	# 骰子停止时的回调
	print("【场景】骰子已停止")

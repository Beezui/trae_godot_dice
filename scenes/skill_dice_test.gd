extends Node3D

@onready var camera = $Camera3D
@onready var sandbox = $Sandbox
@onready var light = $DirectionalLight3D
@onready var attacker_dice = $AttackerDice
@onready var skill_dice = $SkillDice
@onready var target_dice1 = $TargetDice1
@onready var target_dice2 = $TargetDice2
@onready var marker = $Marker3D

@onready var charge_label = $ChargeLabel

# 属性骰子管理器
var attr_dice_manager = null
var power_dice = null
var agility_dice = null
var intelligence_dice = null

var base_width = 24.0
var base_height = 13.5

var dice_csv_reader
var skill_csv_reader: RefCounted
var skill_system: RefCounted
var fireball_scene: Node = null
var power_dice_result: int = 0
var agility_dice_result: int = 0
var intelligence_dice_result: int = 0
var is_skill_active: bool = false
var current_skill_id: String = "10001"
var skill_attribute_dice: Dictionary = {}

var is_charging: bool = false
var is_preparation_mode: bool = true
var original_positions: Dictionary = {}

# 兼容旧代码的变量 (已废弃，保留以避免编译错误)
var dices_thrown: bool = false
var dice_are_stopping: bool = false
var all_dices_stopped: bool = false
var global_time: float = 0.0

var skill_dice_result: int = 0
var skill_dice_result_id: String = ""


func _ready():
	dice_csv_reader = preload("res://scripts/dice_csv_reader.gd").new()
	skill_csv_reader = preload("res://scripts/skill_csv_reader.gd").new()
	skill_system = preload("res://scripts/skill_system.gd").new()
	
	# 初始化属性骰子管理器（使用全局单例）
	attr_dice_manager = $AttributeDiceManager
	
	_load_skill_config()
	
	# ✅ 使用 CameraManager 统一管理摄像机配置
	_setup_camera()
	_setup_light()
	_setup_sandbox()
	_setup_attribute_dices()
	_setup_skill_dice()
	_setup_particles()
	
	await get_tree().process_frame
	
	reset_scene()


func _load_skill_config():
	var skill = skill_system.get_skill(current_skill_id)
	if skill.is_empty():
		print("Error: Skill ", current_skill_id, " not found!")
		return
	skill_attribute_dice = skill.get("attribute_dice", {})


func _setup_camera():
	# ✅ 使用 CameraManager 统一管理摄像机配置
	if camera:
		CameraManager.register_camera(camera)
		print("【摄像机】已注册到 CameraManager，使用统一配置")


func _setup_light():
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))


func _setup_sandbox():
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width
	var sandbox_height = sandbox_width / base_ratio
	
	if sandbox:
		var ground_collision = sandbox.get_node("Ground")
		if ground_collision:
			var ground_shape = BoxShape3D.new()
			ground_shape.size = Vector3(sandbox_width, 0.1, sandbox_height)
			ground_collision.shape = ground_shape
			
		var ground_physics_material = PhysicsMaterial.new()
		ground_physics_material.bounce = 0.3
		ground_physics_material.friction = 0.8
		sandbox.physics_material_override = ground_physics_material
		
		var ground_mesh = sandbox.get_node("GroundMesh")
		if ground_mesh:
			var ground_mesh_resource = BoxMesh.new()
			ground_mesh_resource.size = Vector3(sandbox_width, 0.1, sandbox_height)
			ground_mesh.mesh = ground_mesh_resource
			
			var ground_material = StandardMaterial3D.new()
			ground_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
			ground_mesh.material_override = ground_material
		
		var wall_north_shape = BoxShape3D.new()
		wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
		var wall_north = CollisionShape3D.new()
		wall_north.name = "WallNorth"
		wall_north.shape = wall_north_shape
		wall_north.position = Vector3(0, 21, -sandbox_height/2)
		sandbox.add_child(wall_north)
		
		var wall_north_mesh = MeshInstance3D.new()
		wall_north_mesh.name = "WallNorthMesh"
		wall_north_mesh.position = Vector3(0, 1.5, -sandbox_height/2)
		var wall_north_mesh_resource = BoxMesh.new()
		wall_north_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
		wall_north_mesh.mesh = wall_north_mesh_resource
		var north_wall_material = StandardMaterial3D.new()
		north_wall_material.albedo_color = Color(0.3, 0.3, 0.7, 1)
		wall_north_mesh.material_override = north_wall_material
		sandbox.add_child(wall_north_mesh)
		
		var wall_south_shape = BoxShape3D.new()
		wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
		var wall_south = CollisionShape3D.new()
		wall_south.name = "WallSouth"
		wall_south.shape = wall_south_shape
		wall_south.position = Vector3(0, 21, sandbox_height/2)
		sandbox.add_child(wall_south)
		
		var wall_south_mesh = MeshInstance3D.new()
		wall_south_mesh.name = "WallSouthMesh"
		wall_south_mesh.position = Vector3(0, 1.5, sandbox_height/2)
		var wall_south_mesh_resource = BoxMesh.new()
		wall_south_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
		wall_south_mesh.mesh = wall_south_mesh_resource
		var south_wall_material = StandardMaterial3D.new()
		south_wall_material.albedo_color = Color(0.7, 0.3, 0.3, 1)
		wall_south_mesh.material_override = south_wall_material
		sandbox.add_child(wall_south_mesh)
		
		var wall_east_shape = BoxShape3D.new()
		wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
		var wall_east = CollisionShape3D.new()
		wall_east.name = "WallEast"
		wall_east.shape = wall_east_shape
		wall_east.position = Vector3(sandbox_width/2, 21, 0)
		sandbox.add_child(wall_east)
		
		var wall_east_mesh = MeshInstance3D.new()
		wall_east_mesh.name = "WallEastMesh"
		wall_east_mesh.position = Vector3(sandbox_width/2, 1.5, 0)
		var wall_east_mesh_resource = BoxMesh.new()
		wall_east_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
		wall_east_mesh.mesh = wall_east_mesh_resource
		var east_wall_material = StandardMaterial3D.new()
		east_wall_material.albedo_color = Color(0.7, 0.7, 0.3, 1)
		wall_east_mesh.material_override = east_wall_material
		sandbox.add_child(wall_east_mesh)
		
		var wall_west_shape = BoxShape3D.new()
		wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
		var wall_west = CollisionShape3D.new()
		wall_west.name = "WallWest"
		wall_west.shape = wall_west_shape
		wall_west.position = Vector3(-sandbox_width/2, 21, 0)
		sandbox.add_child(wall_west)
		
		var wall_west_mesh = MeshInstance3D.new()
		wall_west_mesh.name = "WallWestMesh"
		wall_west_mesh.position = Vector3(-sandbox_width/2, 1.5, 0)
		var wall_west_mesh_resource = BoxMesh.new()
		wall_west_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
		wall_west_mesh.mesh = wall_west_mesh_resource
		var west_wall_material = StandardMaterial3D.new()
		west_wall_material.albedo_color = Color(0.3, 0.7, 0.3, 1)
		wall_west_mesh.material_override = west_wall_material
		sandbox.add_child(wall_west_mesh)

	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)


func _setup_attribute_dices():
	# 使用 attr_dice_manager 创建正式的属性骰子（参考 attr_dice_test.tscn）
	var test_hero_id = 1  # 使用 hero id: 1
	
	# 力量骰子
	power_dice = attr_dice_manager.create_attribute_dice(test_hero_id, "str", self)
	if power_dice:
		power_dice.position = Vector3(-2, 4, 6)
		power_dice.gravity_scale = 0.0  # 初始时禁用重力，使骰子悬浮
		power_dice.visible = true
	
	# 敏捷骰子
	agility_dice = attr_dice_manager.create_attribute_dice(test_hero_id, "agi", self)
	if agility_dice:
		agility_dice.position = Vector3(0, 4, 6)
		agility_dice.gravity_scale = 0.0
		agility_dice.visible = true
	
	# 智力骰子
	intelligence_dice = attr_dice_manager.create_attribute_dice(test_hero_id, "int", self)
	if intelligence_dice:
		intelligence_dice.position = Vector3(2, 4, 6)
		intelligence_dice.gravity_scale = 0.0
		intelligence_dice.visible = true
	
	print("【属性骰子】创建了 ", 3, " 个属性骰子（使用 attr_dice_manager）")


func _setup_skill_dice():
	if skill_dice and is_instance_valid(skill_dice):
		skill_dice.position = Vector3(-4, 4, 6)
		skill_dice.visible = true
		skill_dice.gravity_scale = 0.0
		skill_dice.linear_velocity = Vector3.ZERO
		skill_dice.angular_velocity = Vector3.ZERO
		if skill_dice.has_method("set_freeze"):
			skill_dice.set_freeze(true)
		elif "freeze" in skill_dice:
			skill_dice.freeze = true
		
		var skill_dice_config = dice_csv_reader.get_skill_dice_config("4001")
		if not skill_dice_config.is_empty():
			var skill_ids = skill_dice_config.get("skill_ids", [])
			var texture_config = {}
			for i in range(6):
				if i < skill_ids.size():
					var skill_id = skill_ids[i]
					var skill_data = skill_system.get_skill(skill_id)
					if not skill_data.is_empty():
						texture_config[i] = "res://textures/skill/skill_" + skill_id + ".png"
					else:
						texture_config[i] = "res://textures/skill/default.png"
			
			var value_config = {}
			for i in range(6):
				value_config[i] = i + 1
			
			if texture_config.size() > 0 and skill_dice.has_method("set_dice_face_config"):
				skill_dice.set_dice_face_config(texture_config, value_config)
	
	if skill_dice and is_instance_valid(skill_dice):
		skill_dice.skip_skill_trigger = true
	
	if attacker_dice and is_instance_valid(attacker_dice):
		attacker_dice.position = Vector3(-6, 0.5, 0)
		attacker_dice.visible = true
		attacker_dice.gravity_scale = 0.0
		attacker_dice.linear_velocity = Vector3.ZERO
		attacker_dice.angular_velocity = Vector3.ZERO
		if attacker_dice.has_method("set_freeze"):
			attacker_dice.set_freeze(true)
		elif "freeze" in attacker_dice:
			attacker_dice.freeze = true
	
	if target_dice1 and is_instance_valid(target_dice1):
		target_dice1.position = Vector3(6, 0.5, -2)
		target_dice1.visible = true
		target_dice1.gravity_scale = 0.0
		target_dice1.linear_velocity = Vector3.ZERO
		target_dice1.angular_velocity = Vector3.ZERO
		if target_dice1.has_method("set_freeze"):
			target_dice1.set_freeze(true)
		elif "freeze" in target_dice1:
			target_dice1.freeze = true
	
	if target_dice2 and is_instance_valid(target_dice2):
		target_dice2.position = Vector3(6, 0.5, 2)
		target_dice2.visible = true
		target_dice2.gravity_scale = 0.0
		target_dice2.linear_velocity = Vector3.ZERO
		target_dice2.angular_velocity = Vector3.ZERO
		if target_dice2.has_method("set_freeze"):
			target_dice2.set_freeze(true)
		elif "freeze" in target_dice2:
			target_dice2.freeze = true


func _setup_particles():
	pass


func reset_scene():
	is_preparation_mode = true
	is_skill_active = false
	is_charging = false
	dices_thrown = false
	all_dices_stopped = false
	dice_are_stopping = false
	global_time = 0.0
	original_positions.clear()
	
	if charge_label:
		charge_label.text = "蓄力：0%"
	
	if skill_system and skill_system.has_method("clear_cooldowns"):
		skill_system.clear_cooldowns()
	
	if skill_dice and is_instance_valid(skill_dice):
		skill_dice.skip_skill_trigger = true
	
	var battle_dices = [attacker_dice, target_dice1, target_dice2]
	for dice in battle_dices:
		if dice:
			dice.gravity_scale = 0.0
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			dice.freeze = true
	
	# 重置属性骰子位置（由 attr_dice_manager 创建）
	var attr_dices = [power_dice, agility_dice, intelligence_dice, skill_dice]
	var positions = [
		Vector3(-2, 4, 6),
		Vector3(0, 4, 6),
		Vector3(2, 4, 6),
		Vector3(-4, 4, 6)
	]
	
	for i in range(attr_dices.size()):
		var dice = attr_dices[i]
		if dice and is_instance_valid(dice):
			dice.position = positions[i]
			dice.gravity_scale = 0.0
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			dice.visible = true
			if dice.has_method("set_freeze"):
				dice.set_freeze(true)
			elif "freeze" in dice:
				dice.freeze = true
	
	print("【重置】力量骰=%s | 敏捷骰=%s | 智力骰=%s | 技能骰=%d" % [
		power_dice.get_attribute_value() if power_dice else "0",
		agility_dice.get_attribute_value() if agility_dice else "0",
		intelligence_dice.get_attribute_value() if intelligence_dice else "0",
		skill_dice.get_dice_value() if skill_dice else 0
	])


func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_1 and event.pressed:
			reset_scene()
		
		# 空格键开始蓄力
		if event.keycode == KEY_SPACE and event.pressed and is_preparation_mode and not is_charging:
			start_charging()
		
		# 空格键松开投掷
		if event.keycode == KEY_SPACE and not event.pressed and is_charging:
			throw_all_battle_dices()
		
		# ✅ 摄像机控制快捷键
		if event.keycode == KEY_HOME and event.pressed:
			CameraManager.set_preset("high")
			print("【摄像机】切换至高位视角")
		elif event.keycode == KEY_END and event.pressed:
			CameraManager.set_preset("low")
			print("【摄像机】切换至低位视角")
		elif event.keycode == KEY_PAGEUP and event.pressed:
			CameraManager.set_preset("wide")
			print("【摄像机】切换至广角视角")
		elif event.keycode == KEY_PAGEDOWN and event.pressed:
			CameraManager.reset_to_default()
			print("【摄像机】重置为默认视角")


func start_charging():
	is_charging = true
	# ✅ 使用统一的投掷控制器开始蓄力
	DiceThrowController.start_charge()
	
	# 记录骰子的初始位置
	original_positions.clear()
	for dice in [power_dice, agility_dice, intelligence_dice, skill_dice]:
		if dice and is_instance_valid(dice):
			original_positions[dice] = dice.position
	
	print("开始蓄力...")


func _process(delta):
	global_time += delta
	
	if is_charging:
		# ✅ 使用统一的投掷控制器更新蓄力
		var charge_ratio = DiceThrowController.update_charge(delta)
		
		# ✅ 使用统一的震动效果
		var dice_list = [power_dice, agility_dice, intelligence_dice, skill_dice]
		DiceThrowController.apply_shake(dice_list, original_positions, charge_ratio, delta)


func throw_all_battle_dices():
	is_charging = false
	var charge_ratio = DiceThrowController.get_charge_ratio()
	print("【投掷】蓄力比例：", charge_ratio)
	
	# ✅ 使用统一的投掷控制器结束蓄力并投掷
	var dice_list = [power_dice, agility_dice, intelligence_dice, skill_dice]
	
	# 检查骰子是否有效并解除 freeze
	for dice in dice_list:
		if not dice or not is_instance_valid(dice):
			print("警告：骰子无效！")
		else:
			# 解除 freeze 状态
			if dice.has_method("set_freeze"):
				dice.set_freeze(false)
			elif "freeze" in dice:
				dice.freeze = false
			
			# 重置物理状态
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			dice.sleeping = false
			
			print("骰子已解除 freeze: ", dice.name, ", 位置=", dice.position)
	
	# 使用 DiceThrowController 投掷
	DiceThrowController.end_charge(dice_list)
	
	# 清空原始位置
	original_positions.clear()
	print("投掷战斗骰子！")
	
	for dice in [skill_dice]:
		if dice and is_instance_valid(dice):
			dice.skip_skill_trigger = false
	
	await get_tree().create_timer(1.0).timeout
	wait_for_all_dices_stopped()


func throw_all_dices_with_charge(charge_ratio: float):
	# ✅ 此方法已废弃，使用 DiceThrowController 替代
	# 保留此空方法以避免编译错误，如有调用会自动忽略
	pass


func _check_dices_stable(all_dices: Array, check_count: int):
	if not dice_are_stopping:
		return
	
	var all_sleeping = true
	
	for dice in all_dices:
		if dice and is_instance_valid(dice):
			if not dice.sleeping:
				all_sleeping = false
				break
	
	if all_sleeping:
		if check_count >= 8:
			_on_all_dices_stopped()
		else:
			await get_tree().create_timer(0.1).timeout
			_check_dices_stable(all_dices, check_count + 1)
	else:
		await get_tree().create_timer(0.15).timeout
		_check_dices_stable(all_dices, 0)


func _on_all_dices_stopped():
	_perform_battle_results()


func _perform_battle_results():
	for dice in [power_dice, agility_dice, intelligence_dice, skill_dice]:
		if dice and is_instance_valid(dice):
			if dice.has_method("check_dice_value"):
				dice.check_dice_value()
	
	await get_tree().create_timer(0.05).timeout
	
	for dice in [power_dice, agility_dice, intelligence_dice, skill_dice]:
		if dice and is_instance_valid(dice):
			dice.skip_skill_trigger = true
			if dice.has_method("stop_rolling"):
				dice.stop_rolling()
			dice.freeze = true
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
	
	dice_are_stopping = false
	all_dices_stopped = true
	
	check_battle_results()


func wait_for_all_dices_stopped():
	var all_dices = [power_dice, agility_dice, intelligence_dice, skill_dice]
	
	dice_are_stopping = true
	all_dices_stopped = false
	_check_dices_stable(all_dices, 0)


func check_battle_results():
	if power_dice and is_instance_valid(power_dice):
		if power_dice.has_method("check_dice_value"):
			power_dice.check_dice_value()
	if agility_dice and is_instance_valid(agility_dice):
		if agility_dice.has_method("check_dice_value"):
			agility_dice.check_dice_value()
	if intelligence_dice and is_instance_valid(intelligence_dice):
		if intelligence_dice.has_method("check_dice_value"):
			intelligence_dice.check_dice_value()
	if skill_dice and is_instance_valid(skill_dice):
		if skill_dice.has_method("check_dice_value"):
			skill_dice.check_dice_value()
	
	var current_skill_attribute_dice = {}
	var skill_index = 0
	var dice_value = 1
	
	if skill_dice and is_instance_valid(skill_dice):
		dice_value = skill_dice.dice_value
		skill_index = dice_value - 1
		
		var skill_dice_config = dice_csv_reader.get_skill_dice_config("4001")
		if not skill_dice_config.is_empty():
			var skill_ids = skill_dice_config.get("skill_ids", [])
			if skill_index >= 0 and skill_index < skill_ids.size():
				var current_skill_id = skill_ids[skill_index]
				var skill_data = skill_system.get_skill(current_skill_id)
				if not skill_data.is_empty():
					current_skill_attribute_dice = skill_data.get("attribute_dice", {})
	
	power_dice_result = 0
	agility_dice_result = 0
	intelligence_dice_result = 0
	
	if current_skill_attribute_dice.has("1"):
		var attr_type = current_skill_attribute_dice["1"]
		if attr_type == "力量" and power_dice and is_instance_valid(power_dice):
			power_dice_result = int(power_dice.get_attribute_value())
		elif attr_type == "敏捷" and agility_dice and is_instance_valid(agility_dice):
			agility_dice_result = int(agility_dice.get_attribute_value())
		elif attr_type == "智力" and intelligence_dice and is_instance_valid(intelligence_dice):
			intelligence_dice_result = int(intelligence_dice.get_attribute_value())

	if current_skill_attribute_dice.has("2"):
		var attr_type = current_skill_attribute_dice["2"]
		if attr_type == "力量" and power_dice and is_instance_valid(power_dice):
			power_dice_result = int(power_dice.get_attribute_value())
		elif attr_type == "敏捷" and agility_dice and is_instance_valid(agility_dice):
			agility_dice_result = int(agility_dice.get_attribute_value())
		elif attr_type == "智力" and intelligence_dice and is_instance_valid(intelligence_dice):
			intelligence_dice_result = int(intelligence_dice.get_attribute_value())

	if current_skill_attribute_dice.has("3"):
		var attr_type = current_skill_attribute_dice["3"]
		if attr_type == "力量" and power_dice and is_instance_valid(power_dice):
			power_dice_result = int(power_dice.get_attribute_value())
		elif attr_type == "敏捷" and agility_dice and is_instance_valid(agility_dice):
			agility_dice_result = int(agility_dice.get_attribute_value())
		elif attr_type == "智力" and intelligence_dice and is_instance_valid(intelligence_dice):
			intelligence_dice_result = int(intelligence_dice.get_attribute_value())
	
	if skill_dice and is_instance_valid(skill_dice):
		var skill_dice_config = dice_csv_reader.get_skill_dice_config("4001")
		if not skill_dice_config.is_empty():
			var skill_ids = skill_dice_config.get("skill_ids", [])
			if skill_index >= 0 and skill_index < skill_ids.size():
				skill_dice_result_id = skill_ids[skill_index]
	
	print("【投掷结果】索引=%d | 技能ID=%s | 力量=%d | 敏捷=%d | 智力=%d" % [dice_value, skill_dice_result_id, power_dice_result, agility_dice_result, intelligence_dice_result])
	
	release_skill_by_id(skill_dice_result_id)


func release_skill_by_id(skill_id: String):
	var caster_marker = $Marker3D
	var caster_position = caster_marker.global_position
	var targets = [target_dice1]
	
	var dice_results = {
		"str": power_dice_result,
		"agi": agility_dice_result,
		"int": intelligence_dice_result
	}
	
	var params = {
		"dice_results": dice_results,
		"scene": self,
		"caster_position": caster_position
	}
	
	print("【执行技能】技能ID=%s" % skill_id)
	SkillManager.use_skill(skill_id, caster_marker, targets, params)
	
	await get_tree().create_timer(3.0).timeout
	
	print("【技能释放后】力量=%d | 敏捷=%d | 智力=%d" % [power_dice_result, agility_dice_result, intelligence_dice_result])
	_check_dice_state_after_skill()


func _check_dice_state_after_skill():
	if skill_dice and is_instance_valid(skill_dice):
		var dice_value = skill_dice.dice_value
		var skill_index = dice_value - 1
		
		var current_skill_id = ""
		var skill_dice_config = dice_csv_reader.get_skill_dice_config("4001")
		if not skill_dice_config.is_empty():
			var skill_ids = skill_dice_config.get("skill_ids", [])
			if skill_index >= 0 and skill_index < skill_ids.size():
				current_skill_id = skill_ids[skill_index]
		
		var power_val = 0
		var agility_val = 0
		var intelligence_val = 0
		
		if power_dice and is_instance_valid(power_dice):
			power_val = int(power_dice.get_attribute_value())
		if agility_dice and is_instance_valid(agility_dice):
			agility_val = int(agility_dice.get_attribute_value())
		if intelligence_dice and is_instance_valid(intelligence_dice):
			intelligence_val = int(intelligence_dice.get_attribute_value())
		
		print("【技能释放后检测】骰面索引=%d | 技能 ID=%s | 力量=%d | 敏捷=%d | 智力=%d" % [dice_value, current_skill_id, power_val, agility_val, intelligence_val])


func get_skill_dice() -> RigidBody3D:
	return skill_dice


func get_marker_position() -> Vector3:
	return marker.position

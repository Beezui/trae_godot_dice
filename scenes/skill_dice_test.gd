extends Node3D

@onready var camera = $Camera3D
@onready var sandbox = $Sandbox
@onready var light = $DirectionalLight3D
@onready var attacker_dice = $AttackerDice
@onready var skill_dice = $SkillDice
@onready var target_dice1 = $TargetDice1
@onready var target_dice2 = $TargetDice2
@onready var marker = $Marker3D

@onready var power_dice = $AttributeDices/PowerDice
@onready var agility_dice = $AttributeDices/AgilityDice
@onready var intelligence_dice = $AttributeDices/IntelligenceDice
@onready var charge_label = $ChargeLabel

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

var is_preparation_mode: bool = true
var is_charging: bool = false
var charge_start_time: float = 0
var charge_power: float = 0
var max_charge_time: float = 2.0
var max_charge_power: float = 20.0

var dices_thrown: bool = false
var dice_are_stopping: bool = false
var global_time: float = 0.0
var original_positions: Dictionary = {}

var skill_dice_result: int = 0
var skill_dice_result_id: String = ""
var all_dices_stopped: bool = false


func _ready():
	dice_csv_reader = preload("res://scripts/dice_csv_reader.gd").new()
	skill_csv_reader = preload("res://scripts/skill_csv_reader.gd").new()
	skill_system = preload("res://scripts/skill_system.gd").new()
	
	_load_skill_config()
	
	_setup_camera()
	_setup_light()
	_setup_sandbox()
	_setup_attribute_dices()
	_setup_skill_dice()
	_setup_particles()
	
	await get_tree().process_frame
	
	reset_scene()
	
	print("=== 技能骰子战斗测试场景加载完成 ===")
	print("按 1 键：重置场景到初始化状态")
	print("按空格键：蓄力后同时投掷所有战斗骰子")
	print("=========================================")


func _load_skill_config():
	var skill = skill_system.get_skill(current_skill_id)
	if skill.is_empty():
		print("Error: Skill ", current_skill_id, " not found!")
		return
	
	print("Loaded skill config: ", skill.get("id"), " - ", skill.get("name"))
	print("Attribute dice: ", skill.get("attribute_dice", {}))
	skill_attribute_dice = skill.get("attribute_dice", {})


func _setup_camera():
	if camera:
		camera.position = Vector3(0, 60, 0)
		camera.fov = 15.0
		camera.rotation = Vector3(-PI/2, 0, 0)


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
	var dice_list = [power_dice, agility_dice, intelligence_dice]
	var positions = [
		Vector3(-2, 4, 6),
		Vector3(0, 4, 6),
		Vector3(2, 4, 6)
	]
	
	var power_config = dice_csv_reader.get_num_dice_config("1001")
	var agility_config = dice_csv_reader.get_num_dice_config("1002")
	var intelligence_config = dice_csv_reader.get_num_dice_config("1001")
	
	for i in range(dice_list.size()):
		var dice = dice_list[i]
		if dice and is_instance_valid(dice):
			dice.position = positions[i]
			dice.visible = true
			dice.gravity_scale = 0.0
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			if dice.has_method("set_freeze"):
				dice.set_freeze(true)
			elif "freeze" in dice:
				dice.freeze = true
			
			var config = null
			if i == 0:
				config = power_config
			elif i == 1:
				config = agility_config
			else:
				config = intelligence_config
			
			if config and dice.has_method("set_dice_face_config"):
				var texture_config = config.get("textures", {})
				var value_config = config.get("values", {})
				dice.set_dice_face_config(texture_config, value_config)
				print("Applied config to dice ", i, ": ", config.get("id", "unknown"))


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
			print("=== 技能骰子配置 ===")
			var skill_ids = skill_dice_config.get("skill_ids", [])
			print("skill_ids 数组: ", skill_ids)
			print("skill_ids 长度: ", skill_ids.size())
			
			# 详细打印每个面对应的技能
			for i in range(skill_ids.size()):
				var skill_id = skill_ids[i]
				var skill_data = skill_system.get_skill(skill_id)
				var skill_name = "未知"
				if not skill_data.is_empty():
					skill_name = skill_data.get("name", "未知")
				print("  面索引 %d → 技能ID %s (%s)" % [i, skill_id, skill_name])
			
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
				print("Applied skill dice config: ", texture_config)
	
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
	print("=== 重置场景到初始化状态 ===")
	
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
	
	var attr_dices = [power_dice, agility_dice, intelligence_dice, skill_dice]
	var positions = [
		Vector3(-2, 4, 6),
		Vector3(0, 4, 6),
		Vector3(2, 4, 6),
		Vector3(-4, 4, 6)
	]
	
	var power_config = dice_csv_reader.get_num_dice_config("1001")
	var agility_config = dice_csv_reader.get_num_dice_config("1002")
	var intelligence_config = dice_csv_reader.get_num_dice_config("1001")
	
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
			
			var config = null
			if i == 0:
				config = power_config
			elif i == 1:
				config = agility_config
			elif i == 2:
				config = intelligence_config
			elif i == 3:
				config = dice_csv_reader.get_skill_dice_config("4001")
				if not config.is_empty():
					var skill_ids = config.get("skill_ids", [])
					var texture_config = {}
					for j in range(6):
						if j < skill_ids.size():
							var skill_id = skill_ids[j]
							texture_config[j] = "res://textures/skill/skill_" + skill_id + ".png"
					var value_config = {}
					for j in range(6):
						value_config[j] = j + 1
					if texture_config.size() > 0 and dice.has_method("set_dice_face_config"):
						dice.set_dice_face_config(texture_config, value_config)
				continue
			
			if config and dice.has_method("set_dice_face_config"):
				var texture_config = config.get("textures", {})
				var value_config = config.get("values", {})
				dice.set_dice_face_config(texture_config, value_config)
	
	print("场景已重置，进入战斗准备阶段")
	print("按空格键蓄力后，同时投掷技能骰子和属性骰子")


func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_1 and event.pressed:
			reset_scene()
		
		if event.keycode == KEY_SPACE and event.pressed and is_preparation_mode and not dices_thrown and not is_charging and not dice_are_stopping:
			start_charging()
		
		if event.keycode == KEY_SPACE and not event.pressed and is_charging:
			throw_all_battle_dices()


func start_charging():
	is_charging = true
	charge_start_time = Time.get_ticks_msec()
	charge_power = 0
	global_time = 0.0
	
	original_positions.clear()
	var dice_list = [power_dice, agility_dice, intelligence_dice, skill_dice]
	for dice in dice_list:
		if dice and is_instance_valid(dice):
			original_positions[dice.get_path()] = dice.position
	
	print("开始蓄力...")


func _process(delta):
	global_time += delta
	
	if is_charging:
		var charge_duration = (Time.get_ticks_msec() - charge_start_time) / 1000.0
		charge_power = min(charge_duration / max_charge_time, 1.0)
		
		if charge_label:
			var charge_percent = int(charge_power * 100)
			charge_label.text = "蓄力：%d%%" % charge_percent
		
		var charge_ratio = charge_power
		var shake_amplitude = charge_ratio * 0.05
		var shake_frequency = 15.0 + (charge_ratio * 25.0)
		
		var time = global_time * shake_frequency
		var shake_offset = Vector3(
			sin(time * 3.14159) * shake_amplitude,
			sin(time * 3.14159 * 1.5) * shake_amplitude,
			sin(time * 3.14159 * 2.0) * shake_amplitude
		)
		
		var dice_list = [power_dice, agility_dice, intelligence_dice, skill_dice]
		for dice in dice_list:
			if dice and is_instance_valid(dice):
				var dice_path = dice.get_path()
				if original_positions.has(dice_path):
					dice.position = original_positions[dice_path] + shake_offset
		
		if charge_power >= 1.0:
			print("已达到最大蓄力！")


func throw_all_battle_dices():
	is_charging = false
	dice_are_stopping = true
	dices_thrown = true
	original_positions.clear()
	
	var charge_duration = (Time.get_ticks_msec() - charge_start_time) / 1000.0
	charge_power = min(charge_duration / max_charge_time, 1.0)
	
	print("=== 同时投掷所有战斗骰子 ===")
	print("蓄力时间：%.2f 秒" % charge_duration)
	print("蓄力强度：%.0f%%" % (charge_power * 100))
	
	for dice in [skill_dice]:
		if dice and is_instance_valid(dice):
			dice.skip_skill_trigger = false
	
	throw_all_dices_with_charge(charge_power)
	
	await get_tree().create_timer(1.0).timeout
	wait_for_all_dices_stopped()


func throw_all_dices_with_charge(charge_ratio: float):
	var all_dices = [power_dice, agility_dice, intelligence_dice, skill_dice]
	
	var max_force = 20.0
	var min_force_ratio = 0.3
	var force_magnitude = (min_force_ratio + (charge_ratio * (1.0 - min_force_ratio))) * max_force
	
	for dice in all_dices:
		if dice and is_instance_valid(dice):
			var angle = deg_to_rad(randf_range(-45, 45))
			
			var force = Vector3(
				sin(angle) * 0.25 * force_magnitude,
				(0.3 + (charge_ratio * 0.7)) * force_magnitude * 0.5,
				-0.25 * force_magnitude
			)
			
			var min_angular_force = 11.2
			var max_angular_force = 31.5
			var angular_force_magnitude = min_angular_force + (charge_ratio * (max_angular_force - min_angular_force))
			
			var x_rot = randf_range(-1.0, 1.0)
			var y_rot = randf_range(-1.0, 1.0)
			var z_rot = randf_range(-1.0, 1.0)
			
			if abs(x_rot) < 0.5:
				x_rot = randf_range(0.5, 1.0) * sign(x_rot) if x_rot != 0 else 0.7
			if abs(y_rot) < 0.5:
				y_rot = randf_range(0.5, 1.0) * sign(y_rot) if y_rot != 0 else 0.7
			if abs(z_rot) < 0.5:
				z_rot = randf_range(0.5, 1.0) * sign(z_rot) if z_rot != 0 else 0.7
			
			var angular_force = Vector3(x_rot, y_rot, z_rot).normalized() * angular_force_magnitude
			
			dice.visible = true
			dice.gravity_scale = 1.0
			dice.freeze = false
			dice.linear_velocity = force
			dice.angular_velocity = angular_force
			
			if dice.has_method("roll"):
				dice.roll(force, angular_force)
	
	print("同时投掷所有战斗骰子（属性骰子 + 技能骰子）！")


func wait_for_all_dices_stopped():
	var max_wait_time = 8.0
	var wait_interval = 0.3
	var waited_time = 0.0
	var check_count = 0
	
	while waited_time < max_wait_time:
		waited_time += wait_interval
		await get_tree().create_timer(wait_interval).timeout
		check_count += 1
		
		var all_stopped = true
		var all_dices = [power_dice, agility_dice, intelligence_dice, skill_dice]
		
		for dice in all_dices:
			if dice and is_instance_valid(dice):
				var lin_vel = dice.linear_velocity.length()
				var ang_vel = dice.angular_velocity.length()
				
				if lin_vel > 0.1 or ang_vel > 0.1:
					all_stopped = false
					if check_count % 6 == 0:
						print("骰子未停止 - 线速度：%.2f, 角速度：%.2f" % [lin_vel, ang_vel])
					break
		
		if all_stopped:
			print("所有骰子已停止运动")
			break
	
	check_battle_results()
	
	dice_are_stopping = false
	all_dices_stopped = true
	
	for dice in [power_dice, agility_dice, intelligence_dice, skill_dice]:
		if dice and is_instance_valid(dice):
			dice.skip_skill_trigger = true


func check_battle_results():
	print("=== 检测所有骰子结果 ===")
	
	# 首先获取技能ID，然后根据技能ID获取属性配置
	var current_skill_attribute_dice = {}
	
	if skill_dice and is_instance_valid(skill_dice):
		var dice_value = skill_dice.dice_value
		var skill_index = dice_value - 1
		
		var skill_dice_config = dice_csv_reader.get_skill_dice_config("4001")
		if not skill_dice_config.is_empty():
			var skill_ids = skill_dice_config.get("skill_ids", [])
			if skill_index >= 0 and skill_index < skill_ids.size():
				var current_skill_id = skill_ids[skill_index]
				var skill_data = skill_system.get_skill(current_skill_id)
				if not skill_data.is_empty():
					current_skill_attribute_dice = skill_data.get("attribute_dice", {})
					print("当前技能 ", current_skill_id, " 的属性配置: ", current_skill_attribute_dice)
	
	print("使用的属性配置: ", current_skill_attribute_dice)
	
	var power_result = 0
	var agility_result = 0
	var intelligence_result = 0
	
	if current_skill_attribute_dice.has("1"):
		var attr_type = current_skill_attribute_dice["1"]
		print("Attribute 1 type: ", attr_type)
		if attr_type == "力量" and power_dice and is_instance_valid(power_dice):
			power_result = power_dice.get_dice_value()
			power_dice_result = power_result
			print("力量骰子结果：", power_result)
	
	if current_skill_attribute_dice.has("2"):
		var attr_type = current_skill_attribute_dice["2"]
		print("Attribute 2 type: ", attr_type)
		if attr_type == "敏捷" and agility_dice and is_instance_valid(agility_dice):
			agility_result = agility_dice.get_dice_value()
			agility_dice_result = agility_result
			print("敏捷骰子结果：", agility_result)
	
	if current_skill_attribute_dice.has("3"):
		var attr_type = current_skill_attribute_dice["3"]
		if attr_type == "智力" and intelligence_dice and is_instance_valid(intelligence_dice):
			intelligence_result = intelligence_dice.get_dice_value()
			intelligence_dice_result = intelligence_result
			print("智力骰子结果：", intelligence_result)
	
	if skill_dice and is_instance_valid(skill_dice):
		var face_index = skill_dice.get_dice_face_index()
		var dice_value = skill_dice.dice_value
		
		print("=== 技能骰子调试 ===")
		print("skill_dice.get_dice_face_index() 面索引: ", face_index)
		print("skill_dice.dice_value (面值): ", dice_value)
		
		# 验证：dice_value - 1 应该等于 face_index（如果骰子已停止）
		if face_index == dice_value - 1:
			print("✓ 骰子已停止，索引一致")
		else:
			print("✗ 警告：骰子可能还在滚动！face_index=", face_index, " != dice_value-1=", dice_value-1)
		
		# 使用 dice_value - 1 来获取 skill_ids 数组索引
		# 因为 dice_value 是 1-6，数组索引是 0-5
		var skill_index = dice_value - 1
		
		var skill_dice_config = dice_csv_reader.get_skill_dice_config("4001")
		
		if not skill_dice_config.is_empty():
			var skill_ids = skill_dice_config.get("skill_ids", [])
			print("skill_ids 数组：", skill_ids)
			
			if skill_index >= 0 and skill_index < skill_ids.size():
				skill_dice_result_id = skill_ids[skill_index]
				print("skill_ids[", skill_index, "] = ", skill_ids[skill_index])
				print("成功获取技能 ID: ", skill_dice_result_id)
				
				# 验证技能 ID 是否正确
				var skill_data = skill_system.get_skill(skill_dice_result_id)
				if not skill_data.is_empty():
					print("技能名称：", skill_data.get("name", "Unknown"))
			else:
				print("索引超出范围！skill_index=", skill_index, ", skill_ids 大小=", skill_ids.size())
		else:
			print("skill_dice_config 为空！")
	
	print("=== 战斗骰子结果 ===")
	print("力量骰子结果：", power_dice_result)
	print("敏捷骰子结果：", agility_dice_result)
	print("智力骰子结果：", intelligence_dice_result)
	print("技能骰子技能ID：", skill_dice_result_id)
	
	await get_tree().create_timer(1.0).timeout
	
	release_skill_by_id(skill_dice_result_id)


func release_skill_by_id(skill_id: String):
	print("=== 根据技能 ID 释放技能 ===")
	print("技能 ID: ", skill_id)
	
	# 设置固定的施法者位置（左侧标记点）
	var caster_marker = $Marker3D
	var caster_position = caster_marker.global_position
	
	# 设置固定的目标（右侧骰子）
	var targets = [target_dice1]
	
	# 准备骰子结果
	var dice_results = {
		"str": power_dice_result,
		"agi": agility_dice_result,
		"int": intelligence_dice_result
	}
	
	var params = {
		"dice_results": dice_results,
		"scene": self,  # 传递当前场景
		"caster_position": caster_position  # 传递施法者位置
	}
	
	# 使用 SkillManager 调用技能
	var success = SkillManager.use_skill(skill_id, caster_marker, targets, params)
	
	if success:
		print("技能 ", skill_id, " 释放成功")
	else:
		print("技能 ", skill_id, " 释放失败")


func get_skill_dice() -> RigidBody3D:
	return skill_dice


func get_marker_position() -> Vector3:
	return marker.position

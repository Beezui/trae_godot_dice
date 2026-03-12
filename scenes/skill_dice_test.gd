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


func _load_skill_config():
	var skill = skill_system.get_skill(current_skill_id)
	if skill.is_empty():
		print("Error: Skill ", current_skill_id, " not found!")
		return
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
			pass


func throw_all_battle_dices():
	is_charging = false
	dice_are_stopping = true
	dices_thrown = true
	original_positions.clear()
	
	var charge_duration = (Time.get_ticks_msec() - charge_start_time) / 1000.0
	charge_power = min(charge_duration / max_charge_time, 1.0)
	
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


func _check_dices_stable(all_dices: Array, check_count: int):
	if not dice_are_stopping:
		return
	
	var all_stable = true
	var velocity_threshold = 0.05
	
	for dice in all_dices:
		if dice and is_instance_valid(dice):
			var lin_vel = dice.linear_velocity.length()
			var ang_vel = dice.angular_velocity.length()
			
			if lin_vel > velocity_threshold or ang_vel > velocity_threshold:
				all_stable = false
				break
	
	if all_stable:
		if check_count >= 15:
			_on_all_dices_stopped()
		else:
			await get_tree().create_timer(0.1).timeout
			_check_dices_stable(all_dices, check_count + 1)
	else:
		await get_tree().create_timer(0.2).timeout
		_check_dices_stable(all_dices, 0)


func _on_all_dices_stopped():
	for dice in [power_dice, agility_dice, intelligence_dice, skill_dice]:
		if dice and is_instance_valid(dice):
			dice.skip_skill_trigger = true
	
	dice_are_stopping = false
	all_dices_stopped = true
	
	await get_tree().create_timer(0.3).timeout
	
	check_battle_results()


func wait_for_all_dices_stopped():
	var all_dices = [power_dice, agility_dice, intelligence_dice, skill_dice]
	
	dice_are_stopping = true
	all_dices_stopped = false
	_check_dices_stable(all_dices, 0)


func check_battle_results():
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
			power_dice_result = power_dice.get_dice_value()
	
	if current_skill_attribute_dice.has("2"):
		var attr_type = current_skill_attribute_dice["2"]
		if attr_type == "敏捷" and agility_dice and is_instance_valid(agility_dice):
			agility_dice_result = agility_dice.get_dice_value()
	
	if current_skill_attribute_dice.has("3"):
		var attr_type = current_skill_attribute_dice["3"]
		if attr_type == "智力" and intelligence_dice and is_instance_valid(intelligence_dice):
			intelligence_dice_result = intelligence_dice.get_dice_value()
	
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
			power_val = power_dice.get_dice_value()
		if agility_dice and is_instance_valid(agility_dice):
			agility_val = agility_dice.get_dice_value()
		if intelligence_dice and is_instance_valid(intelligence_dice):
			intelligence_val = intelligence_dice.get_dice_value()
		
		print("【技能释放后检测】骰面索引=%d | 技能ID=%s | 力量=%d | 敏捷=%d | 智力=%d" % [dice_value, current_skill_id, power_val, agility_val, intelligence_val])


func get_skill_dice() -> RigidBody3D:
	return skill_dice


func get_marker_position() -> Vector3:
	return marker.position

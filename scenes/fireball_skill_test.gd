extends Node3D

@onready var camera = $Camera3D
@onready var sandbox = $Sandbox
@onready var light = $DirectionalLight3D
@onready var attacker_dice = $AttackerDice
@onready var target_dice1 = $TargetDice1
@onready var target_dice2 = $TargetDice2
@onready var target_dice3 = $TargetDice3
@onready var marker = $Marker3D
@onready var explosion_particles = $ExplosionParticles

@onready var power_dice = $AttributeDices/PowerDice
@onready var agility_dice = $AttributeDices/AgilityDice
@onready var intelligence_dice = $AttributeDices/IntelligenceDice
@onready var charge_label = $ChargeLabel

var base_width = 24.0
var base_height = 13.5

var dice_csv_reader
var skill_csv_reader: RefCounted
var skill_system: RefCounted
var power_dice_result: int = 0
var agility_dice_result: int = 0
var is_skill_active: bool = false
var current_fireball: Node3D = null
var target_dice: RigidBody3D = null
var current_skill_id: String = "10001"
var skill_attribute_dice: Dictionary = {}

var is_preparation_mode: bool = true
var is_charging: bool = false
var charge_start_time: float = 0
var charge_power: float = 0
var max_charge_time: float = 2.0
var max_charge_power: float = 20.0

var attribute_dices_thrown: bool = false
var dice_are_stopping: bool = false
var global_time: float = 0.0
var original_positions: Dictionary = {}

func _ready():
	dice_csv_reader = preload("res://scripts/dice_csv_reader.gd").new()
	skill_csv_reader = preload("res://scripts/skill_csv_reader.gd").new()
	skill_system = preload("res://scripts/skill_system.gd").new()
	
	_load_skill_config()
	
	_setup_camera()
	_setup_light()
	_setup_sandbox()
	_setup_attribute_dices()
	_setup_particles()
	
	await get_tree().process_frame
	
	reset_scene()
	
	print("=== 火球术技能测试场景加载完成 ===")
	print("按 1 键：重置场景到初始化状态")
	print("按空格键：蓄力投掷属性骰子")
	print("======================================")

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

func _setup_particles():
	if explosion_particles:
		explosion_particles.emitting = false

func reset_scene():
	print("=== 重置场景到初始化状态 ===")
	
	is_preparation_mode = true
	is_skill_active = false
	is_charging = false
	attribute_dices_thrown = false
	dice_are_stopping = false
	global_time = 0.0
	original_positions.clear()
	
	if charge_label:
		charge_label.text = "蓄力：0%"
	
	var dice_list = [attacker_dice, target_dice1, target_dice2, target_dice3]
	for dice in dice_list:
		if dice:
			dice.gravity_scale = 0.0
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			dice.freeze = true
	
	var attr_dices = [power_dice, agility_dice, intelligence_dice]
	var positions = [
		Vector3(-2, 4, 6),
		Vector3(0, 4, 6),
		Vector3(2, 4, 6)
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
			else:
				config = intelligence_config
			
			if config and dice.has_method("set_dice_face_config"):
				var texture_config = config.get("textures", {})
				var value_config = config.get("values", {})
				dice.set_dice_face_config(texture_config, value_config)
	
	if current_fireball:
		current_fireball.queue_free()
		current_fireball = null
	
	print("场景已重置，进入技能释放准备阶段")
	print("请投掷属性骰子：力量骰子、敏捷骰子、智力骰子")

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_1 and event.pressed:
			reset_scene()
		
		if event.keycode == KEY_SPACE and event.pressed and is_preparation_mode and not attribute_dices_thrown and not is_charging and not dice_are_stopping:
			start_charging()
		
		if event.keycode == KEY_SPACE and not event.pressed and is_charging:
			throw_attribute_dices()

func start_charging():
	is_charging = true
	charge_start_time = Time.get_ticks_msec()
	charge_power = 0
	global_time = 0.0
	
	original_positions.clear()
	var dice_list = [power_dice, agility_dice, intelligence_dice]
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
		
		var dice_list = [power_dice, agility_dice, intelligence_dice]
		for dice in dice_list:
			if dice and is_instance_valid(dice):
				var dice_path = dice.get_path()
				if original_positions.has(dice_path):
					dice.position = original_positions[dice_path] + shake_offset
		
		if charge_power >= 1.0:
			print("已达到最大蓄力！")

func throw_attribute_dices():
	is_charging = false
	dice_are_stopping = true
	original_positions.clear()
	
	var charge_duration = (Time.get_ticks_msec() - charge_start_time) / 1000.0
	charge_power = min(charge_duration / max_charge_time, 1.0)
	
	print("=== 投掷属性骰子 ===")
	print("蓄力时间：%.2f 秒" % charge_duration)
	print("蓄力强度：%.0f%%" % (charge_power * 100))
	
	throw_all_dices_with_charge(charge_power)
	
	await get_tree().create_timer(1.0).timeout
	wait_for_dices_stopped()

func throw_all_dices_with_charge(charge_ratio: float):
	var dice_list = [power_dice, agility_dice, intelligence_dice]
	
	var max_force = 20.0
	var min_force_ratio = 0.3
	var force_magnitude = (min_force_ratio + (charge_ratio * (1.0 - min_force_ratio))) * max_force
	
	for dice in dice_list:
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
	
	print("同时投掷所有属性骰子！")

func wait_for_dices_stopped():
	var max_wait_time = 8.0
	var wait_interval = 0.3
	var waited_time = 0.0
	var check_count = 0
	
	while waited_time < max_wait_time:
		await get_tree().create_timer(wait_interval).timeout
		waited_time += wait_interval
		check_count += 1
		
		var all_stopped = true
		var dice_list = [power_dice, agility_dice, intelligence_dice]
		
		for dice in dice_list:
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
	
	dice_are_stopping = false
	
	for dice in [power_dice, agility_dice, intelligence_dice]:
		if dice and is_instance_valid(dice) and dice.has_method("check_dice_value"):
			dice.check_dice_value()
	
	check_attribute_results()

func check_attribute_results():
	print("=== 检测骰子结果 ===")
	print("Skill attribute dice config: ", skill_attribute_dice)
	
	var power_result = 0
	var agility_result = 0
	var intelligence_result = 0
	
	if skill_attribute_dice.has("1"):
		var attr_type = skill_attribute_dice["1"]
		print("Attribute 1 type: ", attr_type)
		if attr_type == "力量" and power_dice and is_instance_valid(power_dice):
			power_result = power_dice.get_dice_value()
			power_dice_result = power_result
			print("力量骰子结果：", power_result)
	
	if skill_attribute_dice.has("2"):
		var attr_type = skill_attribute_dice["2"]
		print("Attribute 2 type: ", attr_type)
		if attr_type == "敏捷" and agility_dice and is_instance_valid(agility_dice):
			agility_result = agility_dice.get_dice_value()
			agility_dice_result = agility_result
			print("敏捷骰子结果：", agility_result)
	
	if skill_attribute_dice.has("3"):
		var attr_type = skill_attribute_dice["3"]
		if attr_type == "智力" and intelligence_dice and is_instance_valid(intelligence_dice):
			intelligence_result = intelligence_dice.get_dice_value()
			print("智力骰子结果：", intelligence_result)
	
	print("=== 属性骰子结果 ===")
	print("力量骰子结果：", power_dice_result)
	print("敏捷骰子结果：", agility_dice_result)
	print("智力骰子结果：", intelligence_result)
	
	attribute_dices_thrown = true
	is_preparation_mode = false
	
	await get_tree().create_timer(1.0).timeout
	release_fireball_skill()

func release_fireball_skill():
	if is_skill_active:
		print("技能正在冷却中...")
		return
	
	is_skill_active = true
	print("=== 火球术技能释放 ===")
	
	if skill_system and skill_system.has_method("use_skill"):
		skill_system.use_skill(current_skill_id, self, target_dice)
	
	_launch_fireball()

func _launch_fireball():
	print("【发射火球】")
	
	var target_list = [target_dice1, target_dice2, target_dice3]
	target_dice = target_list[randi() % target_list.size()]
	
	var start_pos = attacker_dice.position
	var target_pos = target_dice.position
	
	var direction = (target_pos - start_pos).normalized()
	
	_create_fireball_effect(start_pos, direction, target_pos)

func _create_fireball_effect(start_pos: Vector3, _direction: Vector3, target_pos: Vector3):
	var fireball_mesh = SphereMesh.new()
	fireball_mesh.radius = 0.3
	fireball_mesh.height = 0.6
	
	var fireball_material = StandardMaterial3D.new()
	fireball_material.albedo_color = Color(1, 0.8, 0, 1)
	fireball_material.emission_enabled = true
	fireball_material.emission = Color(1, 0.6, 0, 1)
	fireball_material.emission_energy_multiplier = 3.0
	
	var fireball_mesh_instance = MeshInstance3D.new()
	fireball_mesh_instance.mesh = fireball_mesh
	fireball_mesh_instance.material_override = fireball_material
	fireball_mesh_instance.position = start_pos
	fireball_mesh_instance.name = "Fireball"
	add_child(fireball_mesh_instance)
	
	current_fireball = fireball_mesh_instance
	
	var fireball_speed = 25.0
	var distance = start_pos.distance_to(target_pos)
	var travel_time = distance / fireball_speed
	
	var tween = create_tween()
	tween.tween_property(current_fireball, "position", target_pos, travel_time)
	tween.tween_callback(_on_fireball_hit.bind(target_pos))
	
	print("火球已发射，目标：", target_dice.name)
	print("预计飞行时间：", travel_time, "秒")

func _on_fireball_hit(hit_position: Vector3):
	print("=== 火球命中目标 ===")
	
	if current_fireball:
		current_fireball.queue_free()
		current_fireball = null
	
	_trigger_explosion(hit_position)
	
	await get_tree().create_timer(0.5).timeout
	
	_calculate_damage()
	
	is_skill_active = false
	print("=== 技能释放完成 ===")

func _trigger_explosion(hit_position: Vector3):
	print("【触发爆炸效果】")
	
	if explosion_particles:
		explosion_particles.position = hit_position
		explosion_particles.emitting = false
		explosion_particles.restart()
		explosion_particles.emitting = true
		
		print("爆炸粒子已触发，位置：", hit_position)

func _calculate_damage():
	print("=== 伤害结算 ===")
	
	# 获取技能配置
	var skill = skill_system.get_skill(current_skill_id)
	if skill.is_empty():
		print("Error: Skill configuration not found!")
		return
	
	var parameters = skill.get("parameters", {})
	var attribute_dice_map = skill.get("attribute_dice", {})
	
	print("Skill parameters: ", parameters)
	print("Attribute dice map: ", attribute_dice_map)
	
	# 获取骰子结果
	var dice_results = {}
	if attribute_dice_map.has("1"):
		var attr_type = attribute_dice_map["1"]
		if attr_type == "力量" and power_dice and is_instance_valid(power_dice):
			dice_results["str"] = power_dice.get_dice_value()
			print("力量骰子结果 (str): ", dice_results["str"])
		elif attr_type == "敏捷" and agility_dice and is_instance_valid(agility_dice):
			dice_results["agi"] = agility_dice.get_dice_value()
			print("敏捷骰子结果 (agi): ", dice_results["agi"])
		elif attr_type == "智力" and intelligence_dice and is_instance_valid(intelligence_dice):
			dice_results["int"] = intelligence_dice.get_dice_value()
			print("智力骰子结果 (int): ", dice_results["int"])
	
	if attribute_dice_map.has("2"):
		var attr_type = attribute_dice_map["2"]
		if attr_type == "力量" and power_dice and is_instance_valid(power_dice):
			dice_results["str"] = power_dice.get_dice_value()
			print("力量骰子结果 (str): ", dice_results["str"])
		elif attr_type == "敏捷" and agility_dice and is_instance_valid(agility_dice):
			dice_results["agi"] = agility_dice.get_dice_value()
			print("敏捷骰子结果 (agi): ", dice_results["agi"])
		elif attr_type == "智力" and intelligence_dice and is_instance_valid(intelligence_dice):
			dice_results["int"] = intelligence_dice.get_dice_value()
			print("智力骰子结果 (int): ", dice_results["int"])
	
	# 根据参数公式计算伤害
	var damage_results = {}
	for param_name in parameters.keys():
		var formula = parameters[param_name]
		var damage = _calculate_formula(formula, dice_results)
		damage_results[param_name] = damage
		print("参数 ", param_name, " (", formula, ") = ", damage)
	
	# 显示伤害结算信息
	print("=== 伤害结算详情 ===")
	if damage_results.has("p1"):
		print("p1 伤害：", damage_results["p1"], " 点")
	if damage_results.has("p2"):
		print("p2 伤害：", damage_results["p2"], " 点")
	if damage_results.has("p3"):
		print("p3 伤害：", damage_results["p3"], " 点")
	
	if target_dice:
		print("命中目标：", target_dice.name)
		print("目标位置：", target_dice.position)

func _calculate_formula(formula: String, dice_results: Dictionary) -> int:
	# 替换公式中的变量为实际值
	var evaluated_formula = formula
	
	if dice_results.has("str"):
		evaluated_formula = evaluated_formula.replace("str", str(dice_results["str"]))
	if dice_results.has("agi"):
		evaluated_formula = evaluated_formula.replace("agi", str(dice_results["agi"]))
	if dice_results.has("int"):
		evaluated_formula = evaluated_formula.replace("int", str(dice_results["int"]))
	
	# 计算表达式（支持 * / + - 运算）
	var result = _evaluate_expression(evaluated_formula)
	return result

func _evaluate_expression(expr: String) -> int:
	# 简单的表达式求值（支持乘除加减）
	# 注意：这是一个简化实现，生产环境应该使用更安全的表达式解析器
	var tokens = expr.replace(" ", "").split("+")
	var total = 0.0
	
	for token in tokens:
		if "-" in token and token != tokens[0]:
			var parts = token.split("-")
			if parts.size() == 2:
				total += _evaluate_multiplication(parts[0])
				total -= _evaluate_multiplication(parts[1])
			else:
				total += _evaluate_multiplication(token)
		else:
			total += _evaluate_multiplication(token)
	
	return int(total)

func _evaluate_multiplication(expr: String) -> float:
	var tokens = expr.split("*")
	var result = 1.0
	
	for token in tokens:
		if "/" in token:
			var div_parts = token.split("/")
			if div_parts.size() == 2:
				result *= float(div_parts[0]) / float(div_parts[1])
			else:
				result *= float(token)
		else:
			result *= float(token)
	
	return result

func get_attacker_dice() -> RigidBody3D:
	return attacker_dice

func get_target_dice() -> Array:
	return [target_dice1, target_dice2, target_dice3]

func get_marker_position() -> Vector3:
	return marker.position

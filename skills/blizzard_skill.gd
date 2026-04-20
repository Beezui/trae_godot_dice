extends RefCounted

var area_radius: float = 3.0
var duration_base: int = 2
var blizzard_area: Area3D = null
var skill_config: Dictionary = {}
var is_executing: bool = false

func init(config: Dictionary) -> void:
	skill_config = config

func cleanup() -> void:
	is_executing = false
	if blizzard_area:
		blizzard_area.queue_free()
		blizzard_area = null

func get_config() -> Dictionary:
	return skill_config

func get_skill_id() -> String:
	return skill_config.get("id", "")

func get_skill_name() -> String:
	return skill_config.get("name", "Unknown")

func get_skill_type() -> String:
	return skill_config.get("type", "")

func get_target_type() -> String:
	return skill_config.get("target_type", "")

func calculate_damage(formula: String, dice_results: Dictionary) -> int:
	var evaluated_formula = formula
	
	if dice_results.has("str"):
		evaluated_formula = evaluated_formula.replace("str", str(dice_results["str"]))
	if dice_results.has("agi"):
		evaluated_formula = evaluated_formula.replace("agi", str(dice_results["agi"]))
	if dice_results.has("int"):
		evaluated_formula = evaluated_formula.replace("int", str(dice_results["int"]))
	
	return _evaluate_expression(evaluated_formula)

func _evaluate_expression(expr: String) -> int:
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

func execute(caster: Node = null, targets: Array = [], params: Dictionary = {}) -> void:
	var dice_results = params.get("dice_results", {})

	var scene_node: Node = params.get("scene", null)
	if not scene_node and caster:
		scene_node = caster.get_tree().current_scene

	var caster_position: Vector3 = params.get("caster_position", Vector3(-6, 0.5, 0))
	if caster and caster.has_method("get_global_position"):
		caster_position = caster.global_position

	var duration = calculate_damage("int*2", dice_results)
	var damage_per_second = calculate_damage("str*2", dice_results)
	var range_bonus = calculate_damage("agi*3", dice_results)

	if targets.is_empty():
		cleanup()
		return

	var target = targets[randi() % targets.size()]
	# 获取目标位置：如果目标有 character_dice，使用骰子位置；否则使用 global_position（如果是 Node）
	var target_pos: Vector3
	if target is BaseCharacter:
		if target.character_dice:
			target_pos = target.character_dice.position
		else:
			target_pos = Vector3(6, 0.5, 0)  # 默认位置
	elif target.has_method("get_global_position"):
		target_pos = target.global_position
	else:
		target_pos = Vector3(6, 0.5, 0)

	var center_pos = target_pos
	center_pos.y += 3

	# 存储目标和场景引用，用于伤害结算
	_create_blizzard_effect(center_pos, range_bonus, duration, damage_per_second, scene_node, target)

func _create_blizzard_effect(center_pos: Vector3, range_bonus: int, duration: int, damage_per_second: int, scene_node: Node = null, target: RefCounted = null) -> void:
	blizzard_area = Area3D.new()
	blizzard_area.name = "BlizzardArea"
	blizzard_area.position = center_pos

	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = area_radius + range_bonus * 0.1
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = sphere_shape
	blizzard_area.add_child(collision_shape)

	var blizzard_particles = _create_blizzard_particles()
	blizzard_area.add_child(blizzard_particles)

	if scene_node:
		scene_node.add_child(blizzard_area)

	_create_visual_indicator(center_pos, area_radius + range_bonus * 0.1, scene_node)

	var timer_duration = max(1, duration)
	var timer = Timer.new()
	timer.wait_time = timer_duration
	timer.one_shot = true
	timer.timeout.connect(func():
		_cleanup_blizzard()
		timer.queue_free()
	)

	if scene_node:
		scene_node.add_child(timer)

	timer.start()

	# 伤害计时器，每秒造成伤害
	var damage_timer = Timer.new()
	damage_timer.wait_time = 1.0
	damage_timer.autostart = true
	# 存储 target 引用用于伤害结算
	var damage_ref = damage_per_second
	var target_ref = target
	damage_timer.timeout.connect(func():
		_deal_damage(damage_ref, target_ref)
	)

	if scene_node:
		scene_node.add_child(damage_timer)

	timer.timeout.connect(func():
		if is_instance_valid(damage_timer):
			damage_timer.queue_free()
	)

func _create_blizzard_particles() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	particles.name = "BlizzardParticles"
	particles.amount = 300
	particles.lifetime = 5.0
	particles.speed_scale = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	
	var process_material = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(4, 2, 4)
	process_material.direction = Vector3(0, -1, 0)
	process_material.spread = 10.0
	process_material.initial_velocity_min = 0.5
	process_material.initial_velocity_max = 2.0
	process_material.gravity = Vector3(0, -0.5, 0)
	process_material.scale_min = 0.4
	process_material.scale_max = 0.8
	
	var color_gradient = Gradient.new()
	color_gradient.add_point(0.0, Color(1, 1, 1, 1))
	color_gradient.add_point(0.5, Color(0.8, 0.8, 1, 1))
	color_gradient.add_point(1.0, Color(0.6, 0.6, 1, 1))
	process_material.color_ramp = color_gradient
	
	process_material.angular_velocity_min = -90
	process_material.angular_velocity_max = 90
	
	particles.process_material = process_material
	
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	particles.draw_pass_1 = sphere_mesh
	
	particles.emitting = true
	
	return particles

func _create_visual_indicator(center_pos: Vector3, radius: float, scene_node: Node = null) -> void:
	var indicator = MeshInstance3D.new()
	indicator.name = "BlizzardIndicator"
	
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = 0.1
	cylinder_mesh.radial_segments = 32
	
	indicator.mesh = cylinder_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.8, 1, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	indicator.material_override = material
	indicator.position = Vector3(center_pos.x, 0.05, center_pos.z)
	indicator.rotation_degrees = Vector3(90, 0, 0)
	
	if scene_node:
		scene_node.add_child(indicator)
	
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(indicator):
			indicator.queue_free()
		timer.queue_free()
	)
	
	if scene_node:
		scene_node.add_child(timer)
	
	timer.start()

func _deal_damage(damage: int, target: RefCounted = null) -> void:
	# 对目标造成伤害（暴风雪是持续性伤害，每秒结算一次）
	if target and is_instance_valid(target):
		if target is BaseCharacter:
			# 调用角色的 take_damage 方法
			target.take_damage(damage)
			print("【BlizzardSkill】对 ", target.name, " 造成 ", damage, " 点持续伤害")
		else:
			print("【BlizzardSkill】目标类型不正确，伤害未生效")
	else:
		print("【BlizzardSkill】目标无效，伤害未生效")

func _cleanup_blizzard() -> void:
	if blizzard_area:
		blizzard_area.queue_free()
		blizzard_area = null
	
	cleanup()

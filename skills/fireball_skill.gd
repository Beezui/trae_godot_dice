extends RefCounted

var fireball_speed: float = 25.0
var explosion_radius: float = 2.0
var current_fireball: Node3D = null
var skill_config: Dictionary = {}
var is_executing: bool = false

func init(config: Dictionary) -> void:
	skill_config = config

func cleanup() -> void:
	is_executing = false
	if current_fireball:
		current_fireball.queue_free()
		current_fireball = null

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
	
	var p1 = calculate_damage("str*2 + agi*2", dice_results)
	
	if targets.is_empty():
		cleanup()
		return

	var target = targets[randi() % targets.size()]
	var target_pos = target.global_position if target else Vector3(6, 0.5, 0)
	
	_launch_fireball(caster_position, target_pos, p1, scene_node)

func _launch_fireball(start_pos: Vector3, target_pos: Vector3, damage: int, scene_node: Node = null) -> void:
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
	
	if scene_node:
		scene_node.add_child(fireball_mesh_instance)
	
	current_fireball = fireball_mesh_instance
	
	var distance = start_pos.distance_to(target_pos)
	var travel_time = distance / fireball_speed
	
	var tween = fireball_mesh_instance.create_tween()
	tween.tween_property(fireball_mesh_instance, "position", target_pos, travel_time)
	tween.tween_callback(_on_fireball_hit.bind(target_pos, damage, scene_node))

func _on_fireball_hit(hit_position: Vector3, damage: int, scene_node: Node = null) -> void:
	_trigger_explosion(hit_position, scene_node)
	
	if current_fireball:
		current_fireball.queue_free()
		current_fireball = null
	
	cleanup()

func _trigger_explosion(hit_position: Vector3, scene_node: Node = null) -> void:
	var explosion_particles = CPUParticles3D.new()
	explosion_particles.name = "FireballExplosion"
	explosion_particles.position = hit_position
	explosion_particles.amount = 400
	explosion_particles.lifetime = 1.3
	explosion_particles.explosiveness = 1.0
	explosion_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	explosion_particles.emission_sphere_radius = explosion_radius
	explosion_particles.gravity = Vector3(0, 0, 0)
	explosion_particles.initial_velocity_min = 4.0
	explosion_particles.initial_velocity_max = 4.0
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.6, 0, 1)
	material.emission_enabled = true
	material.emission = Color(1, 0.4, 0, 1)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	explosion_particles.material_override = material
	
	if scene_node:
		scene_node.add_child(explosion_particles)
	
	explosion_particles.emitting = true
	
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if is_instance_valid(explosion_particles):
			explosion_particles.queue_free()
		if is_instance_valid(timer):
			timer.queue_free()
	)
	
	if scene_node:
		scene_node.add_child(timer)
	
	timer.start()

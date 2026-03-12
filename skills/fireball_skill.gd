extends RefCounted

## 火球术技能
## 向目标发射火球，造成范围伤害

# 火球速度
var fireball_speed: float = 25.0
# 爆炸半径
var explosion_radius: float = 2.0
# 当前火球对象
var current_fireball: Node3D = null
# 技能配置数据
var skill_config: Dictionary = {}
# 技能是否正在执行
var is_executing: bool = false


## 初始化技能
func init(config: Dictionary) -> void:
	skill_config = config


## 清理技能效果
func cleanup() -> void:
	is_executing = false
	if current_fireball:
		current_fireball.queue_free()
		current_fireball = null


## 获取技能配置
func get_config() -> Dictionary:
	return skill_config


## 获取技能 ID
func get_skill_id() -> String:
	return skill_config.get("id", "")


## 获取技能名称
func get_skill_name() -> String:
	return skill_config.get("name", "Unknown")


## 获取技能类型
func get_skill_type() -> String:
	return skill_config.get("type", "")


## 获取目标类型
func get_target_type() -> String:
	return skill_config.get("target_type", "")


## 计算伤害公式
func calculate_damage(formula: String, dice_results: Dictionary) -> int:
	var evaluated_formula = formula
	
	# 替换属性值为实际数值
	if dice_results.has("str"):
		evaluated_formula = evaluated_formula.replace("str", str(dice_results["str"]))
	if dice_results.has("agi"):
		evaluated_formula = evaluated_formula.replace("agi", str(dice_results["agi"]))
	if dice_results.has("int"):
		evaluated_formula = evaluated_formula.replace("int", str(dice_results["int"]))
	
	return _evaluate_expression(evaluated_formula)


## 计算表达式
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


## 计算乘除法表达式
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


## 执行火球术
func execute(caster: Node = null, targets: Array = [], params: Dictionary = {}) -> void:
	print("=== 火球术执行 ===")
	var caster_name = "无"
	if caster:
		caster_name = caster.name
	print("施法者：", caster_name)
	print("目标数量：", targets.size())
	print("参数：", params)
	
	# 从参数中获取骰子结果
	var dice_results = params.get("dice_results", {})
	
	# 获取场景（从参数或 caster）
	var scene_node: Node = params.get("scene", null)
	if not scene_node and caster:
		scene_node = caster.get_tree().current_scene
	if not scene_node:
		print("警告：无法获取场景节点，技能效果可能无法显示")
	
	# 获取施法者位置（优先使用参数中的位置）
	var caster_position: Vector3 = params.get("caster_position", Vector3(-6, 0.5, 0))
	if caster and caster.has_method("get_global_position"):
		caster_position = caster.global_position
	
	# 计算伤害
	var p1 = calculate_damage("str*2 + agi*2", dice_results)
	
	print("力量骰子结果：", dice_results.get("str", 0))
	print("敏捷骰子结果：", dice_results.get("agi", 0))
	print("火球伤害：", p1, " 点")
	print("施法者位置：", caster_position)
	
	# 选择目标
	if targets.is_empty():
		print("错误：没有目标")
		cleanup()
		return
	
	var target = targets[randi() % targets.size()]
	var target_pos = target.global_position if target else Vector3(6, 0.5, 0)
	
	print("目标位置：", target_pos)
	
	# 发射火球
	_launch_fireball(caster_position, target_pos, p1, scene_node)


## 发射火球
func _launch_fireball(start_pos: Vector3, target_pos: Vector3, damage: int, scene_node: Node = null) -> void:
	print("【发射火球】")
	print("起点：", start_pos)
	print("目标：", target_pos)
	print("预计伤害：", damage)
	
	# 创建火球节点
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
	
	# 添加到场景
	if scene_node:
		scene_node.add_child(fireball_mesh_instance)
	else:
		print("警告：没有场景节点，火球无法添加到场景")
	
	current_fireball = fireball_mesh_instance
	
	# 计算飞行时间
	var distance = start_pos.distance_to(target_pos)
	var travel_time = distance / fireball_speed
	
	# 创建 Tween 移动火球
	var tween = fireball_mesh_instance.create_tween()
	tween.tween_property(fireball_mesh_instance, "position", target_pos, travel_time)
	tween.tween_callback(_on_fireball_hit.bind(target_pos, damage, scene_node))
	
	print("火球已发射，预计飞行时间：", travel_time, "秒")


## 火球命中目标
func _on_fireball_hit(hit_position: Vector3, damage: int, scene_node: Node = null) -> void:
	print("=== 火球命中目标 ===")
	print("命中位置：", hit_position)
	print("造成伤害：", damage)
	
	# 触发爆炸效果
	_trigger_explosion(hit_position, scene_node)
	
	# 清理火球
	if current_fireball:
		current_fireball.queue_free()
		current_fireball = null
	
	# 技能结束
	cleanup()


## 触发爆炸效果
func _trigger_explosion(hit_position: Vector3, scene_node: Node = null) -> void:
	print("【触发爆炸效果】")
	print("爆炸位置：", hit_position)
	print("爆炸半径：", explosion_radius)
	
	# 创建爆炸粒子
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
	
	# 创建粒子材质
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.6, 0, 1)
	material.emission_enabled = true
	material.emission = Color(1, 0.4, 0, 1)
	material.emission_energy_multiplier = 2.0  # 增强发光效果
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # 启用透明度
	explosion_particles.material_override = material
	
	# 添加到场景
	if scene_node:
		scene_node.add_child(explosion_particles)
		print("爆炸粒子已添加到场景：", scene_node.name)
	else:
		print("错误：没有场景节点，无法添加爆炸粒子")
	
	# 启动粒子发射
	explosion_particles.emitting = true
	print("爆炸粒子已启动，位置：", hit_position)
	
	# 自动清理
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

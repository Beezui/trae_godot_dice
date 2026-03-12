extends RefCounted

## 暴风雪技能
## 在目标区域降下暴风雪，持续造成伤害

# 暴风雪区域半径
var area_radius: float = 3.0
# 基础持续时间
var duration_base: int = 2
# 当前暴风雪区域
var blizzard_area: Area3D = null
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
	if blizzard_area:
		blizzard_area.queue_free()
		blizzard_area = null


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


## 执行暴风雪
func execute(caster: Node = null, targets: Array = [], params: Dictionary = {}) -> void:
	print("=== 暴风雪执行 ===")
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
	
	# 计算技能参数
	var p1 = calculate_damage("int*2", dice_results)  # 范围
	var p2 = calculate_damage("str*2", dice_results)  # 持续时间
	var p3 = calculate_damage("agi*3", dice_results)  # 每秒伤害
	
	print("智力骰子结果：", dice_results.get("int", 0))
	print("力量骰子结果：", dice_results.get("str", 0))
	print("敏捷骰子结果：", dice_results.get("agi", 0))
	print("暴风雪参数:")
	print("  p1 (范围): ", p1, " 单位")
	print("  p2 (持续时间): ", p2, " 秒")
	print("  p3 (每秒伤害): ", p3, " 点")
	print("施法者位置：", caster_position)
	
	# 选择目标
	if targets.is_empty():
		print("错误：没有目标")
		cleanup()
		return
	
	var target = targets[randi() % targets.size()]
	var center_pos = target.global_position if target else Vector3(6, 0.5, 0)
	center_pos.y += 3  # 在目标上方生成
	
	# 创建暴风雪效果
	_create_blizzard_effect(center_pos, p1, p2, p3, scene_node)


## 创建暴风雪效果
func _create_blizzard_effect(center_pos: Vector3, range_bonus: int, duration: int, damage_per_second: int, scene_node: Node = null) -> void:
	print("【创建暴风雪效果】")
	print("中心位置：", center_pos)
	print("实际范围：", area_radius + range_bonus * 0.1)
	print("持续时间：", duration, " 秒")
	print("每秒伤害：", damage_per_second)
	
	# 创建暴风雪区域
	blizzard_area = Area3D.new()
	blizzard_area.name = "BlizzardArea"
	blizzard_area.position = center_pos
	
	# 添加碰撞形状
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = area_radius + range_bonus * 0.1
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = sphere_shape
	blizzard_area.add_child(collision_shape)
	
	# 创建暴风雪粒子
	var blizzard_particles = _create_blizzard_particles()
	blizzard_area.add_child(blizzard_particles)
	
	# 添加到场景
	if scene_node:
		scene_node.add_child(blizzard_area)
	else:
		print("警告：没有场景节点，暴风雪无法添加到场景")
	
	# 创建视觉指示器
	_create_visual_indicator(center_pos, area_radius + range_bonus * 0.1, scene_node)
	
	# 设置持续时间计时器（确保时间大于 0）
	var timer_duration = max(1, duration)  # 至少 1 秒
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
	
	# 持续伤害逻辑（简化版，实际需要检测区域内敌人）
	var damage_timer = Timer.new()
	damage_timer.wait_time = 1.0
	damage_timer.autostart = true
	damage_timer.timeout.connect(func():
		_deal_damage(damage_per_second)
	)
	
	if scene_node:
		scene_node.add_child(damage_timer)
	
	# 在暴风雪结束时清理伤害计时器
	timer.timeout.connect(func():
		if is_instance_valid(damage_timer):
			damage_timer.queue_free()
	)


## 创建暴风雪粒子
func _create_blizzard_particles() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	particles.name = "BlizzardParticles"
	particles.amount = 300
	particles.lifetime = 5.0
	particles.speed_scale = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	
	# 创建粒子材质
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
	
	# 颜色渐变
	var color_gradient = Gradient.new()
	color_gradient.add_point(0.0, Color(1, 1, 1, 1))
	color_gradient.add_point(0.5, Color(0.8, 0.8, 1, 1))
	color_gradient.add_point(1.0, Color(0.6, 0.6, 1, 1))
	process_material.color_ramp = color_gradient
	
	process_material.angular_velocity_min = -90
	process_material.angular_velocity_max = 90
	
	particles.process_material = process_material
	
	# 创建粒子网格
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	particles.draw_pass_1 = sphere_mesh
	
	particles.emitting = true
	
	return particles


## 创建视觉指示器
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
	else:
		print("警告：没有场景节点，视觉指示器无法添加到场景")
	
	# 5 秒后淡出
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


## 造成伤害（简化版）
func _deal_damage(damage: int) -> void:
	print("暴风雪造成伤害：", damage, " 点")
	# 实际游戏中需要检测区域内的敌人并造成伤害


## 清理暴风雪
func _cleanup_blizzard() -> void:
	print("清理暴风雪效果")
	if blizzard_area:
		blizzard_area.queue_free()
		blizzard_area = null
	
	cleanup()

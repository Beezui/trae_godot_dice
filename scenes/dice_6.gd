extends RigidBody3D

@export var dice_value: int = 1
@export var dice_faces: Array = [1, 2, 3, 4, 5, 6]
@export var dice_type: String = "normal"

var is_rolling: bool = false
var roll_timer: Timer
var collision_count: int = 0
var skill_system
var particle_system
var controlled_result: int = -1  # -1表示没有控制结果
var result_control_timer: Timer

func _ready():
	# 初始化系统
	skill_system = preload("res://scripts/skill_system.gd").new()
	particle_system = preload("res://scripts/particle_system.gd").new()
	
	# 调整物理参数
	contact_monitor = true
	max_contacts_reported = 10
	
	# 设置质量，减小质量使旋转更容易
	mass = 0.5
	
	# 设置阻尼
	linear_damp = 0.1  # 增加线性阻尼
	angular_damp = 0.03  # 进一步减少角阻尼，使旋转持续时间更长
	
	# 设置物理材质
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.1404  # 提升反弹效果50%
	physics_material.friction = 0.8  # 增加摩擦力
	
	# 应用物理材质到刚体
	physics_material_override = physics_material
	
	# 初始状态：禁用重力，使骰子悬浮
	gravity_scale = 0.0
	
	# 确保骰子静止
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# 创建碰撞形状
	var collision_shape = $CollisionShape3D
	if collision_shape:
		var cube_shape = BoxShape3D.new()
		cube_shape.size = Vector3(1, 1, 1)
		collision_shape.shape = cube_shape
	
	# 创建计时器
	roll_timer = Timer.new()
	roll_timer.wait_time = 3.0
	roll_timer.one_shot = true
	roll_timer.timeout.connect(_on_roll_timer_timeout)
	add_child(roll_timer)
	
	result_control_timer = Timer.new()
	result_control_timer.wait_time = 2.0
	result_control_timer.one_shot = true
	result_control_timer.timeout.connect(_on_result_control_timeout)
	add_child(result_control_timer)
	
	# 初始化骰子模型
	init_dice_model()
	
	print("Dice initialization complete")
	
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func init_dice_model():
	# 检查网格实例是否存在
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		print("MeshInstance3D found: ", mesh_instance.name)
		
		# 检查是否有有效的mesh
		if mesh_instance.mesh:
			print("Using imported dice model")
			# 缩放模型以适应场景
			mesh_instance.scale = Vector3(1, 1, 1)
		else:
			print("No mesh found, trying to load model")
			# 尝试加载模型
			load_dice_model(mesh_instance)
	else:
		print("MeshInstance3D not found, creating fallback")
		# 创建备用网格实例
		create_fallback_mesh()

func load_dice_model(mesh_instance):
	# 尝试加载GLTF模型
	var model_path = "res://models/dice_smooth.gltf"
	var model_resource = load(model_path)
	
	if model_resource:
		print("Model resource loaded: ", model_path)
		# 实例化模型
		var model_instance = model_resource.instantiate()
		
		if model_instance:
			print("Model instantiated successfully")
			# 直接检查模型实例是否有mesh属性（因为GLTF根节点就是MeshInstance3D）
			if model_instance.has_method("get_mesh") and model_instance.mesh:
				mesh_instance.mesh = model_instance.mesh
				# 缩放模型以适应场景
				mesh_instance.scale = Vector3(1, 1, 1)
				print("Model mesh assigned from root node")
			else:
				# 如果根节点没有mesh，尝试遍历所有子节点
				var children = model_instance.get_children()
				var mesh_found = false
				
				for child in children:
					if child.has_method("get_mesh") and child.mesh:
						mesh_instance.mesh = child.mesh
						mesh_instance.scale = Vector3(1, 1, 1)
						mesh_found = true
						print("Model mesh assigned from child node")
						break
					# 递归检查子节点
					var grand_children = child.get_children()
					for grand_child in grand_children:
						if grand_child.has_method("get_mesh") and grand_child.mesh:
							mesh_instance.mesh = grand_child.mesh
							mesh_instance.scale = Vector3(1, 1, 1)
							mesh_found = true
							print("Model mesh assigned from grandchild node")
							break
						if mesh_found:
							break
					if mesh_found:
						break
				
				if not mesh_found:
					print("No mesh found in model, creating fallback")
					create_fallback_mesh()
			# 清理临时实例
			model_instance.queue_free()
		else:
			print("Failed to instantiate model, creating fallback")
			create_fallback_mesh()
	else:
		print("Failed to load model resource, creating fallback")
		create_fallback_mesh()

func create_fallback_mesh():
	# 创建备用立方体网格
	var mesh_instance = $MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
	
	# 创建默认立方体
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3(1, 1, 1)
	mesh_instance.mesh = cube_mesh
	
	# 创建材质
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 1)  # 使用白色，确保可见
	material.roughness = 0.8
	mesh_instance.material_override = material
	
	print("Fallback cube mesh created")

func roll(force: Vector3, angular_force: Vector3 = Vector3.ZERO):
	# 恢复重力影响
	gravity_scale = 1.0
	
	is_rolling = true
	collision_count = 0
	linear_velocity = force
	
	# 如果提供了旋转力，则使用它；否则使用随机旋转力
	if angular_force != Vector3.ZERO:
		angular_velocity = angular_force
	else:
		angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
	
	roll_timer.start()
	
	# 如果有控制结果，启动结果控制计时器
	if controlled_result != -1:
		result_control_timer.start()

func _on_roll_timer_timeout():
	is_rolling = false
	check_dice_value()

func _on_result_control_timeout():
	# 控制骰子结果
	if controlled_result != -1:
		# 计算目标旋转
		var target_rotation = get_target_rotation(controlled_result)
		# 平滑过渡到目标旋转
		rotation = target_rotation
		# 确保骰子稳定
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		# 直接设置骰子值
		dice_value = controlled_result
		print("Controlled dice result: ", dice_value)
		# 重置控制状态
		controlled_result = -1

func get_target_rotation(value: int) -> Quaternion:
	# 根据骰子值计算目标旋转
	match value:
		1:
			# 1点朝上
			return Quaternion()
		2:
			# 2点朝上
			return Quaternion(Vector3(0, 1, 0), deg_to_rad(90))
		3:
			# 3点朝上
			return Quaternion(Vector3(0, 0, 1), deg_to_rad(-90))
		4:
			# 4点朝上
			return Quaternion(Vector3(0, 0, 1), deg_to_rad(90))
		5:
			# 5点朝上
			return Quaternion(Vector3(0, 1, 0), deg_to_rad(-90))
		6:
			# 6点朝上
			return Quaternion(Vector3(0, 1, 0), deg_to_rad(180))
		_:
			return Quaternion()

func check_dice_value():
	# 如果有控制结果，直接使用控制值
	if controlled_result != -1:
		dice_value = controlled_result
		print("Dice rolled: ", dice_value)
		trigger_skill()
		return
	
	# 从骰子中心向六个方向发射射线，检测哪个面朝上
	var ray_origin = global_position
	var directions = [
		Vector3.UP,      # 1点
		Vector3.DOWN,    # 6点
		Vector3.RIGHT,   # 3点
		Vector3.LEFT,    # 4点
		Vector3.FORWARD, # 2点
		Vector3.BACK     # 5点
	]
	var values = [1, 6, 3, 4, 2, 5]
	
	var space_state = get_world_3d().direct_space_state
	
	for i in range(directions.size()):
		var direction = directions[i]
		var query = PhysicsRayQueryParameters3D.new()
		query.from = ray_origin
		query.to = ray_origin + direction * 100
		query.exclude = [self]
		var result = space_state.intersect_ray(query)
		
		if result:
			# 检查碰撞点是否在骰子的哪个面上
			var collision_normal = result.normal
			if collision_normal.dot(direction) > 0.9:
				dice_value = values[i]
				print("Dice rolled: ", dice_value)
				trigger_skill()
				break

func trigger_skill():
	# 根据骰子点数触发对应技能
	var skill_id = skill_system.get_skill_by_dice_value(dice_value)
	if skill_id:
		var skill = skill_system.get_skill(skill_id)
		print("Triggering skill: ", skill.name)
		skill_system.use_skill(skill_id, self)
		
		# 生成技能粒子特效
		var particles = particle_system.spawn_skill_particles(skill_id, global_position)
		if particles:
			get_parent().add_child(particles)
			particles.emitting = true
		
		# 更新结果显示
		var parent = get_parent()
		if parent and parent.has_method("update_result_display"):
			parent.update_result_display(dice_value, skill.name)

func _process(delta):
	# 更新技能冷却（如果方法存在）
	if skill_system and skill_system.has_method("update_cooldowns"):
		skill_system.update_cooldowns(delta)
	# 更新粒子系统（如果方法存在）
	if particle_system and particle_system.has_method("update"):
		particle_system.update(delta)

func _on_body_entered(body):
	if is_rolling:
		collision_count += 1
		print("Dice collided with: ", body.name)
		# 这里可以添加碰撞特效和技能触发逻辑
		
		# 检测是否与其他骰子碰撞
		if body is RigidBody3D and body.has_method("get_dice_type"):
			print("Collided with another dice: ", body.get_dice_type())
			
		# 检测是否与场景物体碰撞
		elif body is StaticBody3D:
			print("Collided with scene object: ", body.name)

func _on_body_exited(_body):
	if is_rolling:
		collision_count = max(0, collision_count - 1)

func get_dice_type() -> String:
	return dice_type

func get_collision_count() -> int:
	return collision_count

func set_controlled_result(value: int):
	# 设置控制结果
	if value >= 1 and value <= dice_faces.size():
		controlled_result = value
		print("Set controlled result: ", value)

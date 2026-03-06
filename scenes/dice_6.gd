extends RigidBody3D

@export var dice_value: int = 1
@export var dice_faces: Array = [1, 2, 3, 4, 5, 6]
@export var dice_type: String = "normal"
@export var dice_face_config: Dictionary = {}

var is_rolling: bool = false
var roll_timer: Timer
var collision_count: int = 0
var skill_system
var particle_system
var dice_face_manager
var controlled_result: int = -1  # -1表示没有控制结果
var result_control_timer: Timer
var has_valid_result: bool = false  # 标记骰子是否有有效结果
var result_check_timer: Timer  # 用于定期检查骰子状态

func _ready():
	# 初始化系统
	skill_system = preload("res://scripts/skill_system.gd").new()
	particle_system = preload("res://scripts/particle_system.gd").new()
	dice_face_manager = preload("res://scripts/dice_face_manager.gd").new()
	
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
	
	# 确保骰子可见
	visible = true
	
	# 确保骰子大小合适
	scale = Vector3(1, 1, 1)
	
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
	
	# 创建结果检查计时器
	result_check_timer = Timer.new()
	result_check_timer.wait_time = 0.5  # 每0.5秒检查一次
	result_check_timer.timeout.connect(_on_result_check_timeout)
	add_child(result_check_timer)
	
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
		
		# 确保网格实例可见
		mesh_instance.visible = true
		
		# 检查是否有有效的mesh
		if mesh_instance.mesh:
			print("Using imported dice model")
			# 缩放模型以适应场景
			mesh_instance.scale = Vector3(1, 1, 1)
			# 应用六面贴图
			apply_dice_textures(mesh_instance)
		else:
			print("No mesh found, trying to load model")
			# 尝试加载模型
			load_dice_model(mesh_instance)
	else:
		print("MeshInstance3D not found, creating fallback")
		# 创建备用网格实例
		create_fallback_mesh()

func apply_dice_textures(mesh_instance):
	# 为骰子的六个面应用不同的材质
	var materials = []
	
	# 定义不同ID对应的颜色（作为备用）
	var id_colors = {
		1: Color(1, 0, 0, 1),   # 红色
		2: Color(0, 1, 0, 1),   # 绿色
		3: Color(0, 0, 1, 1),   # 蓝色
		4: Color(1, 1, 0, 1),   # 黄色
		5: Color(1, 0, 1, 1),   # 紫色
		6: Color(0, 1, 1, 1),   # 青色
		7: Color(1, 0.5, 0, 1), # 橙色
		8: Color(0.5, 0, 0.5, 1), # 深紫色
		9: Color(0, 0.5, 0.5, 1)  # 深青色
	}
	
	# 创建六个面的材质
	for i in range(6):
		# 获取当前面的配置
		var face_id = dice_face_config.get(i, 1)
		# 创建材质
		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		
		# 尝试从CSV加载贴图
		var texture_path = dice_face_manager.get_texture_path_by_id(face_id)
		if texture_path and not texture_path.is_empty():
			print("Loading texture for face ", i, " with ID: ", face_id, " from path: ", texture_path)
			var texture = load(texture_path)
			if texture:
				print("Successfully loaded texture: ", texture_path)
				material.albedo_texture = texture
			else:
				print("Failed to load texture: ", texture_path)
				# 加载失败，使用彩色材质
				var color = id_colors.get(face_id, Color(0.5, 0.5, 0.5, 1))  # 默认灰色
				material.albedo_color = color
				print("Using fallback color: ", color)
		else:
			# 没有贴图路径，使用彩色材质
			var color = id_colors.get(face_id, Color(0.5, 0.5, 0.5, 1))  # 默认灰色
			material.albedo_color = color
			print("No texture path, using color: ", color)
		
		materials.append(material)
	
	# 应用材质到网格
	if mesh_instance.mesh and materials.size() > 0:
		# 尝试为每个面设置不同的材质
		var surface_count = mesh_instance.mesh.get_surface_count()
		print("Mesh surface count: ", surface_count)
		
		# 对于多面体网格，为每个面设置材质
		if surface_count >= 6:
			for i in range(6):
				if i < surface_count:
					mesh_instance.mesh.surface_set_material(i, materials[i])
					print("Applied material ", i, " to surface ", i)
			print("Applied materials to mesh surfaces")
		else:
			# 对于单一表面的网格，使用材质覆盖
			mesh_instance.material_override = materials[0]
			print("Applied default material to dice model")
		
		# 存储材质数组，以便在运行时切换
		mesh_instance.set_meta("dice_materials", materials)

func load_dice_model(mesh_instance):
	# 直接使用fallback mesh，确保有6个独立表面
	print("Using fallback mesh with 6 surfaces")
	create_fallback_mesh()

func create_fallback_mesh():
	# 创建备用立方体网格
	var mesh_instance = $MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
	
	# 创建一个具有6个独立表面的立方体
	var mesh = ArrayMesh.new()
	
	# 定义立方体的8个顶点
	var vertices = [
		Vector3(-0.5, -0.5, -0.5),  # 0
		Vector3(0.5, -0.5, -0.5),   # 1
		Vector3(0.5, 0.5, -0.5),    # 2
		Vector3(-0.5, 0.5, -0.5),   # 3
		Vector3(-0.5, -0.5, 0.5),   # 4
		Vector3(0.5, -0.5, 0.5),    # 5
		Vector3(0.5, 0.5, 0.5),     # 6
		Vector3(-0.5, 0.5, 0.5)     # 7
	]
	
	# 定义6个面的索引（每个面4个顶点）
	var faces = [
		[0, 1, 2, 3],  # 前面
		[5, 4, 7, 6],  # 后面
		[4, 0, 3, 7],  # 左面
		[1, 5, 6, 2],  # 右面
		[3, 2, 6, 7],  # 顶面
		[4, 5, 1, 0]   # 底面
	]
	
	# 为每个面创建独立的表面
	for i in range(6):
		# 创建表面数据
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		
		# 顶点数据
		var surface_vertices = []
		for j in faces[i]:
			surface_vertices.append(vertices[j])
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(surface_vertices)
		
		# 法线数据
		var normals = []
		var normal = Vector3(0, 0, 0)
		match i:
			0: normal = Vector3(0, 0, -1)  # 前面
			1: normal = Vector3(0, 0, 1)   # 后面
			2: normal = Vector3(-1, 0, 0)  # 左面
			3: normal = Vector3(1, 0, 0)   # 右面
			4: normal = Vector3(0, 1, 0)   # 顶面
			5: normal = Vector3(0, -1, 0)  # 底面
		for j in range(4):
			normals.append(normal)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
		
		# UV数据
		var uvs = [
			Vector2(0, 0),
			Vector2(1, 0),
			Vector2(1, 1),
			Vector2(0, 1)
		]
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
		
		# 索引数据
		var indices = [0, 1, 2, 0, 2, 3]
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
		
		# 添加表面
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# 设置网格
	mesh_instance.mesh = mesh
	
	# 应用贴图
	apply_dice_textures(mesh_instance)
	
	print("Fallback cube mesh with 6 surfaces created")

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
	# 检查骰子是否真的停止运动
	if linear_velocity.length() < 0.1 and angular_velocity.length() < 0.1:
		is_rolling = false
		check_dice_value()
		# 通知骰子管理器
		var parent = get_parent()
		if parent and parent.has_method("on_dice_stopped"):
			parent.on_dice_stopped()
	else:
		# 骰子还在运动，重新启动计时器
		roll_timer.start()

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
		has_valid_result = true
		print("Controlled dice result: ", dice_value)
		# 重置控制状态
		controlled_result = -1

func _on_result_check_timeout():
	# 定期检查骰子状态
	if not is_rolling and not has_valid_result:
		# 骰子停止但没有有效结果，应用预防措施
		_apply_preventive_measure()

func _apply_preventive_measure():
	# 应用预防措施，给骰子施加随机力使其重新运动
	if not is_rolling:
		is_rolling = true
		# 施加随机的线性力
		var linear_force = Vector3(
			randf_range(-2, 2),
			randf_range(1, 3),
			randf_range(-2, 2)
		)
		# 施加随机的旋转力
		var angular_force = Vector3(
			randf_range(-5, 5),
			randf_range(-5, 5),
			randf_range(-5, 5)
		)
		
		# 应用力
		linear_velocity = linear_force
		angular_velocity = angular_force
		
		print("Applied preventive measure: small force to reposition dice")
		
		# 重启滚动计时器
		roll_timer.start()

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
		has_valid_result = true
		print("Dice rolled (controlled): ", dice_value)
		trigger_skill()
		return
	
	# 直接根据骰子的旋转计算朝上的面
	var up_direction = Vector3.UP
	var transform = global_transform
	var global_directions = []
	
	# 定义骰子六个面的本地方向，与create_fallback_mesh函数中的面索引顺序匹配
	var local_directions = [
		Vector3(0, 0, -1),  # 前面 (面索引0)
		Vector3(0, 0, 1),   # 后面 (面索引1)
		Vector3(-1, 0, 0),  # 左面 (面索引2)
		Vector3(1, 0, 0),   # 右面 (面索引3)
		Vector3(0, 1, 0),   # 顶面 (面索引4)
		Vector3(0, -1, 0)   # 底面 (面索引5)
	]
	
	# 将本地方向转换为全局方向
	for local_dir in local_directions:
		global_directions.append(transform.basis * local_dir)
	
	# 根据dice_config.gd中的配置，映射每个面索引对应的骰子值
	# 面索引与dice_config的对应关系：
	# 0: 前面 -> dice_config[0] = 1 (1点)
	# 1: 后面 -> dice_config[1] = 2 (2点)
	# 2: 左面 -> dice_config[2] = 3 (3点)
	# 3: 右面 -> dice_config[3] = 4 (4点)
	# 4: 顶面 -> dice_config[4] = 4 (5点)
	# 5: 底面 -> dice_config[5] = 4 (6点)
	var values = [1, 2, 3, 4, 4, 4]
	
	# 找到最接近全局向上方向的面
	var max_dot = -1
	var closest_index = 0
	
	for i in range(global_directions.size()):
		var dot = up_direction.dot(global_directions[i])
		if dot > max_dot:
			max_dot = dot
			closest_index = i
	
	# 设置骰子值
	dice_value = values[closest_index]
	has_valid_result = true
	print("Dice rolled: ", dice_value)
	trigger_skill()
	
	# 不需要预防措施，因为我们总能找到一个面朝上

func trigger_skill():
	# 根据骰子点数触发对应技能
	if skill_system and skill_system.has_method("get_skill_by_dice_value"):
		var skill_id = skill_system.get_skill_by_dice_value(dice_value)
		if skill_id and skill_system.has_method("get_skill") and skill_system.has_method("use_skill"):
			var skill = skill_system.get_skill(skill_id)
			if skill and skill.has("name"):
				print("Triggering skill: ", skill.name)
				skill_system.use_skill(skill_id, self)
				
				# 生成技能粒子特效
				if particle_system and particle_system.has_method("spawn_skill_particles"):
					var particles = particle_system.spawn_skill_particles(skill_id, global_position)
					if particles:
						get_parent().add_child(particles)
						particles.emitting = true
	# 结果显示由 dice_manager 在所有骰子停止后统一处理

func _process(delta):
	# 只在需要时更新系统
	if is_rolling:
		# 更新技能冷却（如果方法存在）
		if skill_system and skill_system.has_method("update_cooldowns"):
			skill_system.update_cooldowns(delta)
		# 更新粒子系统（如果方法存在）
		if particle_system and particle_system.has_method("update"):
			particle_system.update(delta)

func _on_body_entered(body):
	if is_rolling:
		collision_count += 1
		# 只在调试模式下打印
		if Engine.is_editor_hint():
			print("Dice collided with: ", body.name)
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

func get_dice_value() -> int:
	# 获取骰子点数
	return dice_value

func set_controlled_result(value: int):
	# 设置控制结果
	if value >= 1 and value <= dice_faces.size():
		controlled_result = value
		print("Set controlled result: ", value)

func set_dice_face_config(config: Dictionary):
	# 设置骰子面的贴图配置
	dice_face_config = config
	# 更新贴图
	update_dice_textures()
	print("Set dice face config: ", config)

func update_dice_textures():
	# 动态更新骰子贴图
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		apply_dice_textures(mesh_instance)
		print("Updated dice textures")

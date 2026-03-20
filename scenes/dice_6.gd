extends RigidBody3D

@export var dice_value: int = 1              # 当前点数
@export var dice_faces: Array = [1,2,3,4,5,6]  # 骰子面数组
@export var dice_type: String = "normal"      # 骰子类型
@export var dice_face_config: Dictionary = {}  # 贴图配置
@export var dice_value_config: Dictionary = {} # 点数配置

var is_rolling: bool = false
var roll_timer: Timer
var skip_skill_trigger: bool = false
var collision_count: int = 0
var closest_index: int = 0
var skill_system
var particle_system
var controlled_result: int = -1  # -1表示没有控制结果
var result_control_timer: Timer
var has_valid_result: bool = false  # 标记骰子是否有有效结果
var result_check_timer: Timer  # 用于定期检查骰子状态

func _ready():
	# 初始化系统
	print("【骰子】_ready() 开始执行")
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
	physics_material.bounce = 0.1404  # 提升反弹效果 50%
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
	result_check_timer.wait_time = 0.5  # 每 0.5 秒检查一次
	result_check_timer.timeout.connect(_on_result_check_timeout)
	add_child(result_check_timer)
	
	# 初始化骰子模型
	init_dice_model()
	
	print("【骰子】_ready() 执行完成，等待配置加载")
	
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
		
		# 检查是否有有效的 mesh
		if mesh_instance.mesh:
			print("Using imported dice model")
			# 缩放模型以适应场景
			mesh_instance.scale = Vector3(1, 1, 1)
			# 注意：不在这里应用贴图，等 set_dice_face_config 调用时再应用
			print("【初始化】等待配置加载，暂不应用贴图")
		else:
			print("No mesh found, creating fallback mesh")
			# 创建备用网格实例（会创建 ArrayMesh）
			create_fallback_mesh()
			# 重新获取 mesh_instance
			mesh_instance = $MeshInstance3D
			if mesh_instance and mesh_instance.mesh:
				print("【初始化】备用网格创建完成，等待配置加载")
	else:
		print("MeshInstance3D not found, creating fallback")
		# 创建备用网格实例
		create_fallback_mesh()


func load_dice_model(_mesh_instance):
	# 直接使用 fallback mesh，确保有 6 个独立表面
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
	
	# 注意：不在这里应用贴图，等 set_dice_face_config 调用时再应用
	print("Fallback cube mesh with 6 surfaces created")

func stop_rolling():
	if roll_timer:
		roll_timer.stop()
	is_rolling = false

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
	var dice_transform = global_transform
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
	
	# 将每个面的本地方向转换为全局方向
	for local_dir in local_directions:
		global_directions.append(dice_transform.basis * local_dir)
	
	# 找到最接近全局向上方向的面
	var max_dot = -1
	closest_index = 0
	
	for i in range(global_directions.size()):
		var dot = up_direction.dot(global_directions[i])
		if dot > max_dot:
			max_dot = dot
			closest_index = i
	
	# 设置骰子值，使用从CSV读取的点数配置
	if dice_value_config.size() > 0:
		# 使用从CSV读取的点数配置
		dice_value = dice_value_config.get(closest_index, 1)
	else:
		# 使用默认值
		var values = [1, 2, 3, 4, 5, 6]
		dice_value = values[closest_index]
	has_valid_result = true
	print("Dice rolled: ", dice_value)
	trigger_skill()
	
	# 不需要预防措施，因为我们总能找到一个面朝上

func trigger_skill():
	print("=== trigger_skill() 被调用 ===")
	print("skip_skill_trigger = ", skip_skill_trigger)
	if skip_skill_trigger:
		return
	
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

func get_dice_face_index() -> int:
	return closest_index

func get_collision_count() -> int:
	return collision_count

func get_dice_value() -> int:
	# 获取骰子点数
	return dice_value

func get_has_valid_result() -> bool:
	# 获取是否有有效结果
	return has_valid_result

func set_controlled_result(value: int):
	# 设置控制结果
	if value >= 1 and value <= dice_faces.size():
		controlled_result = value
		print("Set controlled result: ", value)

func set_dice_face_config(config: Dictionary, value_config: Dictionary = {}):
	# 设置骰子面的贴图配置
	print("【骰子】set_dice_face_config 被调用，config=", config)
	dice_face_config = config
	print("【骰子】dice_face_config 已赋值：", dice_face_config)
	# 设置骰子面的点数配置
	dice_value_config = value_config
	# 使用 DiceTextureManager 统一应用贴图
	print("【骰子】准备调用 apply_textures_from_manager")
	apply_textures_from_manager()
	print("Set dice face config: ", config)
	print("Set dice value config: ", value_config)


func apply_textures_from_manager():
	# 使用 DiceTextureManager 统一应用贴图
	print("【骰子】apply_textures_from_manager 被调用，dice_face_config=", dice_face_config)
	if DiceTextureManager:
		print("【骰子】调用 DiceTextureManager.apply_textures_to_dice，config=", dice_face_config)
		DiceTextureManager.apply_textures_to_dice(self, dice_face_config)
	else:
		print("【骰子】错误：DiceTextureManager 不存在")


func update_dice_textures():
	# 动态更新骰子贴图（已废弃，使用 apply_textures_from_manager 替代）
	apply_textures_from_manager()

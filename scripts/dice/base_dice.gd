class_name BaseDice
extends RigidBody3D

## 骰子类型枚举
enum DiceType { 
	NUM,      ## 数字骰子
	ATTR,     ## 属性骰子
	SKILL,    ## 技能骰子
	ELEMENT   ## 元素骰子 (预留)
}

## 骰子类型
@export var dice_type: DiceType = DiceType.NUM

## 骰子点数
@export var dice_value: int = 1

## 骰子面配置
@export var dice_face_config: Dictionary = {}

## 骰子值配置
@export var dice_value_config: Dictionary = {}

## 是否正在滚动
var is_rolling: bool = false

## 滚动计时器
var roll_timer: Timer

## 结果控制计时器
var result_control_timer: Timer

## 结果检查计时器
var result_check_timer: Timer

## 控制结果 (-1 表示没有控制)
var controlled_result: int = -1

## 是否有有效结果
var has_valid_result: bool = false

## 最接近的面索引
var closest_index: int = 0

## 碰撞次数
var collision_count: int = 0

## 跳过技能触发
var skip_skill_trigger: bool = false

## 技能系统
var skill_system: RefCounted

## 粒子系统
var particle_system: RefCounted


func _ready():
	# 初始化系统
	skill_system = preload("res://scripts/skill_system.gd").new()
	particle_system = preload("res://scripts/particle_system.gd").new()
	
	# 调整物理参数
	contact_monitor = true
	max_contacts_reported = 10
	
	# 设置质量
	mass = 0.5
	
	# 设置阻尼
	linear_damp = 0.1
	angular_damp = 0.03
	
	# 设置物理材质
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.1404
	physics_material.friction = 0.8
	physics_material_override = physics_material
	
	# 初始状态：禁用重力，使骰子悬浮
	gravity_scale = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	visible = true
	scale = Vector3(1, 1, 1)
	
	# 创建碰撞形状
	var collision_shape = $CollisionShape3D
	if collision_shape:
		var cube_shape = BoxShape3D.new()
		cube_shape.size = Vector3(1, 1, 1)
		collision_shape.shape = cube_shape
	
	# 创建计时器
	_create_timers()
	
	# 初始化骰子模型
	init_dice_model()
	
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("BaseDice 初始化完成，类型：", DiceType.keys()[dice_type])


func _create_timers():
	# 滚动计时器
	roll_timer = Timer.new()
	roll_timer.wait_time = 3.0
	roll_timer.one_shot = true
	roll_timer.timeout.connect(_on_roll_timer_timeout)
	add_child(roll_timer)
	
	# 结果控制计时器
	result_control_timer = Timer.new()
	result_control_timer.wait_time = 2.0
	result_control_timer.one_shot = true
	result_control_timer.timeout.connect(_on_result_control_timeout)
	add_child(result_control_timer)
	
	# 结果检查计时器
	result_check_timer = Timer.new()
	result_check_timer.wait_time = 0.5
	result_check_timer.timeout.connect(_on_result_check_timeout)
	add_child(result_check_timer)


## 初始化骰子模型
func init_dice_model():
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		mesh_instance.visible = true
		if mesh_instance.mesh:
			mesh_instance.scale = Vector3(1, 1, 1)
			apply_dice_textures(mesh_instance)
		else:
			load_dice_model(mesh_instance)
	else:
		create_fallback_mesh()


## 应用贴图 (由子类或策略实现)
func apply_dice_textures(mesh_instance: MeshInstance3D):
	# 默认实现：使用 DiceTextureManager
	if DiceTextureManager:
		DiceTextureManager.apply_textures(self, get_config())


## 加载骰子模型
func load_dice_model(mesh_instance: MeshInstance3D):
	create_fallback_mesh()


## 创建备用网格
func create_fallback_mesh():
	var mesh_instance = $MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
	
	# 创建具有 6 个独立表面的立方体
	var mesh = ArrayMesh.new()
	
	var vertices = [
		Vector3(-0.5, -0.5, -0.5),
		Vector3(0.5, -0.5, -0.5),
		Vector3(0.5, 0.5, -0.5),
		Vector3(-0.5, 0.5, -0.5),
		Vector3(-0.5, -0.5, 0.5),
		Vector3(0.5, -0.5, 0.5),
		Vector3(0.5, 0.5, 0.5),
		Vector3(-0.5, 0.5, 0.5)
	]
	
	var faces = [
		[0, 1, 2, 3],
		[5, 4, 7, 6],
		[4, 0, 3, 7],
		[1, 5, 6, 2],
		[3, 2, 6, 7],
		[4, 5, 1, 0]
	]
	
	for i in range(6):
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		
		var surface_vertices = []
		for j in faces[i]:
			surface_vertices.append(vertices[j])
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(surface_vertices)
		
		var normals = []
		var normal = Vector3(0, 0, 0)
		match i:
			0: normal = Vector3(0, 0, -1)
			1: normal = Vector3(0, 0, 1)
			2: normal = Vector3(-1, 0, 0)
			3: normal = Vector3(1, 0, 0)
			4: normal = Vector3(0, 1, 0)
			5: normal = Vector3(0, -1, 0)
		for j in range(4):
			normals.append(normal)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
		
		var uvs = [
			Vector2(0, 0),
			Vector2(1, 0),
			Vector2(1, 1),
			Vector2(0, 1)
		]
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
		
		var indices = [0, 1, 2, 0, 2, 3]
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
		
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	mesh_instance.mesh = mesh
	apply_dice_textures(mesh_instance)


## 停止滚动
func stop_rolling():
	if roll_timer:
		roll_timer.stop()
	is_rolling = false


## 投掷骰子
func roll(force: Vector3, angular_force: Vector3 = Vector3.ZERO):
	gravity_scale = 1.0
	is_rolling = true
	collision_count = 0
	linear_velocity = force
	
	if angular_force != Vector3.ZERO:
		angular_velocity = angular_force
	else:
		angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
	
	roll_timer.start()
	
	if controlled_result != -1:
		result_control_timer.start()


## 滚动计时器超时
func _on_roll_timer_timeout():
	if linear_velocity.length() < 0.1 and angular_velocity.length() < 0.1:
		is_rolling = false
		check_dice_value()
		var parent = get_parent()
		if parent and parent.has_method("on_dice_stopped"):
			parent.on_dice_stopped()
	else:
		roll_timer.start()


## 结果控制超时
func _on_result_control_timeout():
	if controlled_result != -1:
		var target_rotation = get_target_rotation(controlled_result)
		rotation = target_rotation
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		controlled_result = -1


## 结果检查超时
func _on_result_check_timeout():
	if not is_rolling and not has_valid_result:
		_apply_preventive_measure()


## 应用预防措施
func _apply_preventive_measure():
	if not is_rolling:
		is_rolling = true
		var linear_force = Vector3(
			randf_range(-2, 2),
			randf_range(1, 3),
			randf_range(-2, 2)
		)
		var angular_force = Vector3(
			randf_range(-5, 5),
			randf_range(-5, 5),
			randf_range(-5, 5)
		)
		linear_velocity = linear_force
		angular_velocity = angular_force
		roll_timer.start()


## 获取目标旋转
func get_target_rotation(value: int) -> Quaternion:
	match value:
		1: return Quaternion()
		2: return Quaternion(Vector3(0, 1, 0), deg_to_rad(90))
		3: return Quaternion(Vector3(0, 0, 1), deg_to_rad(-90))
		4: return Quaternion(Vector3(0, 0, 1), deg_to_rad(90))
		5: return Quaternion(Vector3(0, 1, 0), deg_to_rad(-90))
		6: return Quaternion(Vector3(0, 1, 0), deg_to_rad(180))
		_: return Quaternion()


## 检查骰子值
func check_dice_value():
	if controlled_result != -1:
		closest_index = controlled_result - 1
		has_valid_result = true
		controlled_result = -1
		trigger_skill()
		return
	
	# 向量点积法检测
	var up_direction = Vector3.UP
	var dice_transform = global_transform
	var global_directions = []
	
	var local_directions = [
		Vector3(0, 0, -1),
		Vector3(0, 0, 1),
		Vector3(-1, 0, 0),
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(0, -1, 0)
	]
	
	for local_dir in local_directions:
		global_directions.append(dice_transform.basis * local_dir)
	
	var max_dot = -1
	closest_index = 0
	
	for i in range(global_directions.size()):
		var dot = up_direction.dot(global_directions[i])
		if dot > max_dot:
			max_dot = dot
			closest_index = i
	
	# 设置骰子值
	if dice_value_config.size() > 0:
		dice_value = dice_value_config.get(closest_index, 1)
	else:
		var values = [1, 2, 3, 4, 5, 6]
		dice_value = values[closest_index]
	
	has_valid_result = true
	print("BaseDice 检查结果：", dice_value, " (索引：", closest_index, ")")
	trigger_skill()


## 触发技能
func trigger_skill():
	if skip_skill_trigger:
		return
	
	if skill_system and skill_system.has_method("get_skill_by_dice_value"):
		var skill_id = skill_system.get_skill_by_dice_value(dice_value)
		if skill_id and skill_system.has_method("get_skill") and skill_system.has_method("use_skill"):
			var skill = skill_system.get_skill(skill_id)
			if skill and skill.has("name"):
				print("触发技能：", skill.name)
				skill_system.use_skill(skill_id, self)
				
				if particle_system and particle_system.has_method("spawn_skill_particles"):
					var particles = particle_system.spawn_skill_particles(skill_id, global_position)
					if particles:
						get_parent().add_child(particles)
						particles.emitting = true


func _process(delta):
	if is_rolling:
		if skill_system and skill_system.has_method("update_cooldowns"):
			skill_system.update_cooldowns(delta)
		if particle_system and particle_system.has_method("update"):
			particle_system.update(delta)


func _on_body_entered(body):
	if is_rolling:
		collision_count += 1


func _on_body_exited(_body):
	if is_rolling:
		collision_count = max(0, collision_count - 1)


## 获取骰子类型
func get_dice_type() -> String:
	return DiceType.keys()[dice_type]


## 获取骰子面索引
func get_dice_face_index() -> int:
	return closest_index


## 获取碰撞次数
func get_collision_count() -> int:
	return collision_count


## 获取骰子值
func get_dice_value() -> int:
	return dice_value


## 是否有有效结果
func get_has_valid_result() -> bool:
	return has_valid_result


## 设置控制结果
func set_controlled_result(value: int):
	if value >= 1 and value <= 6:
		controlled_result = value


## 设置骰子面配置
func set_dice_face_config(config: Dictionary, value_config: Dictionary = {}):
	dice_face_config = config
	dice_value_config = value_config
	update_dice_textures()


## 更新骰子贴图
func update_dice_textures():
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		apply_dice_textures(mesh_instance)


## 获取配置 (由子类重写)
func get_config() -> Dictionary:
	return {
		"textures": dice_face_config,
		"values": dice_value_config
	}

extends RigidBody3D

signal dice_stopped  # 骰子完全停止并锁定后发出的信号

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
var stable_check_count: int = 0  # 稳定检查计数
const REQUIRED_STABLE_CHECKS: int = 10  # 需要连续稳定检查次数（每 0.1 秒一次，共 1 秒）
var final_wait_timer: Timer  # 最终等待计时器（余韵时间）
const FINAL_WAIT_TIME: float = 1.5  # 完全稳定后的等待时间（秒）- 余韵
var is_in_final_wait: bool = false  # 是否在余韵等待中

# 角色骰子相关
var character: RefCounted = null  # 关联的角色对象
var health_bar: Node3D = null  # 血条引用

# 受击效果相关
var idle_texture_config: Dictionary = {}  # idle 贴图配置（用于受击后恢复）
var is_hit_animating: bool = false  # 是否正在播放受击动画

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

	# 注意：不在 _ready 中重置 scale，允许外部设置缩放
	# scale = Vector3(1, 1, 1)  # 已移除，避免覆盖外部设置的缩放

	# 创建碰撞形状（使用默认大小，后续可通过 set_dice_scale 调整）
	var collision_shape = $CollisionShape3D
	if collision_shape:
		var cube_shape = BoxShape3D.new()
		cube_shape.size = Vector3(1, 1, 1)
		collision_shape.shape = cube_shape
	
	# 创建计时器
	roll_timer = Timer.new()
	roll_timer.wait_time = 0.1  # 每 0.1 秒检查一次（100ms）
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

	# 创建最终等待计时器（余韵时间）
	final_wait_timer = Timer.new()
	final_wait_timer.wait_time = FINAL_WAIT_TIME
	final_wait_timer.one_shot = true
	final_wait_timer.timeout.connect(_on_final_wait_timeout)
	add_child(final_wait_timer)

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

	# 如果已经有配置，立即应用贴图
	if dice_face_config.size() > 0:
		print("【备用网格】检测到已有配置，立即应用贴图")
		apply_textures_from_manager()

	print("Fallback cube mesh with 6 surfaces created")

func stop_rolling():
	if roll_timer:
		roll_timer.stop()
	is_rolling = false

func roll(force: Vector3, angular_force: Vector3 = Vector3.ZERO):
	# 恢复重力影响
	gravity_scale = 1.0

	is_rolling = true
	is_in_final_wait = false  # 重置余韵状态
	collision_count = 0
	stable_check_count = 0  # 重置稳定计数
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
	# 在余韵等待中，不再检查
	if is_in_final_wait:
		return

	# 检查骰子是否真的停止运动（非常严格的阈值）
	if linear_velocity.length() < 0.03 and angular_velocity.length() < 0.03:
		# 骰子已停止，增加稳定计数
		stable_check_count += 1

		# 需要连续 10 次检查都稳定（共 1 秒）才认为是真的停止
		if stable_check_count >= REQUIRED_STABLE_CHECKS:
			# 完全稳定，启动余韵计时器
			is_in_final_wait = true
			final_wait_timer.start()
		else:
			# 还没达到足够的稳定检查次数，继续等待
			roll_timer.start()
	else:
		# 骰子还在运动，重置稳定计数
		stable_check_count = 0
		roll_timer.start()


## 最终等待超时（余韵时间结束）
func _on_final_wait_timeout():
	is_rolling = false
	is_in_final_wait = false
	check_dice_value()

	# 如果是角色骰子，停止后锁定位置
	if dice_type == "character":
		lock_character_dice()
		# 创建血条（角色骰子完全稳定后）
		create_health_bar()

	# 通知骰子管理器
	var parent = get_parent()
	if parent and parent.has_method("on_dice_stopped"):
		parent.on_dice_stopped()

	# 发出停止信号（供 CharacterEnterManager 等外部系统监听）
	dice_stopped.emit()


func lock_character_dice():
	"""锁定角色骰子，使其不受外力影响"""
	# 禁用重力
	gravity_scale = 0.0

	# 清除所有速度
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# 设置睡眠状态，防止物理引擎继续计算
	sleeping = true

	# 设置碰撞层，避免与其他骰子碰撞
	collision_layer = 0
	collision_mask = 0

	print("【角色骰子】已锁定位置，不受外力影响")


func create_health_bar():
	"""创建 3D 血条（仅在角色骰子上）- 使用 2D 血条"""
	if dice_type != "character":
		print("【骰子】不是角色骰子，跳过血条创建")
		return

	if health_bar:
		print("【骰子】血条已存在，跳过创建")
		return

	# 加载 2D 血条脚本
	var health_bar_script = load("res://scripts/ui/dice_health_bar_2d.gd")
	if not health_bar_script:
		print("【骰子】无法加载 2D 血条脚本")
		return

	# 创建血条节点 - 添加到 sandbox
	var parent = get_parent()
	health_bar = Node3D.new()
	health_bar.name = "HealthBar2D"
	health_bar.set_script(health_bar_script)

	# 直接设置 parent_dice 属性（在添加到场景树之前）
	health_bar.parent_dice = self

	parent.add_child(health_bar)

	print("【骰子】2D 血条已创建，路径：", health_bar.get_path())
	print("【骰子】血条父节点：", parent.name)


func get_character() -> RefCounted:
	"""获取关联的角色对象"""
	return character


func set_character(chara: RefCounted):
	"""设置关联的角色对象"""
	character = chara


func update_hp_text(current_hp: int, max_hp: int):
	"""更新 HP 文字显示（由 BaseCharacter.update_health_bar 调用）"""
	if health_bar and is_instance_valid(health_bar):
		if health_bar.has_method("update_hp_text"):
			health_bar.update_hp_text(current_hp, max_hp)


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
	# 角色骰子不需要预防措施（不依赖特定点数）
	if dice_type == "character":
		return
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

## 设置骰子缩放（同步调整网格和碰撞体）
func set_dice_scale(scale: Vector3):
	"""
	设置骰子的缩放比例
	注意：直接缩放 RigidBody3D 根节点，这样网格和碰撞体会同步缩放
	:param scale: 缩放比例向量
	"""
	# 直接缩放 RigidBody3D 根节点
	self.scale = scale
	print("【骰子】根节点缩放已设置为：", scale)

	# 同步调整碰撞体大小（确保碰撞体形状匹配缩放后的骰子）
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape:
		# BoxShape3D 的 size 是半尺寸，需要乘以 2
		var base_size = Vector3(1, 1, 1)  # 基础碰撞体大小（对应 scale=1 时的尺寸）
		collision_shape.shape.size = base_size * scale
		print("【骰子】碰撞体已同步调整：", collision_shape.shape.size)

	# 也设置网格的缩放（双重保障）
	var mesh = get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.scale = Vector3(1, 1, 1)  # 根节点已缩放，网格保持 1:1
		print("【骰子】网格缩放已重置为 1:1")


func get_dice_value() -> int:
	# 获取骰子点数
	return dice_value

func get_has_valid_result() -> bool:
	# 获取是否有有效结果
	return has_valid_result

func get_is_rolling() -> bool:
	# 获取骰子是否正在滚动（包括余韵等待中）
	return is_rolling or is_in_final_wait

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
	# 保存 idle 贴图配置（用于受击后恢复）
	idle_texture_config = config.duplicate()
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


## 受击效果：抖动 + 切换 hit 贴图
func take_hit_effect():
	"""
	播放受击效果：
	1. 骰子轻微震动一下
	2. 所有骰面切换为 hit 贴图
	3. 持续 0.5 秒后恢复 idle 贴图
	"""
	if is_hit_animating:
		print("【受击效果】正在播放受击动画，跳过")
		return

	is_hit_animating = true
	print("【受击效果】开始播放受击效果")

	# 1. 切换到 hit 贴图
	_apply_hit_textures()

	# 2. 播放轻微震动动画（简单前后移动一下）
	var shake_tween = create_tween()
	var shake_offset = Vector3(0.1, 0.1, 0.1)  # 轻微震动幅度
	var shake_duration = 0.08  # 震动时间（快速）

	# 震出去
	shake_tween.tween_property(self, "position", global_position + shake_offset, shake_duration)
	# 震回来
	shake_tween.tween_property(self, "position", global_position, shake_duration)

	# 3. 0.5 秒后恢复 idle 贴图
	var recover_timer = get_tree().create_timer(0.5)
	recover_timer.timeout.connect(_on_hit_effect_finished)

	print("【受击效果】受击动画播放中...")


## 应用 hit 贴图
func _apply_hit_textures():
	"""将骰子所有面切换为 hit 状态的贴图"""
	if not character or idle_texture_config.size() == 0:
		print("【受击效果】角色或贴图配置为空，跳过 hit 贴图切换")
		return

	# 获取角色的 hit 贴图 ID
	var hero_id = character.hero_id
	var hero_textures = character.hero_textures

	# 查找 hit 状态的索引
	var hit_texture_state = "hit"
	var hit_texture_path = ""

	# 构建 hit 贴图配置
	var hit_config = {}

	# 检查 hero_textures 中是否有 hit 状态
	if hero_textures.has("hit"):
		# hero_textures 是字典格式
		var texture_state = hero_textures["hit"]
		hit_texture_path = "res://textures/hero/hero_" + str(hero_id) + "_" + texture_state + ".png"
	else:
		# hero_textures 是数组格式，按顺序对应 6 个面
		# 默认 hit 贴图使用所有面相同的 hit 状态
		if hero_textures.size() >= 1:
			# 使用第一个贴图状态作为 hit
			# 通常 hero.json 中 hero_texture 是 ["idle", "hit", "attack", ...] 这样的格式
			# 我们需要找到 "hit" 对应的索引
			for i in range(hero_textures.size()):
				if hero_textures[i] == "hit":
					hit_texture_path = "res://textures/hero/hero_" + str(hero_id) + "_hit.png"
					break

			# 如果没找到，尝试直接使用 "hit" 状态
			if hit_texture_path.is_empty():
				hit_texture_path = "res://textures/hero/hero_" + str(hero_id) + "_hit.png"

	# 为所有面设置 hit 贴图
	for i in range(6):
		hit_config[i] = hit_texture_path

	print("【受击效果】应用 hit 贴图：", hit_texture_path)

	# 临时保存当前 config，然后应用 hit 贴图
	var old_config = dice_face_config.duplicate()
	dice_face_config = hit_config
	apply_textures_from_manager()


## 恢复 idle 贴图
func _apply_idle_textures():
	"""将骰子所有面恢复为 idle 状态的贴图"""
	if idle_texture_config.size() == 0:
		print("【受击效果】idle 贴图配置为空，无法恢复")
		return

	print("【受击效果】恢复 idle 贴图")

	# 恢复 idle 贴图配置
	dice_face_config = idle_texture_config.duplicate()
	apply_textures_from_manager()


## 受击效果结束回调
func _on_hit_effect_finished():
	"""受击效果结束，恢复 idle 贴图"""
	print("【受击效果】受击效果结束，恢复 idle 贴图")
	_apply_idle_textures()
	is_hit_animating = false


## 高亮效果相关
var highlight_material: StandardMaterial3D = null  # 高亮材质
var highlight_mesh: MeshInstance3D = null  # 高亮网格


## 添加高亮/描边效果
func add_highlight():
	"""给骰子添加高亮效果（边缘光）"""
	if highlight_mesh:
		print("【高亮效果】高亮已存在，跳过")
		return

	print("【高亮效果】添加高亮")

	# 获取原始网格实例
	var mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance or not mesh_instance.mesh:
		print("【高亮效果】网格实例不存在")
		return

	# 创建高亮网格（复制原始网格）
	highlight_mesh = MeshInstance3D.new()
	highlight_mesh.name = "HighlightMesh"
	highlight_mesh.mesh = mesh_instance.mesh

	# 放大形成边框效果（5% 放大，更明显的描边）
	highlight_mesh.scale = Vector3(1.05, 1.05, 1.05)

	# 创建高亮材质（只渲染背面，形成边缘光效果）
	highlight_material = StandardMaterial3D.new()
	highlight_material.albedo_color = Color(1, 1, 1, 1)  # 白色
	highlight_material.emission_enabled = true
	highlight_material.emission = Color(1, 0.8, 0, 1)  # 橙黄色发光
	highlight_material.emission_energy_multiplier = 3.0

	# 关键：只渲染背面，配合放大形成边缘光
	highlight_material.cull_mode = StandardMaterial3D.CULL_FRONT
	highlight_material.blend_mode = StandardMaterial3D.BLEND_MODE_ADD

	highlight_mesh.material_override = highlight_material

	# 将高亮网格添加为子节点
	add_child(highlight_mesh)

	print("【高亮效果】高亮已添加")


## 移除高亮效果
func remove_highlight():
	"""移除骰子的高亮效果"""
	if not highlight_mesh:
		print("【高亮效果】没有高亮效果")
		return

	print("【高亮效果】移除高亮")

	# 移除并清理高亮网格
	if highlight_mesh and is_instance_valid(highlight_mesh):
		highlight_mesh.queue_free()

	# 清除引用
	highlight_mesh = null
	highlight_material = null

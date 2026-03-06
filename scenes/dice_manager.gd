extends Node3D

@export var dice_count: int = 2  # 默认2个骰子
@export var max_dice_count: int = 6  # 最大6个骰子
@export var dice_scene: PackedScene  # 骰子场景
@export var current_scene: String = "normal"  # 当前场景

var dice_config

func _ready():
	# 加载骰子配置
	dice_config = preload("res://scripts/dice_config.gd").new()
	
	# 加载骰子场景
	if not dice_scene:
		dice_scene = load("res://scenes/dice_6.tscn")
		if not dice_scene:
			print("Error: Failed to load dice scene")
			return
	
	# 初始化骰子池
	initialize_dice_pool()

var dice_instances: Array = []
var is_throwing: bool = false
var rolling_dice_count: int = 0

func initialize_dice_pool():
	# 清理现有骰子
	for dice in dice_instances:
		if dice and is_instance_valid(dice):
			dice.queue_free()
	dice_instances.clear()
	
	# 限制骰子数量
	dice_count = clamp(dice_count, 1, max_dice_count)
	
	# 获取当前场景配置
	var scene_config = dice_config.get_scene_config(current_scene)
	
	# 强制加载正确的骰子场景
	var dice_scene_path = "res://scenes/dice_6.tscn"
	var dice_scene = load(dice_scene_path)
	if not dice_scene:
		print("Error: Failed to load dice scene from ", dice_scene_path)
		return
	
	# 创建骰子实例
	for i in range(dice_count):
		var dice = dice_scene.instantiate()
		if dice:
			print("Dice instance type:", dice.get_class())
			dice.name = "Dice_%d" % i
			add_child(dice)
			dice_instances.append(dice)
			# 初始状态：禁用重力，使骰子悬浮
			if dice is RigidBody3D:
				dice.gravity_scale = 0.0
				dice.linear_velocity = Vector3.ZERO
				dice.angular_velocity = Vector3.ZERO
			else:
				print("Error: Dice is not RigidBody3D, cannot set physics properties")
			dice.visible = true
			
			# 应用当前场景配置
			if dice.has_method("set_dice_face_config"):
				dice.set_dice_face_config(scene_config)
			
			# 设置初始位置，沿着水平方向并排排列
			var spacing = 1.5  # 骰子间距
			var start_x = -((dice_count - 1) * spacing) / 2
			var x_pos = start_x + (i * spacing)
			dice.position = Vector3(x_pos, 6, 4.75)  # 靠近屏幕下方南墙
	
	print("Dice pool initialized with %d dice" % dice_instances.size())

func set_dice_count(count: int):
	# 设置骰子数量
	dice_count = clamp(count, 1, max_dice_count)
	initialize_dice_pool()

func get_dice_count() -> int:
	# 获取当前骰子数量
	return dice_instances.size()

func get_dice(index: int) -> Node3D:
	# 获取指定索引的骰子
	if index >= 0 and index < dice_instances.size():
		return dice_instances[index]
	return null

func reset_all_dice():
	# 重置所有骰子
	for i in range(dice_instances.size()):
		var dice = dice_instances[i]
		if dice and is_instance_valid(dice):
			# 检查是否为 RigidBody3D 类型
			if dice.get_class() == "RigidBody3D":
				dice.linear_velocity = Vector3.ZERO
				dice.angular_velocity = Vector3.ZERO
				dice.gravity_scale = 0.0
			dice.rotation = Vector3()  # 重置旋转角度
			dice.visible = true
			
			# 设置初始位置，沿着水平方向并排排列
			var spacing = 1.5  # 骰子间距
			var start_x = -((dice_instances.size() - 1) * spacing) / 2
			var x_pos = start_x + (i * spacing)
			dice.position = Vector3(x_pos, 6, 4.75)  # 靠近屏幕下方南墙
	
	is_throwing = false
	rolling_dice_count = 0

func prepare_dice_for_throw():
	# 准备骰子投掷
	var base_ratio = 16.0 / 9.0
	var sandbox_width = 24.0
	var sandbox_height = sandbox_width / base_ratio
	
	# 计算骰子初始位置，确保它们有适当间隔
	var spacing = 1.5  # 骰子间距
	var start_x = -((dice_instances.size() - 1) * spacing) / 2
	
	for i in range(dice_instances.size()):
		var dice = dice_instances[i]
		if dice and is_instance_valid(dice):
			# 计算初始位置，确保骰子之间有间隔
			var x_pos = start_x + (i * spacing)
			dice.position = Vector3(x_pos, 7.5, sandbox_height/2 - 2)
			dice.rotation = Vector3()
			# 检查是否为 RigidBody3D 类型
			if dice.get_class() == "RigidBody3D":
				dice.linear_velocity = Vector3.ZERO
				dice.angular_velocity = Vector3.ZERO
				dice.gravity_scale = 0.0
			dice.visible = true

func throw_all_dice(force_multiplier: float = 1.0):
	# 同时投掷所有骰子
	if dice_instances.size() == 0:
		print("Error: No dice to throw")
		return
	
	prepare_dice_for_throw()
	is_throwing = true
	rolling_dice_count = dice_instances.size()
	
	for dice in dice_instances:
		if dice and is_instance_valid(dice):
			# 为每个骰子生成独立的投掷力
			var force = Vector3(
				randf_range(-0.5, 0.5) * force_multiplier,
				randf_range(3, 5) * force_multiplier,
				randf_range(-2.5, -1.25) * force_multiplier
			)
			
			# 为每个骰子生成独立的旋转力
			var angular_force = Vector3(
				randf_range(-7, 7),
				randf_range(-7, 7),
				randf_range(-7, 7)
			)
			
			# 检查骰子是否有 roll 方法
			if dice.has_method("roll"):
				dice.roll(force, angular_force)
			# 对于 RigidBody3D 类型，直接设置物理属性
			elif dice.get_class() == "RigidBody3D":
				dice.gravity_scale = 1.0
				dice.linear_velocity = force
				dice.angular_velocity = angular_force

func throw_all_dice_with_charge(charge_ratio: float):
	# 蓄力投掷所有骰子
	if dice_instances.size() == 0:
		print("Error: No dice to throw")
		return
	
	prepare_dice_for_throw()
	is_throwing = true
	rolling_dice_count = dice_instances.size()
	
	var max_force = 20.0
	var min_force_ratio = 0.3
	var force_magnitude = (min_force_ratio + (charge_ratio * (1.0 - min_force_ratio))) * max_force
	
	for dice in dice_instances:
		if dice and is_instance_valid(dice):
			# 生成朝向屏幕上方的力，角度在-45到45度之间
			var angle = deg_to_rad(randf_range(-45, 45))
			
			# 计算投掷力
			var force = Vector3(
				sin(angle) * 0.25 * force_magnitude,
				(0.3 + (charge_ratio * 0.7)) * force_magnitude * 0.5,
				-0.25 * force_magnitude
			)
			
			# 计算旋转力
			var min_angular_force = 11.2
			var max_angular_force = 31.5
			var angular_force_magnitude = min_angular_force + (charge_ratio * (max_angular_force - min_angular_force))
			
			# 生成随机方向的旋转力
			var x_rot = randf_range(-1.0, 1.0)
			var y_rot = randf_range(-1.0, 1.0)
			var z_rot = randf_range(-1.0, 1.0)
			
			# 确保每个轴都有足够的旋转分量
			if abs(x_rot) < 0.5:
				x_rot = randf_range(0.5, 1.0) * sign(x_rot) if x_rot != 0 else 0.7
			if abs(y_rot) < 0.5:
				y_rot = randf_range(0.5, 1.0) * sign(y_rot) if y_rot != 0 else 0.7
			if abs(z_rot) < 0.5:
				z_rot = randf_range(0.5, 1.0) * sign(z_rot) if z_rot != 0 else 0.7
			
			# 创建旋转力向量并归一化
			var angular_force = Vector3(x_rot, y_rot, z_rot).normalized() * angular_force_magnitude
			
			# 检查骰子是否有 roll 方法
			if dice.has_method("roll"):
				dice.roll(force, angular_force)
			# 对于 RigidBody3D 类型，直接设置物理属性
			elif dice.get_class() == "RigidBody3D":
				dice.gravity_scale = 1.0
				dice.linear_velocity = force
				dice.angular_velocity = angular_force

func on_dice_stopped():
	# 骰子停止时的回调
	rolling_dice_count -= 1
	if rolling_dice_count <= 0:
		is_throwing = false
		print("All dice have stopped rolling")
		# 这里可以添加结果判定逻辑

func get_all_dice_values() -> Array:
	# 获取所有骰子的点数
	var values = []
	for dice in dice_instances:
		if dice and is_instance_valid(dice) and dice.has_method("get_dice_value"):
			values.append(dice.get_dice_value())
	return values

func update(delta: float):
	# 更新所有骰子
	for dice in dice_instances:
		if is_instance_valid(dice):
			# 只在骰子滚动时更新，减少不必要的计算
			if dice.has_method("_process"):
				# 直接访问 is_rolling 属性，GDScript 会处理不存在的情况
				if dice.is_rolling:
					dice._process(delta)

func set_scene_config(scene_name: String):
	# 切换场景配置
	current_scene = scene_name
	# 获取场景配置
	var scene_config = dice_config.get_scene_config(scene_name)
	# 更新所有骰子的贴图配置
	for dice in dice_instances:
		if dice and is_instance_valid(dice) and dice.has_method("set_dice_face_config"):
			dice.set_dice_face_config(scene_config)
	print("Set scene config to: ", scene_name)
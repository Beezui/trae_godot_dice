extends RigidBody3D

@export var attr_type: String = "str"  # str, agi, int
@export var hero_id: int = 1
@export var attr_values: Array = []
@export var attr_textures: Array = []
@export var attr_color: Color = Color(1, 1, 1, 1)
@export var points_color: Color = Color.BLACK  # 属性数值文字颜色

var is_rolling: bool = false
var roll_timer: Timer
var skill_system
var particle_system
var controlled_result: int = -1
var result_control_timer: Timer
var has_valid_result: bool = false
var result_check_timer: Timer
var closest_index: int = 0
var collision_count: int = 0
var skip_skill_trigger: bool = false

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
	linear_damp = 0.1
	angular_damp = 0.03
	
	# 设置物理材质
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.1404
	physics_material.friction = 0.8
	
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
	result_check_timer.wait_time = 0.5
	result_check_timer.timeout.connect(_on_result_check_timeout)
	add_child(result_check_timer)
	
	# 初始化骰子模型
	init_dice_model()
	
	print("Attribute dice initialization complete")
	
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
	# 使用 DiceTextureManager 统一管理属性骰子贴图
	# 构建配置字典（使用新格式：hero.json 格式）
	var config = {
		"hero_id": hero_id,
		"attr_type": attr_type,
		"values": attr_values,
		"textures": attr_textures,
		"points_color": points_color  # 传递文字颜色配置
	}
	
	# 调用 DiceTextureManager 应用贴图
	if DiceTextureManager.get_instance():
		DiceTextureManager.get_instance().apply_textures_to_dice(self, config)
		print("【属性骰子】使用 DiceTextureManager 统一管理贴图，文字颜色：", points_color)
	else:
		# 备用方案：如果 DiceTextureManager 不可用，使用本地方法
		print("【属性骰子】警告：DiceTextureManager 不可用，使用本地方法")
		_apply_dice_textures_local(mesh_instance)


# 备用方法：本地贴图应用（仅在 DiceTextureManager 不可用时使用）
func _apply_dice_textures_local(mesh_instance):
	# 尝试加载静态贴图
	var static_texture = null
	if attr_textures.size() > 0 and attr_textures[0] and not attr_textures[0].is_empty():
		var texture_path = "res://textures/hero/hero_" + attr_textures[0] + ".png"
		print("【本地方法】加载贴图：", texture_path)
		static_texture = load(texture_path)
	
	# 获取骰面尺寸
	var face_size = Vector2i(512, 512)
	if mesh_instance and mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		face_size = Vector2i(int(aabb.size.x), int(aabb.size.y))
	
	# 为每个面创建动态纹理和材质
	var materials = []
	for i in range(6):
		var attr_value = "0"
		if i < attr_values.size():
			attr_value = format_attribute_value(attr_values[i])
		
		# 使用本地方法创建动态纹理
		var dynamic_texture = create_face_texture(i, static_texture, attr_value, face_size)
		
		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		material.metallic = 0.0
		
		if dynamic_texture:
			material.albedo_texture = dynamic_texture
			material.uv1_scale = Vector3(1, 1, 1)
			material.uv1_offset = Vector3(0, 0, 0)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		else:
			material.albedo_color = get_attr_color()
		
		materials.append(material)
	
	# 应用材质到网格
	if mesh_instance and mesh_instance.mesh:
		var surface_count = mesh_instance.mesh.get_surface_count()
		for i in range(min(6, surface_count, materials.size())):
			if i < materials.size():
				mesh_instance.mesh.surface_set_material(i, materials[i])
		mesh_instance.visible = true

func create_face_texture(face_index: int, static_texture: Texture2D, dynamic_text: String, face_size: Vector2i) -> Texture2D:
	# 创建一个 SubViewport 用于生成动态纹理
	var viewport = SubViewport.new()
	viewport.name = "DynamicFaceViewport_%d" % face_index
	
	# 根据 AABB 大小设置 viewport 尺寸，最小 512x512 以保证清晰度
	var viewport_size = Vector2i(max(face_size.x, 512), max(face_size.y, 512))
	viewport.size = viewport_size
	
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE  # 只更新一次
	viewport.transparent_bg = true  # 使用透明背景
	add_child(viewport)  # 将 Viewport 添加到骰子节点下

	# 构建 UI 树，确保填满
	var control = Control.new()
	control.anchors_preset = Control.PRESET_FULL_RECT  # 充满整个 Viewport
	control.size = viewport_size  # 明确设置尺寸
	viewport.add_child(control)

	# 添加 TextureRect 用于显示静态贴图
	if static_texture:
		var texture_rect = TextureRect.new()
		texture_rect.texture = static_texture
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE  # 拉伸以完全覆盖
		texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		texture_rect.size = viewport_size  # 明确设置尺寸
		control.add_child(texture_rect)
		print("Face ", face_index, ": Added texture_rect with size ", viewport_size)

	# 添加 Label 用于显示动态文本
	var label = Label.new()
	label.text = dynamic_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 96)  # 增大字体确保清晰
	label.add_theme_color_override("font_color", Color.BLACK)
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.size = viewport_size  # 明确设置尺寸
	control.add_child(label)
	
	print("Created viewport for face ", face_index, " with size: ", viewport_size, ", text: ", dynamic_text)
	
	# 获取 ViewportTexture
	var viewport_texture = viewport.get_texture()
	
	return viewport_texture

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
	
	# 应用贴图
	apply_dice_textures(mesh_instance)
	
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
		print("\n[计时器] 骰子已停止运动")
		print("  线速度：", linear_velocity.length())
		print("  角速度：", angular_velocity.length())
		is_rolling = false
		check_dice_value()
		# 通知骰子管理器
		var parent = get_parent()
		if parent and parent.has_method("on_dice_stopped"):
			parent.on_dice_stopped()
	else:
		# 骰子还在运动，重新启动计时器
		print("\n[计时器] 骰子仍在运动，重置计时器")
		print("  线速度：", linear_velocity.length())
		print("  角速度：", angular_velocity.length())
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
	print("\n========== 骰子结果检查开始 ==========")
	
	# 如果有控制结果，直接使用控制值
	if controlled_result != -1:
		print("[控制模式] 使用预设结果：", controlled_result)
		closest_index = controlled_result - 1  # 转换为 0-5 的索引
		has_valid_result = true
		print("[控制模式] 最终面索引：", closest_index)
		if closest_index >= 0 and closest_index < attr_values.size():
			print("[控制模式] 对应属性值：", attr_values[closest_index])
		print("========== 骰子结果检查结束 ==========\n")
		# 重置控制状态
		controlled_result = -1
		trigger_skill()
		return
	
	# 直接根据骰子的旋转计算朝上的面
	var up_direction = Vector3.UP
	var dice_transform = global_transform
	var global_directions = []
	
	# 定义骰子六个面的本地方向，与 create_fallback_mesh 函数中的面索引顺序匹配
	var local_directions = [
		Vector3(0, 0, -1),  # 前面 (面索引 0)
		Vector3(0, 0, 1),   # 后面 (面索引 1)
		Vector3(-1, 0, 0),  # 左面 (面索引 2)
		Vector3(1, 0, 0),   # 右面 (面索引 3)
		Vector3(0, 1, 0),   # 顶面 (面索引 4)
		Vector3(0, -1, 0)   # 底面 (面索引 5)
	]
	
	print("\n[检测] 骰子当前位置和旋转:")
	print("  位置：", dice_transform.origin)
	print("  旋转 (四元数): ", dice_transform.basis.get_rotation_quaternion())
	
	# 将每个面的本地方向转换为全局方向
	for i in range(local_directions.size()):
		var global_dir = dice_transform.basis * local_directions[i]
		global_directions.append(global_dir)
		var dot = up_direction.dot(global_dir)
		print("  面 ", i, " (", local_directions[i], ") -> 全局方向：", str(global_dir.x).substr(0, 5) + ", " + str(global_dir.y).substr(0, 5) + ", " + str(global_dir.z).substr(0, 5), ", 与向上点积：", "%.3f" % dot)
	
	# 找到最接近全局向上方向的面
	var max_dot = -1
	closest_index = 0
	
	for i in range(global_directions.size()):
		var dot = up_direction.dot(global_directions[i])
		if dot > max_dot:
			max_dot = dot
			closest_index = i
	
	print("\n[结果] 最接近向上的面：索引 ", closest_index)
	print("  点积值：", "%.3f" % max_dot)
	print("  对应骰子点数：", closest_index + 1)
	
	if closest_index >= 0 and closest_index < attr_values.size():
		print("  对应属性值：", attr_values[closest_index])
		print("  对应贴图：", attr_textures[closest_index] if closest_index < attr_textures.size() else "无")
	else:
		print("  [警告] 索引超出范围！")
	
	has_valid_result = true
	print("\n========== 骰子结果检查结束 ==========\n")
	trigger_skill()

func trigger_skill():
	print("\n=== trigger_skill() 被调用 ===")
	print("skip_skill_trigger = ", skip_skill_trigger)
	
	if skip_skill_trigger:
		print("[跳过] 技能触发被禁用")
		return
	
	print("[成功] 骰子结果已确认")
	print("  最终面索引：", closest_index)
	print("  是否有效结果：", has_valid_result)
	
	if has_valid_result and closest_index >= 0:
		print("  最终属性值：", get_attribute_value())
		print("  属性类型：", attr_type)
		print("  英雄 ID: ", hero_id)
	
	# 属性骰子不直接触发技能，而是提供属性值给技能系统
	# 技能系统会在需要时读取属性骰子的结果
	print("=== trigger_skill() 结束 ===\n")

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

func _on_body_exited(_body):
	if is_rolling:
		collision_count = max(0, collision_count - 1)

func get_dice_type() -> String:
	return "attribute"

func get_attr_type() -> String:
	return attr_type

func get_hero_id() -> int:
	return hero_id

func get_dice_face_index() -> int:
	return closest_index

func get_collision_count() -> int:
	return collision_count

func get_has_valid_result() -> bool:
	return has_valid_result

func get_attribute_value() -> String:
	# 获取当前朝上的面的属性值
	if closest_index >= 0 and closest_index < attr_values.size():
		var raw_value = attr_values[closest_index]
		var formatted = format_attribute_value(raw_value)
		print("[get_attribute_value] 索引:", closest_index, " 原始值:", raw_value, " 格式化后:", formatted)
		return formatted
	print("[get_attribute_value] 索引无效:", closest_index, " 返回默认值：0")
	return "0"

func set_controlled_result(value: int):
	# 设置控制结果
	if value >= 1 and value <= 6:
		controlled_result = value
		print("Set controlled result: ", value)

func update_attributes(hero_attributes: Dictionary, hero_textures: Array):
	# 更新属性值
	match attr_type:
		"str":
			attr_values = _convert_to_int_array(hero_attributes.get("attr_str", [10, 20, 30, 40, 50, 60]))
		"agi":
			attr_values = _convert_to_int_array(hero_attributes.get("attr_agi", [10, 20, 30, 40, 50, 60]))
		"int":
			attr_values = _convert_to_int_array(hero_attributes.get("attr_int", [10, 20, 30, 40, 50, 60]))
		_:
			attr_values = [10, 20, 30, 40, 50, 60]
	
	# 更新贴图
	attr_textures = hero_textures
	
	# 从 attr_dices.json 读取文字颜色配置
	_update_points_color_from_config()
	
	# 更新骰子贴图
	update_dice_textures()
	print("Updated attribute dice: ", attr_type, " for hero ", hero_id)
	print("Attribute values: ", attr_values)
	print("Texture paths: ", attr_textures)
	print("Points color: ", points_color)


func _update_points_color_from_config():
	# 从 attr_dices.json 读取文字颜色配置
	var DiceCSVReaderClass = load("res://scripts/dice_csv_reader.gd")
	var dice_csv_reader = DiceCSVReaderClass.new()
	var attr_dices_config = dice_csv_reader.load_attr_dices()
	
	# 检查配置是否有效（空字典也是有效的，表示没有配置）
	if attr_dices_config.size() > 0:
		var hero_key = str(hero_id)
		if attr_dices_config.has(hero_key):
			var hero_config = attr_dices_config[hero_key]
			
			# 根据 attr_type 获取对应的配置
			var attr_config = null
			match attr_type:
				"str":
					attr_config = hero_config.get("power", null)
				"agi":
					attr_config = hero_config.get("agility", null)
				"int":
					attr_config = hero_config.get("intelligence", null)
			
			if attr_config and attr_config.has("points_color"):
				var color_str = attr_config["points_color"]
				if color_str is String:
					points_color = Color(color_str)
				else:
					points_color = color_str
				print("【文字颜色】从配置读取：", attr_type, " = ", points_color)
			else:
				# 默认颜色
				points_color = Color.BLACK
				print("【文字颜色】配置中未找到 points_color，使用默认黑色")
		else:
			# 默认颜色
			points_color = Color.BLACK
			print("【文字颜色】未找到英雄 ", hero_id, " 的配置，使用默认黑色")
	else:
		# 默认颜色
		points_color = Color.BLACK
		print("【文字颜色】未找到 attr_dices.json 配置，使用默认黑色")

func _convert_to_int_array(array: Array) -> Array:
	# 将数组中的元素转换为整数
	var result = []
	for item in array:
		if typeof(item) == TYPE_STRING:
			result.append(int(item))
		else:
			result.append(item)
	return result

func update_dice_textures():
	# 清理旧的 SubViewport
	_cleanup_old_viewports()
	
	print("\n[更新纹理] 开始更新骰子纹理")
	print("  属性类型：", attr_type)
	print("  属性值：", attr_values)
	print("  贴图路径：", attr_textures)
	
	# 动态更新骰子贴图
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		apply_dice_textures(mesh_instance)
		print("  [成功] 更新骰子纹理")
	else:
		print("  [错误] 未找到 MeshInstance3D")
	print("[更新纹理] 结束\n")

func _cleanup_old_viewports():
	# 清理旧的 SubViewport，避免内存泄漏
	for child in get_children():
		if child is SubViewport and child.name.begins_with("DynamicFaceViewport_"):
			child.queue_free()
	print("Cleaned up old viewports")

func get_attr_color() -> Color:
	# 根据属性类型返回对应的颜色
	match attr_type:
		"str":
			return Color(1, 0.2, 0.2, 1)  # 力量 - 红色
		"agi":
			return Color(0.2, 0.8, 0.2, 1)  # 敏捷 - 绿色
		"int":
			return Color(0.2, 0.2, 1, 1)  # 智力 - 蓝色
		_:
			return Color(0.5, 0.5, 0.5, 1)  # 默认 - 灰色

func format_attribute_value(value: int) -> String:
	# 格式化属性值，支持缩写
	if value >= 1000:
		var k_value = value / 1000.0
		if k_value.is_integer():
			return str(int(k_value)) + "k"
		else:
			return str(round(k_value * 10) / 10) + "k"
	return str(value)

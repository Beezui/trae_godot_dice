extends Node3D
## 骰子 3D 血条
## 显示在角色骰子上，贴在朝上面与面向屏幕面的交界边处

# 血条节点引用
var background_mesh: MeshInstance3D
var fill_mesh: MeshInstance3D
var hp_text: Label3D

# 当前血量百分比（0.0 - 1.0）
var current_hp_percent: float = 1.0
# 目标血量百分比（用于平滑过渡）
var target_hp_percent: float = 1.0
# 平滑过渡速度
var lerp_speed: float = 5.0

# 血条尺寸配置
var bar_length: float = 1.2  # 血条长度（相对于骰子边长的比例）
var bar_height: float = 0.15  # 血条高度
var bar_thickness: float = 0.08  # 血条厚度
var offset_from_edge: float = 0.05  # 距离边的偏移

# 颜色配置
var color_full: Color = Color(0.2, 0.8, 0.2)  # 绿色（100% HP）
var color_half: Color = Color(0.8, 0.8, 0.2)  # 黄色（50% HP）
var color_low: Color = Color(0.8, 0.2, 0.2)   # 红色（0% HP）

# 父骰子引用
var parent_dice: RigidBody3D


func _ready():
	# 获取父骰子引用（血条作为骰子子节点）
	parent_dice = get_parent() as RigidBody3D
	print("【血条】_ready() 执行，parent_dice=", parent_dice)

	if parent_dice:
		print("【血条】父骰子类型：", parent_dice.get_class())
		print("【血条】父骰子全局位置：", parent_dice.global_position)
		print("【血条】父骰子缩放：", parent_dice.scale)
		print("【血条】父骰子旋转：", parent_dice.rotation_degrees)

		# 创建血条组件
		_create_health_bar()

		# 启动平滑更新
		set_process(true)
	else:
		print("【血条】错误：无法获取父骰子引用")


func _create_health_bar():
	"""创建血条 3D 模型"""

	print("【血条】开始创建血条...")

	# 获取父骰子的缩放比例（如果有）
	var dice_scale = Vector3.ONE
	if parent_dice:
		dice_scale = parent_dice.scale
		print("【血条】父骰子缩放：", dice_scale)

	# 1. 创建背景网格（深色框）
	background_mesh = MeshInstance3D.new()
	background_mesh.name = "HPBarBackground"
	var bg_mesh = BoxMesh.new()
	# 根据骰子缩放调整血条尺寸
	bg_mesh.size = Vector3(bar_length * dice_scale.x, bar_height * dice_scale.y, bar_thickness * dice_scale.z)
	background_mesh.mesh = bg_mesh
	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.2, 0.2, 0.2, 0.9)  # 深灰色半透明背景
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	background_mesh.material_override = bg_material
	add_child(background_mesh)
	print("【血条】背景网格已创建，尺寸：", bg_mesh.size)

	# 2. 创建填充网格（彩色血条）
	fill_mesh = MeshInstance3D.new()
	fill_mesh.name = "HPBarFill"
	var fill_mesh_resource = BoxMesh.new()
	fill_mesh_resource.size = Vector3((bar_length - 0.02) * dice_scale.x, (bar_height - 0.02) * dice_scale.y, (bar_thickness + 0.01) * dice_scale.z)
	fill_mesh.mesh = fill_mesh_resource
	var fill_material = StandardMaterial3D.new()
	fill_material.albedo_color = color_full
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 使用无光照材质，确保颜色始终可见
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mesh.material_override = fill_material
	add_child(fill_mesh)
	print("【血条】填充网格已创建，尺寸：", fill_mesh_resource.size)

	# 3. 创建 3D 文字
	hp_text = Label3D.new()
	hp_text.name = "HPText"
	hp_text.text = "100/100"
	hp_text.font_size = 32  # 调整字体大小与血条比例协调
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 启用 Billboard 模式，使文字始终面向摄像机
	hp_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# 设置文字轮廓，增强可读性（Godot 4.x Label3D 只有 outline_size）
	hp_text.outline_size = 2
	hp_text.modulate = Color.WHITE  # 使用 modulate 设置颜色
	# 文字不需要额外缩放，使用默认大小即可
	add_child(hp_text)
	print("【血条】3D 文字已创建")

	# 设置初始位置
	_update_bar_position()
	_update_bar_display(1.0)

	# 设置血条旋转：使血条面向屏幕（绕 Y 轴旋转 180 度，让血条朝向摄像机）
	# 因为骰子 Z 轴锁定为 0，血条只需要绕 Y 轴旋转
	rotation.y = PI  # 旋转 180 度，面向屏幕

	print("【血条】血条创建完成，父节点：", get_parent().name)
	print("【血条】血条位置：", global_position)
	print("【血条】血条旋转：", rotation_degrees)
	print("【血条】子节点数：", get_child_count())


func _process(delta):
	# 平滑过渡当前血量到目标血量
	if abs(current_hp_percent - target_hp_percent) > 0.001:
		current_hp_percent = lerp(current_hp_percent, target_hp_percent, lerp_speed * delta)
		_update_bar_display(current_hp_percent)


## 更新血条位置（贴在边上）
func _update_bar_position():
	"""根据骰子状态更新血条位置 - 使用局部坐标"""
	if not parent_dice:
		print("【血条】父骰子为空，跳过位置更新")
		return

	# 获取父骰子的缩放比例（角色骰子通常缩放到 1.5 倍）
	var dice_scale = parent_dice.scale
	print("【血条】父骰子缩放：", dice_scale)

	# 计算血条基础位置（在骰子顶部前方的交界边处）
	# 骰子基础边长为 1，缩放后为 dice_scale
	# 顶部 y = 0.5 * dice_scale.y（骰子中心到顶面的距离）
	# 前方 z = -0.5 * dice_scale.z（骰子中心到前面的距离）
	var base_half_y = 0.5 * dice_scale.y
	var base_half_z = 0.5 * dice_scale.z

	var bar_x = 0  # x 轴居中
	var bar_y = base_half_y + offset_from_edge  # 顶面上方一点，避免 z-fighting
	var bar_z = -base_half_z - offset_from_edge  # 前面前方一点，让血条突出于骰子表面

	background_mesh.position = Vector3(bar_x, bar_y, bar_z)
	fill_mesh.position = Vector3(bar_x, bar_y, bar_z)

	# 文字位置在血条上方一点
	hp_text.position = Vector3(bar_x, bar_y + bar_height + 0.02, bar_z)

	# 旋转文字使其面向上方（绕 X 轴旋转 -90 度，让文字朝上显示）
	hp_text.rotation = Vector3(-PI/2, 0, 0)

	print("【血条】血条位置已设置：background=", background_mesh.position, ", fill=", fill_mesh.position, ", text=", hp_text.position)
	print("【血条】血条全局位置：", background_mesh.global_position)

	# 调试：确保网格可见
	background_mesh.visible = true
	fill_mesh.visible = true
	hp_text.visible = true
	print("【血条】网格可见性：background=", background_mesh.visible, ", fill=", fill_mesh.visible, ", text=", hp_text.visible)


## 更新血条显示
func _update_bar_display(hp_percent: float):
	"""更新血条填充和文字"""
	hp_percent = clamp(hp_percent, 0.0, 1.0)

	# 1. 更新填充宽度
	var fill_width = (bar_length - 0.02) * hp_percent
	var fill_size = fill_mesh.mesh.size
	fill_mesh.mesh.size = Vector3(fill_width, fill_size.y, fill_size.z)

	# 填充条左对齐（从左边开始减少）
	var bar_x = 0
	var fill_x = -(bar_length - 0.02) / 2 + fill_width / 2
	fill_mesh.position.x = fill_x

	# 2. 更新颜色（根据血量百分比动态变化）
	var new_color = _get_hp_color(hp_percent)
	fill_mesh.material_override.albedo_color = new_color

	# 3. 更新文字
	if parent_dice and parent_dice.has_method("get_character"):
		var character = parent_dice.get_character()
		if character:
			hp_text.text = "%d/%d" % [character.current_hp, character.attr_hp]
		else:
			hp_text.text = "%d%%" % int(hp_percent * 100)
	else:
		hp_text.text = "%d%%" % int(hp_percent * 100)


## 根据血量百分比获取颜色
func _get_hp_color(hp_percent: float) -> Color:
	"""根据血量百分比返回渐变颜色"""
	if hp_percent >= 0.5:
		# 50%-100%: 绿色 → 黄色
		var t = (hp_percent - 0.5) * 2.0  # 归一化到 0-1
		return color_half.lerp(color_full, t)
	else:
		# 0%-50%: 黄色 → 红色
		var t = hp_percent * 2.0  # 归一化到 0-1
		return color_low.lerp(color_half, t)


## 设置当前血量百分比
func set_hp_percent(hp_percent: float):
	"""设置目标血量百分比，会平滑过渡"""
	target_hp_percent = clamp(hp_percent, 0.0, 1.0)


## 立即设置血量（无动画）
func set_hp_percent_instant(hp_percent: float):
	"""立即设置血量百分比，无平滑过渡"""
	current_hp_percent = clamp(hp_percent, 0.0, 1.0)
	target_hp_percent = current_hp_percent
	_update_bar_display(current_hp_percent)


## 更新最大 HP 显示
func update_hp_text(current_hp: int, max_hp: int):
	"""更新 HP 文字显示"""
	hp_text.text = "%d/%d" % [current_hp, max_hp]
	var hp_percent = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	set_hp_percent(hp_percent)

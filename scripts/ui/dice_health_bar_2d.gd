extends Node3D
## 2D 直线血条
## 始终平行于屏幕，固定在骰子上方

# 血条配置
var bar_length: float = 0.7  # 血条长度（世界单位）
var bar_height: float = 0.5  # 血条高度
var offset_y: float = 1.2  # 血条在骰子上方的高度

# 当前血量百分比（0.0 - 1.0）
var current_hp_percent: float = 1.0
# 目标血量百分比（用于平滑过渡）
var target_hp_percent: float = 1.0
# 平滑过渡速度
var lerp_speed: float = 5.0

# 颜色配置
var color_full: Color = Color(0.2, 0.8, 0.2)  # 绿色（100% HP）
var color_half: Color = Color(0.8, 0.8, 0.2)  # 黄色（50% HP）
var color_low: Color = Color(0.8, 0.2, 0.2)   # 红色（0% HP）

# 节点引用
var viewport: SubViewport
var health_bar_2d: Control
var sprite_3d: Sprite3D
var hp_label: Label

# 父骰子引用
var parent_dice: RigidBody3D

# 调试标记
var _position_logged: bool = false


func set_parent_dice(dice: RigidBody3D):
	"""设置父骰子引用"""
	self.parent_dice = dice


func _ready():
	print("【2D 血条】_ready() 执行，parent_dice=", parent_dice)

	if not parent_dice:
		print("【2D 血条】错误：无法获取父骰子引用")
		return

	# 创建 2D 血条
	_create_2d_health_bar()

	# 启动更新
	set_process(true)


func _create_2d_health_bar():
	"""创建 2D 血条（使用 SubViewport + Sprite3D）"""
	print("【2D 血条】开始创建...")

	# 1. 创建 SubViewport（用于 2D 渲染）
	viewport = SubViewport.new()
	viewport.name = "HealthBarViewport"
	viewport.size = Vector2i(180, 16)  # 长度 +30%，宽度 -60%
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)

	# 2. 创建 2D 血条控件
	health_bar_2d = Control.new()
	health_bar_2d.name = "HealthBar2D"
	health_bar_2d.size = viewport.size
	health_bar_2d.position = Vector2.ZERO
	health_bar_2d.draw.connect(_on_health_bar_2d_draw)
	viewport.add_child(health_bar_2d)

	# 3. 创建 HP 文字标签（放在血条中间）
	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "100/100"
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.size = Vector2(viewport.size.x, 16)  # 与 viewport 同高
	hp_label.position = Vector2(0, -2)  # 向上调整约 10%
	hp_label.add_theme_font_size_override("font_size", 14)  # 字体调大两个字号
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	health_bar_2d.add_child(hp_label)

	# 4. 创建 Sprite3D 显示 viewport 内容
	sprite_3d = Sprite3D.new()
	sprite_3d.name = "HealthBarSprite3D"
	sprite_3d.pixel_size = 0.012  # 微调 pixel_size
	sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # 始终面向摄像机
	sprite_3d.visible = true
	add_child(sprite_3d)

	# 5. 延迟设置 texture（等待 viewport 渲染完成）
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.timeout.connect(_on_texture_delay_timer_timeout)
	add_child(timer)
	timer.start()

	print("【2D 血条】创建完成")


func _on_texture_delay_timer_timeout():
	"""延迟设置 Sprite3D 的 texture"""
	if viewport and sprite_3d:
		sprite_3d.texture = viewport.get_texture()


func _process(delta):
	if not parent_dice:
		return

	# 血条位置：骰子正上方固定高度
	var dice_pos = parent_dice.global_position
	var dice_scale = parent_dice.scale.x

	global_position = Vector3(dice_pos.x, dice_pos.y + dice_scale * 0.5 + offset_y, dice_pos.z)

	# 平滑过渡血量
	if abs(current_hp_percent - target_hp_percent) > 0.001:
		current_hp_percent = lerp(current_hp_percent, target_hp_percent, lerp_speed * delta)
		_update_bar_display(current_hp_percent)

	# 打印调试信息
	if not _position_logged:
		print("【2D 血条】位置：global=", global_position)
		print("【2D 血条】父骰子位置：", dice_pos)
		_position_logged = true


func _update_bar_display(hp_percent: float):
	"""更新血条显示"""
	hp_percent = clamp(hp_percent, 0.0, 1.0)

	# 更新文字
	if parent_dice and parent_dice.has_method("get_character"):
		var character = parent_dice.get_character()
		if character:
			hp_label.text = "%d/%d" % [character.current_hp, character.attr_hp]
		else:
			hp_label.text = "%d%%" % int(hp_percent * 100)
	else:
		hp_label.text = "%d%%" % int(hp_percent * 100)

	# 触发重绘
	if health_bar_2d:
		health_bar_2d.queue_redraw()


func _on_health_bar_2d_draw():
	"""绘制 2D 血条"""
	if not health_bar_2d:
		return

	var bar_color = _get_hp_color(current_hp_percent)
	var bg_color = Color(0.2, 0.2, 0.2, 0.9)

	# 绘制背景（占满 viewport）
	var bg_rect = Rect2(0, 0, viewport.size.x, viewport.size.y)
	health_bar_2d.draw_rect(bg_rect, bg_color, true)

	# 绘制血量填充
	var fill_width = viewport.size.x * current_hp_percent
	var fill_rect = Rect2(0, 0, fill_width, viewport.size.y)
	health_bar_2d.draw_rect(fill_rect, bar_color, true)


func _get_hp_color(hp_percent: float) -> Color:
	"""根据血量百分比返回渐变颜色"""
	if hp_percent >= 0.5:
		var t = (hp_percent - 0.5) * 2.0
		return color_half.lerp(color_full, t)
	else:
		var t = hp_percent * 2.0
		return color_low.lerp(color_half, t)


func set_hp_percent(hp_percent: float):
	"""设置目标血量百分比"""
	target_hp_percent = clamp(hp_percent, 0.0, 1.0)


func update_hp_text(current_hp: int, max_hp: int):
	"""更新 HP 文字显示"""
	hp_label.text = "%d/%d" % [current_hp, max_hp]
	var hp_percent = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	set_hp_percent(hp_percent)

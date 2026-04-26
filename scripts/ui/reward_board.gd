extends Node3D
## 奖励3D地面面板
## 文字渐变效果：每个字符独立应用暖色渐变（金→橙→粉）
## UI风格：温暖喜悦主题，金色光芒 + 暖色渐变 + 收获感
##
## 架构参照 adventure_board.gd（SubViewport + QuadMesh 3D 地面）
## 关键区别：标题使用逐字渐变色，整体配色温暖明亮

var sub_viewport: SubViewport = null
var mesh_instance: MeshInstance3D = null
var event_data: Dictionary = {}
var results: Array = []

# 暖色渐变配色（金→橙→珊瑚粉）
var gradient_colors: Array = [
	Color(1.0, 0.84, 0.0),    # 金色 #FFD700
	Color(1.0, 0.55, 0.0),    # 橙色 #FF8C00
	Color(1.0, 0.3, 0.3),     # 珊瑚粉 #FF4D4D
]


func _ready():
	if not sub_viewport and not event_data.is_empty():
		_create_viewport()
		_create_ground_plane()
		visible = true


func show_board(ev_data: Dictionary, res_list: Array):
	event_data = ev_data
	results = res_list

	if not sub_viewport:
		_create_viewport()
		_create_ground_plane()
		visible = true

	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 0.3, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 0.3, 0.5).set_ease(Tween.EASE_IN)
	print("【奖励3D面板】已显示")


## 创建单层 Label（theme override 实现描边效果）
func _create_label(text: String, font_size: int, font_color: Color, outline_size: int, is_center: bool = true) -> Label:
	var label = Label.new()
	label.text = text
	if is_center:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", outline_size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	return label


## 创建逐字渐变的标题 Label（参照 discount_dice 的渐变实现）
func _create_gradient_title(text: String, font_size: int, outline_size: int) -> Control:
	var font = ThemeDB.fallback_font
	var text_length = text.length()

	# 测量每个字符宽度和总高度
	var char_widths: Array[float] = []
	var total_width = 0.0
	for i in range(text_length):
		var char_w = font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		char_widths.append(char_w)
		total_width += char_w

	var text_height = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y

	# 创建一个容器用于定位（设置 custom_minimum_size 让 VBox 能正确计算布局）
	var container = Control.new()
	container.name = "GradientTitle"
	container.custom_minimum_size = Vector2(0, text_height)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 水平居中起始位置
	var start_x = (2560 * 0.88 - total_width) / 2.0

	var current_x = start_x

	for i in range(text_length):
		var char: String = text[i]
		var t = 0.0 if text_length <= 1 else float(i) / float(text_length - 1)
		var color_index = t * (gradient_colors.size() - 1)
		var ci = int(color_index)
		var cf = color_index - ci
		var ch_color = gradient_colors[ci].lerp(gradient_colors[min(ci + 1, gradient_colors.size() - 1)], cf)

		var main_label = Label.new()
		main_label.text = char
		main_label.add_theme_font_size_override("font_size", font_size)
		main_label.add_theme_color_override("font_color", ch_color)
		main_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		main_label.add_theme_constant_override("outline_size", outline_size)
		main_label.anchors_preset = Control.PRESET_TOP_LEFT
		main_label.position = Vector2(current_x, 0)
		main_label.size = Vector2(char_widths[i], text_height)
		container.add_child(main_label)

		current_x += char_widths[i]

	return container


## 创建 SubViewport（温暖喜悦主题）
func _create_viewport():
	sub_viewport = SubViewport.new()
	sub_viewport.name = "RewardViewport"
	sub_viewport.size = Vector2i(2560, 4096)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.transparent_bg = true
	add_child(sub_viewport)

	var ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.anchors_preset = Control.PRESET_FULL_RECT
	ui_root.size = sub_viewport.size
	sub_viewport.add_child(ui_root)

	# ===== 内容容器（同时作为深色背景面板） =====
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.anchors_preset = Control.PRESET_FULL_RECT
	main_container.anchor_left = 0.06
	main_container.anchor_top = 0.04
	main_container.anchor_right = 0.94
	main_container.anchor_bottom = 0.96
	main_container.add_theme_constant_override("separation", 24)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	bg_style.corner_radius_top_left = 24
	bg_style.corner_radius_top_right = 24
	bg_style.corner_radius_bottom_left = 24
	bg_style.corner_radius_bottom_right = 24
	bg_style.border_width_top = 3
	bg_style.border_width_bottom = 3
	bg_style.border_width_left = 3
	bg_style.border_width_right = 3
	bg_style.border_color = Color(1.0, 0.7, 0.2, 0.5)
	main_container.add_theme_stylebox_override("panel", bg_style)
	ui_root.add_child(main_container)

	# ===== 标题（暖色渐变：逐字独立色） =====
	var title_text = event_data.get("name", "未知奖励")
	var title_container = _create_gradient_title(title_text, 240, 10)
	main_container.add_child(title_container)

	# ===== 分隔线 =====
	var sep1 = ColorRect.new()
	sep1.color = Color(1.0, 0.6, 0.1, 0.5)
	sep1.custom_minimum_size = Vector2(0, 6)
	sep1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(sep1)

	# ===== 描述 =====
	var desc_text = event_data.get("des", "")
	var desc_label = _create_label(desc_text, 132, Color(0.9, 0.82, 0.65), 4, false)
	main_container.add_child(desc_label)

	# ===== 分隔线 =====
	var sep2 = ColorRect.new()
	sep2.color = Color(1.0, 0.6, 0.1, 0.5)
	sep2.custom_minimum_size = Vector2(0, 6)
	sep2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(sep2)

	# ===== 选项列表 =====
	var options_container = VBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	options_container.add_theme_constant_override("separation", 16)
	main_container.add_child(options_container)

	for i in range(results.size()):
		var result = results[i]
		var des = result.get("des", "")
		var params = result.get("params", {})
		for key in params:
			des = des.replace("【" + key + "】", str(params[key]))

		# 选项卡片（VBoxContainer 做背景 + content_margin 做内边距）
		var card = VBoxContainer.new()
		card.name = "OptionCard_%d" % (i + 1)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.14, 0.1, 0.07, 0.85)
		card_style.corner_radius_top_left = 16
		card_style.corner_radius_top_right = 16
		card_style.corner_radius_bottom_left = 16
		card_style.corner_radius_bottom_right = 16
		card_style.border_width_left = 6
		card_style.border_width_right = 2
		card_style.border_width_top = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color(1.0, 0.65, 0.15, 0.7)
		card_style.content_margin_left = 28
		card_style.content_margin_right = 28
		card_style.content_margin_top = 24
		card_style.content_margin_bottom = 24
		card.add_theme_stylebox_override("panel", card_style)
		options_container.add_child(card)

		# 选项行（HBoxContainer + 序号 + 描述）
		var option_row = HBoxContainer.new()
		option_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		option_row.add_theme_constant_override("separation", 24)
		card.add_child(option_row)

		# 序号（暖金渐变：逐字独立色）
		var num_container = _create_gradient_number(str(i + 1), 144, 6)
		option_row.add_child(num_container)

		# 选项描述
		var opt_label = _create_label(des, 108, Color(0.9, 0.82, 0.65), 4, false)
		option_row.add_child(opt_label)


## 创建逐字渐变的序号（参照 discount_dice 渐变实现）
func _create_gradient_number(text: String, font_size: int, outline_size: int) -> Control:
	var font = ThemeDB.fallback_font
	var text_length = text.length()
	var text_height = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y

	# 计算总宽度
	var total_width = 0.0
	for i in range(text_length):
		total_width += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var container = Control.new()
	container.name = "GradientNumber"
	container.custom_minimum_size = Vector2(total_width, text_height)
	container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	container.size_flags_vertical = Control.SIZE_FILL

	var current_x = 0.0

	for i in range(text_length):
		var char: String = text[i]
		var t = 0.0 if text_length <= 1 else float(i) / float(text_length - 1)
		var color_index = t * (gradient_colors.size() - 1)
		var ci = int(color_index)
		var cf = color_index - ci
		var ch_color = gradient_colors[ci].lerp(gradient_colors[min(ci + 1, gradient_colors.size() - 1)], cf)

		var label = Label.new()
		label.text = char
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", ch_color)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", outline_size)
		label.anchors_preset = Control.PRESET_TOP_LEFT
		label.position = Vector2(current_x, 0)
		label.size = Vector2(font.get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, text_height)
		container.add_child(label)

		current_x += font.get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	return container


func _create_ground_plane():
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "BoardMesh"
	mesh_instance.position = Vector3(0, 0.2, 4.0)
	mesh_instance.rotation_degrees = Vector3(-90, 0, 0)

	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(10.0, 16.0)
	mesh_instance.mesh = quad_mesh

	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = sub_viewport.get_texture()
	material.cull_mode = StandardMaterial3D.CULL_DISABLED

	mesh_instance.material_override = material
	add_child(mesh_instance)


func hide_board():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.9, 0.9, 0.9), 0.3)
	await tween.finished
	queue_free()
	print("【奖励3D面板】已隐藏")

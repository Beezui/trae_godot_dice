extends Node3D
## 奇遇3D地面面板
## 文字描边效果：LabelSettings (font_color + outline_color + outline_size)

var sub_viewport: SubViewport = null
var mesh_instance: MeshInstance3D = null
var event_data: Dictionary = {}
var results: Array = []


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
	print("【奇遇3D面板】已显示")


## 创建单层 Label（直接使用 theme override 实现描边效果）
func _create_label(text: String, font_size: int, font_color: Color, is_center: bool = true) -> Label:
	var label = Label.new()
	label.text = text
	if is_center:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	return label


## 创建 SubViewport
func _create_viewport():
	sub_viewport = SubViewport.new()
	sub_viewport.name = "AdventureViewport"
	sub_viewport.size = Vector2i(2560, 4096)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.transparent_bg = true
	add_child(sub_viewport)

	var ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.anchors_preset = Control.PRESET_FULL_RECT
	ui_root.size = sub_viewport.size
	sub_viewport.add_child(ui_root)

	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.anchors_preset = Control.PRESET_FULL_RECT
	main_container.anchor_left = 0.05
	main_container.anchor_top = 0.04
	main_container.anchor_right = 0.95
	main_container.anchor_bottom = 0.96
	main_container.add_theme_constant_override("separation", 20)
	ui_root.add_child(main_container)

	# ===== 标题 =====
	var title_text = event_data.get("name", "未知奇遇")
	var title_box = _create_label(title_text, 240, Color(0.894, 0.788, 0.702))
	main_container.add_child(title_box)

	var sep1 = ColorRect.new()
	sep1.color = Color(0.706, 0.18, 0.18, 0.6)
	sep1.custom_minimum_size = Vector2(0, 8)
	sep1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(sep1)

	# ===== 描述 =====
	var desc_text = event_data.get("des", "")
	var desc_box = _create_label(desc_text, 132, Color(0.773, 0.753, 0.702), false)
	main_container.add_child(desc_box)

	var sep2 = ColorRect.new()
	sep2.color = Color(0.706, 0.18, 0.18, 0.6)
	sep2.custom_minimum_size = Vector2(0, 8)
	sep2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(sep2)

	# ===== 选项列表 =====
	var options_container = VBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_container.add_theme_constant_override("separation", 30)
	main_container.add_child(options_container)

	for i in range(results.size()):
		var result = results[i]
		var des = result.get("des", "")
		var params = result.get("params", {})
		for key in params:
			des = des.replace("【" + key + "】", str(params[key]))

		# 选项行（HBoxContainer + 深色背景）
		var option_row = HBoxContainer.new()
		option_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		option_row.add_theme_constant_override("separation", 24)
		options_container.add_child(option_row)

		# 序号
		var num_label = Label.new()
		num_label.text = str(i + 1)
		num_label.add_theme_font_size_override("font_size", 144)
		num_label.add_theme_color_override("font_color", Color(0.612, 0.42, 0.243))
		num_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		num_label.add_theme_constant_override("outline_size", 4)
		num_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		num_label.size_flags_vertical = Control.SIZE_FILL
		num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		option_row.add_child(num_label)

		# 选项描述
		var opt_box = _create_label(des, 108, Color(0.773, 0.753, 0.702), false)
		opt_box.size_flags_vertical = Control.SIZE_FILL
		option_row.add_child(opt_box)

	var bottom_sep = ColorRect.new()
	bottom_sep.color = Color(0.706, 0.18, 0.18, 0.6)
	bottom_sep.custom_minimum_size = Vector2(0, 8)
	bottom_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(bottom_sep)


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
	print("【奇遇3D面板】已隐藏")

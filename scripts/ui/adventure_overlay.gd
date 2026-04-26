extends Control
## 奇遇 UI 覆盖层
## 显示奇遇名称、描述、选项列表

@onready var adventure_name_label: Label = null
@onready var adventure_desc_label: Label = null
@onready var options_container: VBoxContainer = null
@onready var fade_background: ColorRect = null

var option_buttons: Array = []


func _ready():
	setup_ui()


## 设置 UI 结构
func setup_ui():
	# 设置覆盖层为全屏
	anchor_right = 1.0
	anchor_bottom = 1.0

	# 创建淡入背景（初始不可见）
	fade_background = ColorRect.new()
	fade_background.name = "FadeBackground"
	fade_background.color = Color(0, 0, 0, 0)
	fade_background.anchor_right = 1.0
	fade_background.anchor_bottom = 1.0
	fade_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade_background)

	# 创建主内容面板
	var panel = Panel.new()
	panel.name = "ContentPanel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0

	# 深色半透明背景
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.92)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", panel_style)

	# 创建布局容器
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 上边距
	var top_margin = Control.new()
	top_margin.custom_minimum_size = Vector2(0, 60)
	main_vbox.add_child(top_margin)

	# 奇遇名称
	adventure_name_label = Label.new()
	adventure_name_label.name = "AdventureName"
	adventure_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adventure_name_label.add_theme_font_size_override("font_size", 48)
	adventure_name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	adventure_name_label.add_theme_color_override("font_outline_color", Color(0.2, 0.2, 0.3, 0.8))
	adventure_name_label.add_theme_constant_override("outline_size", 3)
	adventure_name_label.size_flags_horizontal = Control.SIZE_FILL
	main_vbox.add_child(adventure_name_label)

	# 名称下方间距
	var name_spacing = Control.new()
	name_spacing.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(name_spacing)

	# 分隔线
	var separator = ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 2)
	separator.color = Color(0.4, 0.3, 0.2, 0.6)
	separator.anchor_left = 0.15
	separator.anchor_right = 0.85
	main_vbox.add_child(separator)

	# 分隔线下间距
	var sep_spacing = Control.new()
	sep_spacing.custom_minimum_size = Vector2(0, 15)
	main_vbox.add_child(sep_spacing)

	# 奇遇描述
	adventure_desc_label = Label.new()
	adventure_desc_label.name = "AdventureDesc"
	adventure_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adventure_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adventure_desc_label.add_theme_font_size_override("font_size", 28)
	adventure_desc_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.75))
	adventure_desc_label.size_flags_horizontal = Control.SIZE_FILL
	adventure_desc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(adventure_desc_label)

	# 描述下方间距
	var desc_spacing = Control.new()
	desc_spacing.custom_minimum_size = Vector2(0, 30)
	main_vbox.add_child(desc_spacing)

	# 分隔线
	var separator2 = ColorRect.new()
	separator2.custom_minimum_size = Vector2(0, 2)
	separator2.color = Color(0.4, 0.3, 0.2, 0.6)
	separator2.anchor_left = 0.15
	separator2.anchor_right = 0.85
	main_vbox.add_child(separator2)

	# 分隔线下间距
	var sep2_spacing = Control.new()
	sep2_spacing.custom_minimum_size = Vector2(0, 15)
	main_vbox.add_child(sep2_spacing)

	# 选项容器
	options_container = VBoxContainer.new()
	options_container.name = "OptionsContainer"
	options_container.size_flags_horizontal = Control.SIZE_FILL
	options_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(options_container)

	panel.add_child(main_vbox)
	add_child(panel)

	# 初始隐藏
	visible = false


## 显示奇遇界面（带动画）
func show_adventure(event_data: Dictionary, results: Array):
	# 设置内容
	adventure_name_label.text = event_data.get("name", "未知奇遇")
	adventure_desc_label.text = event_data.get("des", "")

	# 清理旧选项
	for btn in option_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	option_buttons.clear()
	while options_container.get_child_count() > 0:
		var child = options_container.get_child(0)
		options_container.remove_child(child)
		child.queue_free()

	# 创建选项
	for i in range(results.size()):
		var result = results[i]
		var des = result.get("des", "")
		var result_id = result.get("id", "")

		# 替换参数占位符
		var params = result.get("params", {})
		for key in params:
			des = des.replace("【" + key + "】", str(params[key]))

		var option_button = _create_option_button(i + 1, des, result_id)
		options_container.add_child(option_button)
		option_buttons.append(option_button)

	# 显示并淡入
	visible = true
	var tween = create_tween()
	tween.tween_property(fade_background, "color", Color(0, 0, 0, 0.85), 0.5)
	print("【奇遇UI】奇遇界面已显示: ", event_data.get("name", ""))


## 隐藏奇遇界面（带动画）
func hide_adventure():
	var tween = create_tween()
	tween.tween_property(fade_background, "color", Color(0, 0, 0, 0), 0.3)
	await tween.finished
	visible = false
	print("【奇遇UI】奇遇界面已隐藏")


## 创建选项按钮
func _create_option_button(option_number: int, description: String, result_id: String) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(0, 70)
	container.size_flags_horizontal = Control.SIZE_FILL

	# 选项面板
	var panel = Panel.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.15, 0.9)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.5, 0.4, 0.3, 0.8)
	panel.add_theme_stylebox_override("panel", panel_style)

	# 内容 HBox
	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.add_theme_constant_override("separation", 15)

	# 选项序号
	var number_label = Label.new()
	number_label.text = str(option_number)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.custom_minimum_size = Vector2(50, 0)
	number_label.add_theme_font_size_override("font_size", 32)
	number_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	number_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.1, 0.9))
	number_label.add_theme_constant_override("outline_size", 2)
	hbox.add_child(number_label)

	# 选项描述
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 24)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.size_flags_vertical = Control.SIZE_FILL
	hbox.add_child(desc_label)

	panel.add_child(hbox)
	container.add_child(panel)

	return container


## 淡出并隐藏（用于骰子投掷前）
func fade_out():
	var tween = create_tween()
	tween.tween_property(fade_background, "color", Color(0, 0, 0, 0), 0.8)
	await tween.finished
	visible = false

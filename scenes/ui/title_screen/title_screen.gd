extends Control
## 游戏标题界面
## 游戏启动的第一个场景

# UI 组件
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var start_button = $MarginContainer/VBoxContainer/StartButton
@onready var exit_button = $MarginContainer/VBoxContainer/ExitButton

# 信号：开始游戏
signal on_start_game_pressed()


func _ready():
	_setup_ui()
	_connect_signals()


## 设置 UI
func _setup_ui():
	# 设置覆盖层布局
	anchors_preset = Control.PRESET_FULL_RECT
	grow_horizontal = 2  # GROW_BOTH_ENDS
	grow_vertical = 2  # GROW_BOTH_ENDS

	# 设置背景颜色（深色渐变）
	var bg_color = Color(0.1, 0.1, 0.15, 1.0)
	var bg_rect = ColorRect.new()
	bg_rect.name = "Background"
	bg_rect.anchors_preset = Control.PRESET_FULL_RECT
	bg_rect.grow_horizontal = 2  # GROW_BOTH_ENDS
	bg_rect.grow_vertical = 2  # GROW_BOTH_ENDS
	bg_rect.color = bg_color
	add_child(bg_rect)
	bg_rect.move_child(bg_rect, 0)

	# 设置标题
	if title_label:
		title_label.text = "晋升吧骰子"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 48)

	# 设置按钮
	if start_button:
		start_button.text = "开始游戏"
		start_button.custom_minimum_size = Vector2(200, 60)

	if exit_button:
		exit_button.text = "退出游戏"
		exit_button.custom_minimum_size = Vector2(200, 60)


## 连接信号
func _connect_signals():
	if start_button:
		start_button.pressed.connect(_on_start_pressed)

	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)


## 开始按钮点击
func _on_start_pressed():
	print("【标题界面】开始游戏")
	on_start_game_pressed.emit()

	# 使用加载动画过渡
	_transition_to_character_select()


## 退出按钮点击
func _on_exit_pressed():
	print("【标题界面】退出游戏")
	get_tree().quit()


## 切换到角色选择界面
func _transition_to_character_select():
	if LoadingOverlay:
		LoadingOverlay.fade_in(0.3)
		await LoadingOverlay.wait_fade_in()

		# 切换到角色选择场景
		var tree = get_tree()
		tree.change_scene_to_file("res://scenes/ui/character_select/character_select.tscn")

		await LoadingOverlay.wait_fade_out()

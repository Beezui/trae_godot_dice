extends Control
## 角色选择界面
## 允许玩家选择出战的角色

# 信号：角色选择完成
signal on_character_selected(hero_ids: Array[int])

# UI 组件
@onready var character_container = $MarginContainer/VBoxContainer/CharacterContainer
@onready var confirm_button = $MarginContainer/VBoxContainer/ConfirmButton
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var hint_label = $MarginContainer/VBoxContainer/HintLabel

# 数据
var selected_hero_ids: Array[int] = []
var available_heroes: Array[Dictionary] = []
var character_cards: Array = []

# 最大选择数量
var max_selection: int = 3


func _ready():
	_setup_ui()
	_load_available_heroes()
	_create_character_cards()


## 设置 UI
func _setup_ui():
	# 设置覆盖层布局
	anchors_preset = Control.PRESET_FULL_RECT
	grow_horizontal = 2  # GROW_BOTH_ENDS
	grow_vertical = 2  # GROW_BOTH_ENDS

	# 设置背景颜色
	var bg_color = Color(0.15, 0.15, 0.2, 1.0)
	var bg_rect = ColorRect.new()
	bg_rect.name = "Background"
	bg_rect.anchors_preset = Control.PRESET_FULL_RECT
	bg_rect.grow_horizontal = 2  # GROW_BOTH_ENDS
	bg_rect.grow_vertical = 2  # GROW_BOTH_ENDS
	bg_rect.color = bg_color
	add_child(bg_rect)
	bg_rect.move_child(bg_rect, 0)  # 移到最底层

	# 设置标题
	if title_label:
		title_label.text = "选择你的角色"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 32)

	# 设置提示
	if hint_label:
		hint_label.text = "点击角色卡片选择/取消选择（最多选择 %d 个）" % max_selection
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size", 16)

	# 确认按钮
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
		confirm_button.text = "确认开始游戏"


## 加载可用角色
func _load_available_heroes():
	# 从 hero.json 加载所有可用角色（type=1 的玩家角色）
	var file_path = "res://table/hero.json"
	var file = FileAccess.open(file_path, FileAccess.READ)

	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())

		if parse_result == OK:
			var data = json.get_data()

			if data is Dictionary and data.has("heroes"):
				for hero in data["heroes"]:
					if hero.get("type", 1) == 1:  # 只加载玩家角色
						available_heroes.append(hero)

		print("【角色选择】加载了 %d 个可用角色" % available_heroes.size())
	else:
		push_error("【角色选择】无法打开 hero.json")
		# 创建测试数据
		available_heroes.append({
			"id": "1",
			"name": "测试勇士",
			"type": 1,
			"attr_hp": "100",
			"attr_mp": "50",
			"portrait": "1"
		})


## 创建角色卡片
func _create_character_cards():
	# 清除现有卡片
	for card in character_cards:
		if card and is_instance_valid(card):
			card.queue_free()
	character_cards.clear()

	# 创建新卡片
	for hero in available_heroes:
		var card = _create_character_card(hero)
		character_container.add_child(card)
		character_cards.append(card)


## 创建单个角色卡片
func _create_character_card(hero: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.name = "CharacterCard_" + str(hero.get("id", "unknown"))
	card.custom_minimum_size = Vector2(200, 280)

	# 设置卡片样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.3, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)

	# 创建垂直布局
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# 头像区域
	var portrait_panel = Panel.new()
	portrait_panel.name = "PortraitPanel"
	portrait_panel.custom_minimum_size = Vector2(150, 150)
	vbox.add_child(portrait_panel)

	var portrait_label = Label.new()
	portrait_label.name = "PortraitLabel"
	portrait_label.text = "头像"
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.add_theme_font_size_override("font_size", 24)
	portrait_panel.add_child(portrait_label)

	# 角色名称
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = hero.get("name", "未知角色")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	# 属性显示
	var stats_grid = GridContainer.new()
	stats_grid.name = "StatsGrid"
	stats_grid.columns = 2
	vbox.add_child(stats_grid)

	# HP
	var hp_label = Label.new()
	hp_label.text = "HP: " + str(hero.get("attr_hp", "100"))
	stats_grid.add_child(hp_label)

	# MP
	var mp_label = Label.new()
	mp_label.text = "MP: " + str(hero.get("attr_mp", "50"))
	stats_grid.add_child(mp_label)

	# 选择指示器
	var select_indicator = Label.new()
	select_indicator.name = "SelectIndicator"
	select_indicator.text = "未选择"
	select_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_indicator.add_theme_font_size_override("font_size", 14)
	select_indicator.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(select_indicator)

	# 点击事件
	card.gui_input.connect(_on_card_gui_input.bind(card, hero, select_indicator))

	# 存储英雄数据
	card.set_meta("hero_data", hero)
	card.set_meta("is_selected", false)

	return card


## 卡片点击事件
func _on_card_gui_input(event: InputEvent, card: PanelContainer, hero: Dictionary, indicator: Label):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_card_selection(card, indicator)


## 切换卡片选择状态
func _toggle_card_selection(card: PanelContainer, indicator: Label):
	var is_selected = card.get_meta("is_selected")
	var hero_id = int(card.get_meta("hero_data").get("id", "0"))

	if is_selected:
		# 取消选择
		card.set_meta("is_selected", false)
		indicator.text = "未选择"
		indicator.modulate = Color(0.7, 0.7, 0.7)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.25, 0.3, 1)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		card.add_theme_stylebox_override("panel", style)

		selected_hero_ids.erase(hero_id)
	else:
		# 检查是否已达上限
		if selected_hero_ids.size() >= max_selection:
			print("【角色选择】已达最大选择数量（%d 个）" % max_selection)
			return

		# 选择
		card.set_meta("is_selected", true)
		indicator.text = "已选择"
		indicator.modulate = Color(0.3, 1.0, 0.5)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.5, 0.3, 1)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.border_color = Color(0.5, 1.0, 0.5)
		style.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", style)

		selected_hero_ids.append(hero_id)

	print("【角色选择】当前选择：", selected_hero_ids)


## 确认按钮点击
func _on_confirm_pressed():
	if selected_hero_ids.size() > 0:
		print("【角色选择】确认选择：", selected_hero_ids)

		# 存储玩家队伍到 LevelTransitionController
		var transition_controller = LevelTransitionController.get_instance()
		if transition_controller:
			transition_controller.set_meta("player_party", selected_hero_ids)

		# 发出信号并切换到游戏主入口
		on_character_selected.emit(selected_hero_ids)

		# 使用加载动画过渡
		_transition_to_game_main()
	else:
		print("【角色选择】请至少选择一个角色")


## 切换到游戏主入口
func _transition_to_game_main():
	if LoadingOverlay:
		LoadingOverlay.fade_in(0.3)
		await LoadingOverlay.wait_fade_in()

		# 切换到游戏主入口场景
		var tree = get_tree()
		tree.change_scene_to_file("res://scenes/game_main/game_main.tscn")

		await LoadingOverlay.wait_fade_out()

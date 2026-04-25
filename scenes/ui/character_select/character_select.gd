extends Control
## 角色选择界面
## 允许玩家选择出战的角色

# 信号：角色选择完成
signal on_character_selected(hero_id: String)

# UI 组件
@onready var character_container = $MarginContainer/VBoxContainer/CharacterContainer
@onready var confirm_button = $MarginContainer/VBoxContainer/ConfirmButton
@onready var title_label = $MarginContainer/VBoxContainer/TitleLabel
@onready var hint_label = $MarginContainer/VBoxContainer/HintLabel

# 数据
var selected_hero_id: String = ""  # 当前选择的英雄 ID，空字符串表示未选择
var available_heroes: Array[Dictionary] = []
var character_cards: Array = []

# 最大选择数量（固定为 1，单选）
var max_selection: int = 1


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

	# 设置标题
	if title_label:
		title_label.text = "选择你的角色"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 32)

	# 设置提示
	if hint_label:
		hint_label.text = "点击角色卡片选择（只能选择 1 名角色）"
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
	var card_scene = load("res://scenes/ui/character_card.tscn")
	if not card_scene:
		push_error("【角色选择】无法加载角色卡片预制")
		return null

	var card = card_scene.instantiate() as PanelContainer
	if not card:
		push_error("【角色选择】无法实例化角色卡片")
		return null

	card.name = "CharacterCard_" + str(hero.get("id", "unknown"))

	# 填充数据
	if card.has_method("setup"):
		card.setup(hero)

	# 点击事件
	card.gui_input.connect(_on_card_gui_input.bind(card, hero))

	# 存储英雄数据
	card.set_meta("hero_data", hero)
	card.set_meta("is_selected", false)

	return card


## 卡片点击事件
func _on_card_gui_input(event: InputEvent, card: PanelContainer, hero: Dictionary):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_card_selection(card)


## 切换卡片选择状态
func _toggle_card_selection(card: PanelContainer):
	var is_selected = card.get_meta("is_selected")
	var hero_id = card.get_meta("hero_data").get("id", "")

	if is_selected:
		# 取消选择
		card.set_meta("is_selected", false)
		if card.has_method("set_selected"):
			card.set_selected(false)
		selected_hero_id = ""
	else:
		# 单选：先取消之前选择的卡片
		if selected_hero_id != "":
			_clear_previous_selection()

		# 选择新卡片
		card.set_meta("is_selected", true)
		if card.has_method("set_selected"):
			card.set_selected(true)
		selected_hero_id = hero_id

	print("【角色选择】当前选择：", selected_hero_id)


## 清空之前的选择
func _clear_previous_selection():
	for card in character_cards:
		if card and is_instance_valid(card):
			var card_hero_id = card.get_meta("hero_data").get("id", "")
			if card_hero_id == selected_hero_id:
				card.set_meta("is_selected", false)
				if card.has_method("set_selected"):
					card.set_selected(false)
				break


## 确认按钮点击
func _on_confirm_pressed():
	if selected_hero_id != "":
		print("【角色选择】确认选择：英雄 ID=", selected_hero_id)

		# 存储玩家队伍到 LevelTransitionController（单元素数组）
		# 注意：hero.json 中的 id 是字符串，但 game_main.gd 期望 Array[int]
		# 所以需要转换为整数数组
		var party_array: Array[int] = [selected_hero_id.to_int()]

		var transition_controller = LevelTransitionController.get_instance()
		if transition_controller:
			transition_controller.set_meta("player_party", party_array)

		# 发出信号并切换到游戏主入口
		on_character_selected.emit(selected_hero_id)

		# 使用加载动画过渡
		_transition_to_game_main()
	else:
		print("【角色选择】请选择一个角色")


## 切换到游戏主入口
func _transition_to_game_main():
	if LoadingOverlay:
		LoadingOverlay.fade_in(0.3)
		await LoadingOverlay.wait_fade_in()

		# 切换到游戏主入口场景
		var tree = get_tree()
		tree.change_scene_to_file("res://scenes/game_main/game_main.tscn")

		await LoadingOverlay.wait_fade_out()

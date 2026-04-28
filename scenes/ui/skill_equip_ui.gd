extends Control
## 技能穿戴 UI
## 玩家选择骰子 → 选择骰子面 → 选择技能进行分配

# 信号
signal on_equip_confirmed  # 确认分配
signal on_ui_closed        # 关闭 UI

# UI 组件引用
@onready var dice_list_container = $MainHBox/LeftPanel/ScrollContainer/DiceListContainer
@onready var dice_info_label = $MainHBox/CenterPanel/DiceInfoLabel
@onready var effect_label = $MainHBox/CenterPanel/EffectLabel
@onready var face_grid = $MainHBox/CenterPanel/FaceGrid
@onready var skill_title_label = $MainHBox/RightPanel/SkillTitleHBox/SkillTitleLabel
@onready var selected_face_label = $MainHBox/RightPanel/SkillTitleHBox/SelectedFaceLabel
@onready var skill_list_container = $MainHBox/RightPanel/SkillScroll/SkillListContainer
@onready var reset_button = $MainHBox/BottomHBox/ResetButton
@onready var confirm_button = $MainHBox/BottomHBox/ConfirmButton
@onready var hint_label = $MainHBox/BottomHBox/HintLabel

# 状态
var selected_instance_id: int = -1  # 当前选中的骰子实例 ID
var selected_face_index: int = -1   # 当前选中的骰子面 (0-5)

# 缓存
var dice_list_buttons = {}     # { instance_id: Button }
var face_buttons = {}          # { face_index: Button }
var skill_buttons = {}         # { skill_id: Button }
var blank_dice_cache = {}      # 空白骰子模板缓存


func _ready():
	_setup_ui()
	_load_data()


## 初始化 UI
func _setup_ui():
	reset_button.pressed.connect(_on_reset_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)

	# ESC 关闭
	hint_label.text = "点击骰子选择 → 点击面 → 点击技能分配 | ESC 关闭"


## 加载数据并刷新 UI
func _load_data():
	if not PlayerData:
		push_error("【技能穿戴】PlayerData 不可用")
		return

	# 加载空白骰子模板缓存
	_load_blank_dice_cache()

	# 刷新骰子列表
	_refresh_dice_list()

	# 如果没有选中骰子，显示提示
	if selected_instance_id == -1:
		_show_face_placeholder()
		_show_skill_placeholder()


## 加载空白骰子模板到缓存
func _load_blank_dice_cache():
	var reader = preload("res://scripts/blank_dice_csv_reader.gd").new()
	var ids = reader.get_all_blank_dice_ids()
	for id in ids:
		blank_dice_cache[id] = reader.get_blank_dice_config(id)


## 刷新骰子列表
func _refresh_dice_list():
	# 清理旧按钮
	for button in dice_list_buttons.values():
		if button and is_instance_valid(button):
			button.queue_free()
	dice_list_buttons.clear()

	var instance_ids = PlayerData.get_all_dice_instance_ids()
	if instance_ids.is_empty():
		var label = Label.new()
		label.text = "暂无骰子"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		dice_list_container.add_child(label)
		return

	for instance_id in instance_ids:
		var instance = PlayerData.get_dice_instance(instance_id)
		var button = _create_dice_list_button(instance_id, instance)
		dice_list_container.add_child(button)


## 创建骰子列表按钮
func _create_dice_list_button(instance_id: int, instance: Dictionary) -> Button:
	var button = Button.new()
	button.text = instance.get("name", "未知骰子")
	button.custom_minimum_size = Vector2(0, 40)
	button.tooltip_text = instance.get("description", "")

	# 标记技能已配置数量
	var faces = instance.get("faces", [])
	var skill_count = 0
	for face in faces:
		if str(face) != "0":
			skill_count += 1
	button.text += " (%d/6)" % skill_count

	# 高亮选中
	if instance_id == selected_instance_id:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.5, 0.8, 0.4)
		button.add_theme_stylebox_override("normal", style)

	button.pressed.connect(_on_dice_selected.bind(instance_id))
	dice_list_buttons[instance_id] = button
	return button


## 刷新中间骰子面展示
func _refresh_dice_faces():
	if selected_instance_id == -1:
		_show_face_placeholder()
		return

	var instance = PlayerData.get_dice_instance(selected_instance_id)
	if instance.is_empty():
		_show_face_placeholder()
		return

	# 更新骰子信息
	dice_info_label.text = instance.get("name", "未知骰子")

	# 更新被动效果描述
	var effect_type = instance.get("effect_type", "")
	if effect_type.is_empty():
		effect_label.text = "无被动效果"
	else:
		var desc = _format_effect_description(instance)
		effect_label.text = "被动： " + desc

	# 清理旧面按钮
	for button in face_buttons.values():
		if button and is_instance_valid(button):
			button.queue_free()
	face_buttons.clear()

	# 创建 6 个面按钮
	var faces = instance.get("faces", ["0", "0", "0", "0", "0", "0"])
	for i in range(6):
		var face_btn = _create_face_button(i, faces[i])
		face_grid.add_child(face_btn)
		face_buttons[i] = face_btn

	# 刷新技能列表
	_refresh_skill_list()


## 创建骰子面按钮
func _create_face_button(face_index: int, skill_id: String) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 60)

	if skill_id == "0" or skill_id.is_empty():
		button.text = "面 %d\n[空]" % (face_index + 1)
		button.tooltip_text = "未配置技能"
	else:
		# 显示技能名称
		var skill_name = _get_skill_name(skill_id)
		button.text = "面 %d\n%s" % [(face_index + 1), skill_name]
		button.tooltip_text = "技能 ID: %s" % skill_id

	# 高亮选中
	if face_index == selected_face_index:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.8, 0.2, 0.5)
		button.add_theme_stylebox_override("normal", style)

	button.pressed.connect(_on_face_selected.bind(face_index))
	return button


## 显示骰子面占位
func _show_face_placeholder():
	for button in face_buttons.values():
		if button and is_instance_valid(button):
			button.queue_free()
	face_buttons.clear()

	dice_info_label.text = "选择一个骰子"
	effect_label.text = ""


## 刷新右侧技能列表
func _refresh_skill_list():
	if not PlayerData:
		return

	# 清理旧按钮
	for button in skill_buttons.values():
		if button and is_instance_valid(button):
			button.queue_free()
	skill_buttons.clear()

	if selected_face_index == -1:
		_show_skill_placeholder()
		return

	# 更新选中面标签
	var face_name = "面 %d" % (selected_face_index + 1)
	selected_face_label.text = face_name

	# 获取已解锁技能
	var unlocked = PlayerData.get_all_unlocked_skills()
	if unlocked.is_empty():
		var label = Label.new()
		label.text = "暂无已解锁技能"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		skill_list_container.add_child(label)
		return

	# 创建技能按钮
	for skill_id in unlocked:
		var sid = str(skill_id)
		var skill_name = _get_skill_name(sid)
		var button = Button.new()
		button.text = skill_name
		button.custom_minimum_size = Vector2(0, 36)
		button.tooltip_text = "技能 ID: %s" % sid
		button.pressed.connect(_on_skill_selected.bind(sid))
		skill_list_container.add_child(button)
		skill_buttons[sid] = button

	# 添加"清除技能"按钮
	var clear_btn = Button.new()
	clear_btn.text = "[清除] 不配置技能"
	clear_btn.custom_minimum_size = Vector2(0, 36)
	clear_btn.pressed.connect(_on_clear_skill_selected)
	skill_list_container.add_child(clear_btn)


## 显示技能列表占位
func _show_skill_placeholder():
	selected_face_label.text = ""
	for button in skill_buttons.values():
		if button and is_instance_valid(button):
			button.queue_free()
	skill_buttons.clear()

	var label = Label.new()
	label.text = "请先选择一个骰子面"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	skill_list_container.add_child(label)


## 骰子选择事件
func _on_dice_selected(instance_id: int):
	selected_instance_id = instance_id
	selected_face_index = -1

	# 刷新骰子列表（更新选中高亮）
	_refresh_dice_list()

	# 刷新骰子面
	_refresh_dice_faces()

	print("【技能穿戴】选中骰子：instance_id=", instance_id)


## 骰子面选择事件
func _on_face_selected(face_index: int):
	selected_face_index = face_index

	# 刷新面按钮（更新选中高亮）
	_refresh_dice_faces()

	print("【技能穿戴】选中面：", face_index + 1)


## 技能选择事件
func _on_skill_selected(skill_id: String):
	if selected_instance_id == -1 or selected_face_index == -1:
		push_error("【技能穿戴】未选中骰子或面")
		return

	PlayerData.assign_skill_to_face(selected_instance_id, selected_face_index, skill_id)
	print("【技能穿戴】分配技能：实例=", selected_instance_id, " 面=", selected_face_index + 1, " 技能=", skill_id)

	# 刷新 UI
	_refresh_dice_faces()
	_refresh_dice_list()  # 更新技能计数


## 清除技能事件
func _on_clear_skill_selected():
	if selected_instance_id == -1 or selected_face_index == -1:
		return

	PlayerData.assign_skill_to_face(selected_instance_id, selected_face_index, "0")
	print("【技能穿戴】清除技能：实例=", selected_instance_id, " 面=", selected_face_index + 1)

	_refresh_dice_faces()
	_refresh_dice_list()


## 重置按钮
func _on_reset_pressed():
	if selected_instance_id == -1:
		return

	# 清除选中骰子的所有技能
	for i in range(6):
		PlayerData.assign_skill_to_face(selected_instance_id, i, "0")

	print("【技能穿戴】重置骰子：instance_id=", selected_instance_id)

	_refresh_dice_faces()
	_refresh_dice_list()


## 确认按钮
func _on_confirm_pressed():
	print("【技能穿戴】确认配置")
	on_equip_confirmed.emit()


## 获取技能名称
func _get_skill_name(skill_id: String) -> String:
	var reader = preload("res://scripts/skill_csv_reader.gd").new()
	var skill_data = reader.get_skill(skill_id)
	if skill_data and skill_data.has("name"):
		return skill_data["name"]
	return "技能 " + skill_id


## 格式化被动效果描述
func _format_effect_description(instance: Dictionary) -> String:
	var effect_type = instance.get("effect_type", "")
	var desc = instance.get("description", "")

	# 替换 [p1] ~ [p4] 占位符
	var p1 = instance.get("p1", "0")
	var p2 = instance.get("p2", "0")
	var p3 = instance.get("p3", "0")
	var p4 = instance.get("p4", "0")

	desc = desc.replace("[p1]", str(p1))
	desc = desc.replace("[p2]", str(p2))
	desc = desc.replace("[p3]", str(p3))
	desc = desc.replace("[p4]", str(p4))

	return desc


## 打开 UI（外部调用）
func open():
	visible = true
	_load_data()


## 关闭 UI
func close():
	visible = false
	on_ui_closed.emit()


## ESC 键关闭
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if visible:
			close()

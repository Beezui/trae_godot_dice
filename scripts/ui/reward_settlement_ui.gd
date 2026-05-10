extends Control

## 奖励结算 UI 场景脚本
## 在关卡完成后显示获得的奖励（道具、金币等）
## 支持悬停显示详细信息

# 信号
signal on_confirm_pressed
signal on_reward_hovered(reward: Dictionary)
signal on_reward_hover_exited

# 奖励数据结构
class RewardItem:
	var item_id: String
	var item_name: String
	var item_type: String
	var icon: String
	var description: String
	var price: int

	func _init(id: String, name: String, type: String, icon_path: String, desc: String, item_price: int):
		item_id = id
		item_name = name
		item_type = type
		icon = icon_path
		description = desc
		price = item_price

# @onready 引用所有 UI 元素
@onready var _title_label: Label = $Panel/VBox/TitleLabel
@onready var _reward_list_container: ScrollContainer = $Panel/VBox/RewardListContainer
@onready var _reward_list: VBoxContainer = $Panel/VBox/RewardListContainer/RewardList
@onready var _confirm_button: Button = $Panel/VBox/ConfirmButton
@onready var _tooltip: Control = $Tooltip
@onready var _tooltip_name: Label = $Tooltip/TooltipName
@onready var _tooltip_desc: Label = $Tooltip/TooltipDesc
@onready var _tooltip_price: Label = $Tooltip/TooltipPrice


func _ready():
	# 连接按钮信号
	_confirm_button.pressed.connect(_on_confirm_pressed)

	# 默认隐藏提示框
	_tooltip.visible = false


func _on_confirm_pressed():
	on_confirm_pressed.emit()


## 显示奖励列表
## @param rewards: Array[Dictionary] 奖励数据数组，每项包含 id 和数量
## @param item_table: Dictionary 从道具表加载的完整道具数据（可选）
func show_rewards(rewards: Array, item_table: Dictionary = {}) -> void:
	visible = true

	# 清空现有列表
	for child in _reward_list.get_children():
		child.queue_free()

	# 填充奖励列表
	for reward in rewards:
		var reward_item = _create_reward_item(reward, item_table)
		_reward_list.add_child(reward_item)


## 创建单个奖励项
func _create_reward_item(reward: Dictionary, item_table: Dictionary) -> Control:
	var item_id = str(reward.get("id", ""))

	# 从道具表获取详细信息（如果提供了）
	var item_name = item_id
	var item_type = ""
	var icon_path = ""
	var description = ""
	var price = 0

	if item_table.has(item_id):
		var item_data = item_table[item_id]
		item_name = item_data.get("name", item_id)
		item_type = item_data.get("type", "")
		icon_path = item_data.get("icon", "")
		description = item_data.get("description", "")
		price = item_data.get("price", 0)
	elif reward.has("name"):
		# 备用：从传入数据中获取
		item_name = reward.get("name", item_id)
		item_type = reward.get("type", "")
		icon_path = reward.get("icon", "")
		description = reward.get("description", "")
		price = reward.get("price", 0)

	# 构建容器
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 80)
	container.add_theme_constant_override("separation", 15)

	# 图标
	var icon_control = Control.new()
	icon_control.custom_minimum_size = Vector2(64, 64)

	var icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if icon_path != "":
		var full_path = "res://textures/items/" + icon_path
		if ResourceLoader.exists(full_path):
			icon_rect.texture = load(full_path)

	# 非物品奖励的 fallback 图标（纯色方块）
	if icon_rect.texture == null:
		var color = Color(0.6, 0.6, 0.6)  # 默认灰色
		if "货币" in item_type or "gold" in item_id:
			color = Color(1.0, 0.85, 0.3)
		elif "属性" in item_type:
			color = Color(0.3, 0.7, 1.0)
		elif "效果" in item_type:
			color = Color(0.3, 1.0, 0.5)
		elif "损失" in item_type:
			color = Color(1.0, 0.3, 0.3)
		elif "遗物" in item_type:
			color = Color(0.8, 0.3, 1.0)
		icon_rect.texture = _create_placeholder_texture(color)

	icon_control.add_child(icon_rect)
	container.add_child(icon_control)

	# 名称标签
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 20)

	container.add_child(name_label)

	# 数量标签（如果有）
	if reward.has("amount") and int(reward.get("amount", 1)) > 1:
		var amount_label = Label.new()
		amount_label.name = "AmountLabel"
		amount_label.text = "x%d" % int(reward.get("amount", 1))
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount_label.add_theme_font_size_override("font_size", 18)
		amount_label.add_theme_color_override("font_color", Color.YELLOW)
		container.add_child(amount_label)

	# 存储奖励数据用于悬停
	container.set_meta("reward_data", {
		"id": item_id,
		"name": item_name,
		"type": item_type,
		"description": description,
		"price": price,
		"amount": reward.get("amount", 1)
	})

	# 鼠标悬停事件
	container.mouse_entered.connect(_on_reward_hovered_internal.bind(container))
	container.mouse_exited.connect(_on_reward_hover_exited_internal)

	return container


## 奖励项悬停（内部处理）
func _on_reward_hovered_internal(container: Control):
	var reward_data = container.get_meta("reward_data") if container.has_meta("reward_data") else {}
	on_reward_hovered.emit(reward_data)
	_show_tooltip(reward_data)


## 奖励项悬停结束（内部处理）
func _on_reward_hover_exited_internal():
	on_reward_hover_exited.emit()
	_hide_tooltip()


## 显示提示框
func _show_tooltip(data: Dictionary):
	if data.is_empty():
		return

	var item_name = data.get("name", "未知道具")
	var item_desc = data.get("description", "")
	var item_type = data.get("type", "")
	var price = data.get("price", 0)
	var amount = data.get("amount", 1)

	_tooltip_name.text = item_name + (" (" + item_type + ")" if item_type else "")
	_tooltip_desc.text = item_desc

	# 非物品奖励显示数值变化
	if item_type in ["属性", "效果", "损失"]:
		var sign = "+" if amount > 0 else ""
		_tooltip_price.text = sign + str(amount)
	elif amount > 1:
		_tooltip_price.text = "价格: %d 金币 x%d" % [price, amount]
	else:
		_tooltip_price.text = "价格: %d 金币" % price

	# 定位到鼠标
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(250, 120)
	var pos = mouse_pos + Vector2(15, 15)

	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tooltip_size.x - 15
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tooltip_size.y - 15

	_tooltip.position = pos
	_tooltip.visible = true


## 隐藏提示框
func _hide_tooltip():
	_tooltip.visible = false


## 隐藏界面
func hide_ui() -> void:
	visible = false


## 设置标题文本
func set_title(title: String) -> void:
	_title_label.text = title


## 创建纯色占位图标（用于非物品奖励）
func _create_placeholder_texture(color: Color) -> ImageTexture:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

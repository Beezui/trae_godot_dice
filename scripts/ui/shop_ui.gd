extends Control
## 商店 UI 场景脚本
## 负责渲染和管理商店界面的所有 UI 元素

# 信号
signal on_close_pressed
signal on_advance_pressed
signal on_throw_discount_pressed
signal on_item_hovered(item: Dictionary)
signal on_item_hover_exited
signal on_item_purchased(item: Dictionary)

# @onready 引用所有 UI 元素
@onready var _gold_label: Label = $GoldLabel
@onready var _discount_label: Label = $DiscountLabel
@onready var _item_grid: GridContainer = $GridContainer/ItemGrid
@onready var _tooltip_container: Control = $Tooltip
@onready var _tooltip_name: Label = $Tooltip/TooltipName
@onready var _tooltip_desc: Label = $Tooltip/TooltipDesc
@onready var _tooltip_price: Label = $Tooltip/TooltipPrice


func _ready():
	# 连接按钮信号
	$CloseButton.pressed.connect(_on_close_pressed)
	$AdvanceButton.pressed.connect(_on_advance_pressed)
	$ThrowDiscountButton.pressed.connect(_on_throw_discount_pressed)

	# 默认隐藏提示框
	_tooltip_container.visible = false


func _on_close_pressed():
	on_close_pressed.emit()


func _on_advance_pressed():
	on_advance_pressed.emit()


func _on_throw_discount_pressed():
	on_throw_discount_pressed.emit()


## 更新金币显示
func update_gold(amount: int):
	_gold_label.text = "金币: %d" % amount


## 更新折扣显示
func update_discount(discount: int):
	if discount > 0:
		_discount_label.text = "折扣: -%d%%" % discount
		_discount_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	else:
		_discount_label.text = "折扣: 无"
		_discount_label.add_theme_color_override("font_color", Color.WHITE)


## 填充道具网格
func populate_items(items: Array, purchased_ids: Array, discount: int):
	# 清空现有
	for child in _item_grid.get_children():
		child.queue_free()

	for item in items:
		var item_id = str(item["id"])
		var is_purchased = purchased_ids.has(item_id)

		var button = _create_item_button(item, is_purchased, discount)
		_item_grid.add_child(button)


## 创建道具按钮
func _create_item_button(item: Dictionary, is_purchased: bool, discount: int) -> TextureButton:
	var item_id = str(item["id"])
	var button = TextureButton.new()
	button.name = "ItemButton_" + item_id
	button.custom_minimum_size = Vector2(100, 120)
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.disabled = is_purchased

	# 加载图标
	var icon_path = "res://textures/items/" + item.get("icon", "")
	if ResourceLoader.exists(icon_path):
		var texture = load(icon_path)
		if texture:
			button.texture_normal = texture
	else:
		var placeholder = PlaceholderTexture2D.new()
		placeholder.size = Vector2(64, 64)
		button.texture_normal = placeholder

	# 鼠标悬停
	button.mouse_entered.connect(_on_item_hovered.bind(item, is_purchased, discount))
	button.mouse_exited.connect(_on_item_hover_exited)

	# 点击购买
	button.pressed.connect(_on_item_purchased.bind(item))

	return button


## 道具悬停
func _on_item_hovered(item: Dictionary, is_purchased: bool, discount: int):
	var item_name = item.get("name", "未知道具")
	var item_desc = item.get("description", "")
	var item_type = item.get("type", "")
	var original_price = item.get("price", 0)
	var discount_price = int(original_price * (1.0 - discount / 100.0))

	_tooltip_name.text = item_name + " (" + item_type + ")"
	if is_purchased:
		_tooltip_desc.text = item_desc + "\n[已购买]"
	else:
		_tooltip_desc.text = item_desc

	if is_purchased:
		_tooltip_price.text = "已售"
	else:
		_tooltip_price.text = "价格: %d 金币 (折后: %d)" % [original_price, discount_price]

	# 定位到鼠标
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(250, 150)
	var pos = mouse_pos + Vector2(15, 15)
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = mouse_pos.x - tooltip_size.x - 15
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = mouse_pos.y - tooltip_size.y - 15
	_tooltip_container.position = pos
	_tooltip_container.visible = true


## 道具悬停结束
func _on_item_hover_exited():
	_tooltip_container.visible = false


## 道具购买
func _on_item_purchased(item: Dictionary):
	on_item_purchased.emit(item)

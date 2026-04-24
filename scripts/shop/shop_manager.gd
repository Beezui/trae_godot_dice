extends Node
## 商店管理器 (Autoload 单例)
## 负责创建和管理全局唯一的商店 UI
## 每个贸易关卡共用同一个商店页面

## 信号：折扣骰子停止（供 trade_flow 等待结果）
signal on_discount_dice_stopped(discount: int)

## 道具数据
var _items_data: Array = []  # 所有道具
var _shop_items: Array = []  # 当前商店刷新的道具
var _purchased_ids: Array = []  # 已购买的道具 ID
var _discount: int = 0  # 当前折扣百分比
var _current_player = null  # 当前玩家角色（用于金币检查）

## UI 根节点
var _ui_root: Control = null
var _ui_created: bool = false

## UI 子节点引用
var _item_grid: GridContainer = null
var _gold_label: Label = null
var _discount_label: Label = null
var _advance_button: Button = null
var _tooltip_container: Control = null
var _tooltip_bg: ColorRect = null
var _tooltip_name: Label = null
var _tooltip_desc: Label = null
var _tooltip_price: Label = null

## 道具图标按钮缓存（item_id -> TextureButton）
var _item_buttons: Dictionary = {}

## 折扣骰子引用（已移至 game_main）


func _ready():
	print("【ShopManager】商店管理器已就绪")
	_load_items_data()


## 加载道具数据
func _load_items_data():
	var json_path = "res://table/items.json"
	if not ResourceLoader.exists(json_path):
		push_error("【ShopManager】道具数据文件不存在：", json_path)
		return

	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("【ShopManager】无法打开道具数据文件")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var result = json.parse(json_text)
	if result != OK:
		push_error("【ShopManager】解析道具数据失败")
		return

	var data = json.get_data()
	if data.has("items"):
		_items_data = data["items"]
		print("【ShopManager】已加载 ", _items_data.size(), " 个道具数据")


## 获取单例
static func get_instance():
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		var node = tree.root.get_node_or_null("ShopManager")
		if node:
			return node
	return null


## 初始化贸易会话
## @param stage 当前关卡阶段
## @param player 玩家角色列表
func initialize_trade_session(stage: int, player):
	# 按权重随机选择 8-10 个道具
	_select_shop_items(stage)
	_discount = 0
	_purchased_ids.clear()
	_current_player = player if player is Array else [player] if player else []
	print("【ShopManager】贸易会话已初始化，刷新 ", _shop_items.size(), " 个道具")


## 按权重随机选择道具
func _select_shop_items(stage: int):
	_shop_items.clear()

	if _items_data.is_empty():
		print("【ShopManager】道具数据为空")
		return

	# 计算总权重
	var total_weight = 0
	for item in _items_data:
		total_weight += item.get("weight", 10)

	if total_weight == 0:
		print("【ShopManager】道具总权重为 0")
		return

	# 随机选择 8-10 个道具（不重复）
	var target_count = randi() % 3 + 8  # 8-10
	var selected_ids = {}

	for attempt in range(target_count * 3):  # 最多尝试 target_count*3 次
		if selected_ids.size() >= target_count:
			break

		var rand_val = randf() * total_weight
		var cumulative = 0.0
		for item in _items_data:
			var item_weight = item.get("weight", 10)
			cumulative += item_weight
			if rand_val <= cumulative:
				var item_id = str(item["id"])
				if not selected_ids.has(item_id):
					selected_ids[item_id] = item
					_shop_items.append(item)
				break

	print("【ShopManager】已选择 ", _shop_items.size(), " 个道具用于商店展示")


## 打开商店 UI
func open_shop():
	if not _ui_created:
		_create_ui()

	if _ui_root:
		_ui_root.visible = true
		_refresh_shop_display()
		print("【ShopManager】商店已打开")


## 关闭商店 UI
func close_shop():
	if _ui_root:
		_ui_root.visible = false
		print("【ShopManager】商店已关闭")


## 销毁 UI
func _destroy_ui():
	if _ui_root and is_instance_valid(_ui_root):
		_ui_root.queue_free()
	_ui_root = null
	_ui_created = false
	_item_buttons.clear()


func _exit_tree():
	_destroy_ui()


## 创建 UI 结构
func _create_ui():
	if _ui_created:
		return

	print("【ShopManager】创建商店 UI...")

	# 创建 UI 根容器
	_ui_root = Control.new()
	_ui_root.name = "ShopUIRoot"
	_ui_root.anchors_preset = Control.PRESET_FULL_RECT
	# 商店需要接收鼠标事件，所以不设置 MOUSE_FILTER_IGNORE

	# 半透明背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.1, 0.1, 0.15, 0.92)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(bg)

	# 关闭按钮（右上角）
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.anchors_preset = Control.PRESET_TOP_RIGHT
	close_btn.offset_top = 10
	close_btn.offset_right = -10
	close_btn.offset_bottom = 50
	close_btn.offset_left = -60
	close_btn.pressed.connect(_on_advance_pressed)
	_ui_root.add_child(close_btn)

	# 标题
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "商店"
	title_label.anchors_preset = Control.PRESET_TOP_LEFT
	title_label.offset_top = 10
	title_label.offset_left = 20
	title_label.offset_right = 200
	title_label.offset_bottom = 50
	title_label.add_theme_font_size_override("font_size", 28)
	_ui_root.add_child(title_label)

	# 金币显示（右上角）
	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_gold_label.text = "金币: --"
	_gold_label.anchors_preset = Control.PRESET_TOP_RIGHT
	_gold_label.offset_top = 55
	_gold_label.offset_left = -200
	_gold_label.offset_right = -10
	_gold_label.offset_bottom = 85
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_root.add_child(_gold_label)

	# 折扣显示（左上角）
	_discount_label = Label.new()
	_discount_label.name = "DiscountLabel"
	_discount_label.text = "折扣: 无"
	_discount_label.anchors_preset = Control.PRESET_TOP_LEFT
	_discount_label.offset_top = 55
	_discount_label.offset_left = 20
	_discount_label.offset_right = 200
	_discount_label.offset_bottom = 85
	_discount_label.add_theme_font_size_override("font_size", 20)
	_ui_root.add_child(_discount_label)

	# 道具网格容器
	var grid_container = Control.new()
	grid_container.name = "GridContainer"
	grid_container.anchors_preset = Control.PRESET_FULL_RECT
	grid_container.offset_top = 100
	grid_container.offset_bottom = -60
	grid_container.offset_left = 20
	grid_container.offset_right = -20

	_item_grid = GridContainer.new()
	_item_grid.name = "ItemGrid"
	_item_grid.columns = 4
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_container.add_child(_item_grid)
	_ui_root.add_child(grid_container)

	# 投掷折扣骰子按钮
	var throw_button = Button.new()
	throw_button.name = "ThrowDiscountButton"
	throw_button.text = "投掷折扣骰子"
	throw_button.anchors_preset = Control.PRESET_BOTTOM_LEFT
	throw_button.offset_left = 20
	throw_button.offset_bottom = -15
	throw_button.offset_right = 200
	throw_button.offset_top = -50
	throw_button.pressed.connect(_on_throw_discount_pressed)
	_ui_root.add_child(throw_button)

	# 前进按钮
	_advance_button = Button.new()
	_advance_button.name = "AdvanceButton"
	_advance_button.text = "前进"
	_advance_button.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_advance_button.offset_left = -120
	_advance_button.offset_right = -20
	_advance_button.offset_bottom = -15
	_advance_button.offset_top = -50
	_advance_button.pressed.connect(_on_advance_pressed)
	_ui_root.add_child(_advance_button)

	# 提示框（鼠标悬停显示）
	_tooltip_container = Control.new()
	_tooltip_container.name = "Tooltip"
	_tooltip_container.visible = false
	_tooltip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tooltip_bg = ColorRect.new()
	_tooltip_bg.name = "TooltipBg"
	_tooltip_bg.color = Color(0.15, 0.15, 0.2, 0.95)
	_tooltip_bg.size = Vector2(250, 150)
	_tooltip_container.add_child(_tooltip_bg)

	_tooltip_name = Label.new()
	_tooltip_name.name = "TooltipName"
	_tooltip_name.anchors_preset = Control.PRESET_TOP_LEFT
	_tooltip_name.offset_top = 5
	_tooltip_name.offset_left = 10
	_tooltip_name.offset_right = -10
	_tooltip_name.offset_bottom = 30
	_tooltip_name.add_theme_font_size_override("font_size", 18)
	_tooltip_container.add_child(_tooltip_name)

	_tooltip_desc = Label.new()
	_tooltip_desc.name = "TooltipDesc"
	_tooltip_desc.anchors_preset = Control.PRESET_TOP_LEFT
	_tooltip_desc.offset_top = 35
	_tooltip_desc.offset_left = 10
	_tooltip_desc.offset_right = -10
	_tooltip_desc.offset_bottom = 90
	_tooltip_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_desc.size_flags_vertical = Control.SIZE_FILL
	_tooltip_desc.wrap_mode = TextServer.LINE_WORD_SMART
	_tooltip_desc.add_theme_font_size_override("font_size", 14)
	_tooltip_container.add_child(_tooltip_desc)

	_tooltip_price = Label.new()
	_tooltip_price.name = "TooltipPrice"
	_tooltip_price.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_tooltip_price.offset_top = -30
	_tooltip_price.offset_left = 10
	_tooltip_price.offset_right = -10
	_tooltip_price.offset_bottom = 5
	_tooltip_price.add_theme_font_size_override("font_size", 16)
	_tooltip_container.add_child(_tooltip_price)

	_ui_root.add_child(_tooltip_container)

	# 添加到场景树
	var root = Engine.get_main_loop().root
	root.add_child(_ui_root)

	_ui_created = true
	print("【ShopManager】商店 UI 已创建")


## 刷新商店显示
func _refresh_shop_display():
	if not _item_grid:
		return

	# 清空现有按钮
	for child in _item_grid.get_children():
		child.queue_free()
	_item_buttons.clear()

	# 创建道具按钮
	for item in _shop_items:
		var item_id = str(item["id"])
		var is_purchased = _purchased_ids.has(item_id)

		var button = _create_item_button(item, is_purchased)
		_item_grid.add_child(button)


## 创建道具按钮
func _create_item_button(item: Dictionary, is_purchased: bool) -> TextureButton:
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
		# 占位贴图
		var placeholder = PlaceholderTexture2D.new()
		placeholder.size = Vector2(64, 64)
		button.texture_normal = placeholder

	# 折扣后价格
	var original_price = item.get("price", 0)
	var discount_price = int(original_price * (1.0 - _discount / 100.0))

	# 鼠标悬停提示
	button.mouse_entered.connect(_on_item_hovered.bind(item))
	button.mouse_exited.connect(_on_item_hover_exited)

	# 点击购买
	button.pressed.connect(_on_item_purchased.bind(item))

	_item_buttons[item_id] = button
	return button


## 刷新金币和折扣显示
func _update_gold_and_discount():
	if _gold_label:
		var gold = 0
		if _current_player is Array and _current_player.size() > 0:
			var player = _current_player[0]
			if player and "gold" in player:
				gold = player.gold
		_gold_label.text = "金币: %d" % gold

	if _discount_label:
		if _discount > 0:
			_discount_label.text = "折扣: -%d%%" % _discount
			_discount_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
		else:
			_discount_label.text = "折扣: 无"
			_discount_label.add_theme_color_override("font_color", Color.WHITE)


## 设置折扣并更新商店
## @param discount 折扣百分比 (0-50)
func set_discount(discount: int):
	_discount = discount
	print("【ShopManager】折扣设置为 %d%%" % discount)
	_update_gold_and_discount()
	# 刷新按钮价格显示
	_refresh_shop_display()


## 获取玩家金币
func _get_player_gold() -> int:
	if _current_player is Array and _current_player.size() > 0:
		var player = _current_player[0]
		if player and "gold" in player:
			return player.gold
	return 0


## 扣除玩家金币
func _deduct_gold(amount: int) -> bool:
	if _current_player is Array and _current_player.size() > 0:
		var player = _current_player[0]
		if player and "gold" in player:
			if player.gold >= amount:
				player.gold -= amount
				print("【ShopManager】扣除金币 %d，剩余 %d" % [amount, player.gold])
				return true
	return false


## 道具悬停回调
func _on_item_hovered(item):
	var item_id = str(item["id"])
	var is_purchased = _purchased_ids.has(item_id)

	var original_price = item.get("price", 0)
	var discount_price = int(original_price * (1.0 - _discount / 100.0))
	var item_name = item.get("name", "未知道具")
	var item_desc = item.get("description", "")
	var item_type = item.get("type", "")

	if _tooltip_name:
		_tooltip_name.text = item_name + " (" + item_type + ")"
	if _tooltip_desc:
		if is_purchased:
			_tooltip_desc.text = item_desc + "\n[已购买]"
		else:
			_tooltip_desc.text = item_desc
	if _tooltip_price:
		if is_purchased:
			_tooltip_price.text = "已售"
		else:
			_tooltip_price.text = "价格: %d 金币 (折后: %d)" % [original_price, discount_price]

	# 定位提示框到鼠标位置
	var mouse_pos = get_viewport().get_mouse_position()
	if _tooltip_container:
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
	if _tooltip_container:
		_tooltip_container.visible = false


## 道具购买回调
func _on_item_purchased(item):
	var item_id = str(item["id"])
	if _purchased_ids.has(item_id):
		print("【ShopManager】道具 %s 已购买，跳过" % item_id)
		return

	var original_price = item.get("price", 0)
	var discount_price = int(original_price * (1.0 - _discount / 100.0))

	# 检查金币
	if _get_player_gold() < discount_price:
		print("【ShopManager】金币不足，需要 %d" % discount_price)
		return

	# 扣除金币
	if _deduct_gold(discount_price):
		_purchased_ids.append(item_id)
		print("【ShopManager】购买道具 %s，花费 %d 金币" % [item.get("name", ""), discount_price])
		_update_gold_and_discount()
		_refresh_shop_display()


## 投掷折扣骰子回调（已移至 game_main 处理）
func _on_throw_discount_pressed():
	print("【ShopManager】折扣骰子投掷由 game_main 处理")


## 前进按钮回调
func _on_advance_pressed():
	print("【ShopManager】点击前进，结束交易")
	close_shop()
	# 通知 game_main 继续命运骰子流程
	_resume_destiny_dice()


## 恢复命运骰子流程
func _resume_destiny_dice():
	# 查找 game_main 场景并恢复流程
	var root = Engine.get_main_loop().root
	# 遍历查找 game_main
	for i in range(root.get_child_count()):
		var child = root.get_child(i)
		if child.has_method("_spawn_destiny_dice"):
			child._spawn_destiny_dice()
			return
	print("【ShopManager】警告：找不到 game_main 的 _spawn_destiny_dice 方法")


## 获取 Sandbox 节点
func _get_sandbox() -> Node:
	var root = Engine.get_main_loop().root
	# 尝试从 LevelStage 获取当前场景
	var level_stage = LevelStage.get_instance() if root.has_node("LevelStage") else null
	if level_stage and level_stage.has_method("get_current_scene"):
		var current_scene = level_stage.get_current_scene()
		if current_scene and is_instance_valid(current_scene):
			if current_scene.has_node("Sandbox"):
				return current_scene.get_node("Sandbox")

	# 回退：从根节点查找
	for i in range(root.get_child_count()):
		var child = root.get_child(i)
		if child.has_node("Sandbox"):
			return child.get_node("Sandbox")

	return null

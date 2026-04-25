extends Node
## 商店管理器 (Autoload 单例)
## 负责加载和管理全局唯一的商店 UI 场景
## 每个贸易关卡共用同一个商店页面

## 信号：折扣骰子停止（供 trade_flow 等待结果）
signal on_discount_dice_stopped(discount: int)

## 信号：贸易完成（玩家点击前进/关闭，供 _start_trade await）
signal on_trade_completed

## 道具数据
var _items_data: Array = []  # 所有道具
var _shop_items: Array = []  # 当前商店刷新的道具
var _purchased_ids: Array = []  # 已购买的道具 ID
var _discount: int = 0  # 当前折扣百分比
var _current_player = null  # 当前玩家角色（用于金币检查）

## UI 场景引用
var _ui_scene: Node = null
var _ui_loaded: bool = false


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
func initialize_trade_session(stage: int, player):
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

	var total_weight = 0
	for item in _items_data:
		total_weight += item.get("weight", 10)

	if total_weight == 0:
		print("【ShopManager】道具总权重为 0")
		return

	var target_count = randi() % 3 + 8
	var selected_ids = {}

	for attempt in range(target_count * 3):
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
	if not _ui_loaded:
		_load_ui()

	if _ui_scene:
		_ui_scene.visible = true
		_refresh_shop_display()
		print("【ShopManager】商店已打开")


## 关闭商店 UI
func close_shop():
	if _ui_scene:
		_ui_scene.visible = false
		print("【ShopManager】商店已关闭")


## 销毁 UI
func _destroy_ui():
	if _ui_scene and is_instance_valid(_ui_scene):
		_ui_scene.queue_free()
	_ui_scene = null
	_ui_loaded = false


func _exit_tree():
	_destroy_ui()


## 加载商店 UI 场景
func _load_ui():
	if _ui_loaded:
		return

	print("【ShopManager】加载商店 UI 场景...")

	var scene = load("res://scenes/ui/shop_ui.tscn")
	if not scene:
		push_error("【ShopManager】无法加载商店 UI 场景")
		return

	_ui_scene = scene.instantiate()
	if not _ui_scene:
		push_error("【ShopManager】无法实例化商店 UI 场景")
		return

	# 连接场景信号
	_ui_scene.on_close_pressed.connect(_on_close_pressed)
	_ui_scene.on_advance_pressed.connect(_on_advance_pressed)
	_ui_scene.on_throw_discount_pressed.connect(_on_throw_discount_pressed)
	_ui_scene.on_item_purchased.connect(_on_item_purchased)

	# 添加到场景树
	var root = Engine.get_main_loop().root
	root.add_child(_ui_scene)

	_ui_loaded = true
	print("【ShopManager】商店 UI 已加载")


## 刷新商店显示
func _refresh_shop_display():
	if not _ui_scene or not _ui_scene.has_method("populate_items"):
		return

	var gold = _get_player_gold()
	_ui_scene.update_gold(gold)
	_ui_scene.update_discount(_discount)
	_ui_scene.populate_items(_shop_items, _purchased_ids, _discount)


## 设置折扣并更新商店
func set_discount(discount: int):
	_discount = discount
	print("【ShopManager】折扣设置为 %d%%" % discount)

	if _ui_scene:
		var gold = _get_player_gold()
		_ui_scene.update_gold(gold)
		_ui_scene.update_discount(_discount)
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


## 道具购买回调
func _on_item_purchased(item):
	var item_id = str(item["id"])
	if _purchased_ids.has(item_id):
		print("【ShopManager】道具 %s 已购买，跳过" % item_id)
		return

	var original_price = item.get("price", 0)
	var discount_price = int(original_price * (1.0 - _discount / 100.0))

	if _get_player_gold() < discount_price:
		print("【ShopManager】金币不足，需要 %d" % discount_price)
		return

	if _deduct_gold(discount_price):
		_purchased_ids.append(item_id)
		print("【ShopManager】购买道具 %s，花费 %d 金币" % [item.get("name", ""), discount_price])
		_refresh_shop_display()


## 投掷折扣骰子回调（由 game_main 处理）
func _on_throw_discount_pressed():
	print("【ShopManager】折扣骰子投掷由 game_main 处理")


## 关闭按钮回调
func _on_close_pressed():
	print("【ShopManager】点击关闭按钮，结束交易")
	close_shop()
	on_trade_completed.emit()


## 前进按钮回调
func _on_advance_pressed():
	print("【ShopManager】点击前进，结束交易")
	close_shop()
	on_trade_completed.emit()

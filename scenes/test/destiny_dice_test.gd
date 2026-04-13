extends Node3D
## 命运骰子测试场景
## 演示如何将命运骰子系统集成到关卡流程中

# 当前关卡数据
var level_data: LevelData = null

# 当前所在节点
var current_node: LevelNode = null

# 命运骰子管理器
var destiny_dice_manager: DestinyDiceManager = null

# 关卡转换控制器
var level_transition_controller: LevelTransitionController = null

# UI 标签（用于显示信息）
var info_label: Label


func _ready():
	print("=== 命运骰子测试场景 ===")

	# 1. 获取管理器实例
	destiny_dice_manager = DestinyDiceManager.get_instance()
	level_transition_controller = LevelTransitionController.get_instance()

	# 2. 初始化关卡数据（从关卡生成器）
	_initialize_level_data()

	# 3. 设置初始节点
	_set_start_node()

	# 4. 创建 UI
	_create_ui()

	# 5. 连接信号
	_connect_signals()

	# 6. 启动命运骰子流程
	call_deferred("_start_destiny_dice_flow")


## 初始化关卡数据
func _initialize_level_data():
	# 从关卡生成器获取生成的关卡数据
	# 注意：这里假设 level_generator 已经生成了关卡
	if level_generator and level_generator.has_method("get_level_data"):
		level_data = level_generator.get_level_data()
		print("关卡数据已加载：", level_data.total_nodes, " 个节点")
	else:
		# 备用方案：创建测试数据
		print("警告：无法从生成器获取关卡数据，创建测试数据")
		level_data = _create_test_level_data()


## 创建测试关卡数据（备用方案）
func _create_test_level_data() -> LevelData:
	var data = LevelData.new(1, 12345)

	# 创建起点
	var start_node = LevelNode.new("1", "起点", 2)
	start_node.is_start = true
	start_node.layer = 0
	data.add_node(start_node)

	# 创建连接的节点
	var node2 = LevelNode.new("2", "战斗 1", 1)
	node2.layer = 1
	data.add_node(node2)

	var node3 = LevelNode.new("3", "奇遇 1", 2)
	node3.layer = 1
	data.add_node(node3)

	var node4 = LevelNode.new("4", "交易 1", 3)
	node4.layer = 1
	data.add_node(node4)

	# 创建连接
	start_node.connections.append("2")
	start_node.connections.append("3")
	start_node.connections.append("4")

	node2.previous_nodes.append("1")
	node3.previous_nodes.append("1")
	node4.previous_nodes.append("1")

	# 创建终点
	var end_node = LevelNode.new("5", "终点", 1)
	end_node.is_end = true
	end_node.layer = 2
	data.add_node(end_node)

	node2.connections.append("5")
	node3.connections.append("5")
	node4.connections.append("5")

	return data


## 设置初始节点
func _set_start_node():
	if level_data and level_data.start_node_id:
		current_node = level_data.get_node(level_data.start_node_id)
		print("初始节点：", current_node.id, " (", current_node.name, ")")
	else:
		push_error("无法找到起始节点")


## 创建 UI
func _create_ui():
	info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.anchors_preset = Control.PRESET_TOP_LEFT
	info_label.position = Vector2(10, 10)
	info_label.size = Vector2(400, 200)
	info_label.text = "命运骰子测试\n\n请稍候..."
	info_label.add_theme_font_size_override("font_size", 16)
	add_child(info_label)

	# 创建投掷按钮
	var throw_button = Button.new()
	throw_button.name = "ThrowButton"
	throw_button.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	throw_button.position = Vector2(-150, -60)
	throw_button.size = Vector2(120, 40)
	throw_button.text = "投掷命运骰子"
	throw_button.add_theme_font_size_override("font_size", 16)
	throw_button.button_down.connect(_on_throw_button_pressed)
	add_child(throw_button)


## 连接信号
func _connect_signals():
	if level_transition_controller:
		if not level_transition_controller.on_transition_started.is_connected(_on_transition_started):
			level_transition_controller.on_transition_started.connect(_on_transition_started)
		if not level_transition_controller.on_transition_completed.is_connected(_on_transition_completed):
			level_transition_controller.on_transition_completed.connect(_on_transition_completed)
		if not level_transition_controller.on_game_clear_triggered.is_connected(_on_game_clear):
			level_transition_controller.on_game_clear_triggered.connect(_on_game_clear)

	if destiny_dice_manager:
		if not destiny_dice_manager.on_config_generated.is_connected(_on_config_generated):
			destiny_dice_manager.on_config_generated.connect(_on_config_generated)


## 启动命运骰子流程
func _start_destiny_dice_flow():
	if not level_transition_controller:
		push_error("关卡转换控制器不存在")
		return

	# 初始化关卡转换控制器
	level_transition_controller.initialize(level_data)
	level_transition_controller.set_current_node(current_node)

	# 启动命运骰子流程
	var success = level_transition_controller.start_destiny_dice_flow(self)
	if success:
		print("命运骰子流程已启动")
		_update_ui("命运骰子已准备，点击按钮投掷")
	else:
		_update_ui("命运骰子流程启动失败")


## 更新 UI
func _update_ui(message: String):
	if info_label:
		info_label.text = "命运骰子测试\n\n" + message + "\n\n当前节点：" + (current_node.name if current_node else "无")


## 投掷按钮按下
func _on_throw_button_pressed():
	print("投掷命运骰子")
	_update_ui("投掷中...")

	if level_transition_controller:
		level_transition_controller.throw_destiny_dice()


## 配置生成完成
func _on_config_generated(config: DestinyDiceConfig):
	print("配置已生成")
	var info = "骰面配置：\n"
	for i in range(6):
		if config.faces.size() > i:
			var face = config.faces[i]
			info += "面%d: %s\n" % [i, config._get_type_name(face.type)]
	_update_ui(info)


## 关卡转换开始
func _on_transition_started(from_node: LevelNode, to_node: LevelNode):
	print("关卡转换开始：", from_node.name, " -> ", to_node.name)
	_update_ui("正在前往：" + to_node.name + "\n\n类型：" + to_node.get_type_name())


## 关卡转换完成
func _on_transition_completed(target_node: LevelNode):
	print("关卡转换完成")
	current_node = target_node
	_update_ui("已到达：" + target_node.name + "\n\n点击按钮继续投掷")

	# 检查是否可以继续投掷
	if target_node.connections.size() == 0:
		_update_ui("已到达终点！\n\n游戏结束")
	else:
		# 继续下一轮投掷
		call_deferred("_start_next_round")


## 开始下一轮投掷
func _start_next_round():
	if level_transition_controller and level_transition_controller.can_throw_again():
		var success = level_transition_controller.start_destiny_dice_flow(self)
		if success:
			_update_ui("下一轮已准备\n\n点击按钮投掷")


## 游戏结算
func _on_game_clear():
	print("游戏通关！")
	_update_ui("=== 游戏通关！===\n\n感谢游玩！")

	# 这里可以触发结算界面或返回主菜单

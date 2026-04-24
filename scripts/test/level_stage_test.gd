extends Node3D
## LevelStage 功能测试场景
## 测试节点网与场景对应功能

# 测试配置
var test_level_data: LevelData = null
var start_node: LevelNode = null

# 地图显示 UI
var map_display: Control = null
var is_map_visible: bool = false

# 命运骰子投掷状态
var is_rolling_destiny_dice: bool = false


func _ready():
	print("=== LevelStage 功能测试 ===")

	# 1. 生成测试关卡数据
	_generate_test_level_data()

	# 2. 初始化 LevelStage（通过 LevelTransitionController）
	var level_transition = LevelTransitionController.get_instance()
	if level_transition:
		level_transition.initialize(test_level_data)
		level_transition.set_current_node(start_node)

		# 3. 触发场景加载测试
		print("\n【测试】开始加载起始节点场景...")
		var level_stage: Node = LevelStage.get_instance()
		if level_stage:
			var success = level_stage.load_level_scene(start_node, test_level_data)
			if success:
				print("【测试】场景加载成功！")
				var loaded_scene = level_stage.get_current_scene()
				print("当前场景：%s" % loaded_scene.name)

				# 激活场景中的摄像机
				var camera = loaded_scene.get_node("Camera3D")
				if camera:
					camera.current = true
					CameraManager.register_camera(camera)
					print("【摄像机】已激活场景中的摄像机")
				else:
					print("【警告】场景中未找到 Camera3D")
			else:
				print("【测试】场景加载失败")

	# 4. 创建地图显示 UI（默认隐藏）
	_create_map_display()

	# 5. 连接关卡转换完成信号（通过 LevelTransitionController 统一处理）
	_connect_transition_signal()

	print("=== 测试完成 ===")


## 生成测试关卡数据
func _generate_test_level_data():
	var seed_value = Time.get_ticks_msec()

	# 通过 LevelGenerator 单例实例调用
	var level_gen = LevelGenerator.get_instance()
	if level_gen:
		test_level_data = level_gen.generate_level(1, seed_value)
		if test_level_data and test_level_data.start_node_id:
			start_node = test_level_data.get_node(test_level_data.start_node_id)
			print("【关卡】生成成功，起始节点：%s (类型：%d)" % [start_node.name, start_node.type])
		else:
			# 创建备用测试数据
			test_level_data = _create_backup_test_data()
			start_node = test_level_data.get_node("1")
			print("【关卡】使用备用测试数据，起始节点：%s" % start_node.name)
	else:
		print("【关卡】LevelGenerator 未找到，使用备用测试数据")
		test_level_data = _create_backup_test_data()
		start_node = test_level_data.get_node("1")


## 创建备用测试数据
func _create_backup_test_data() -> LevelData:
	var data = LevelData.new(1, 12345)

	# 创建起点（战斗类型）
	var start = LevelNode.new("1", "起点·战斗", 1)
	start.is_start = true
	start.layer = 0
	data.add_node(start)

	# 创建节点 2（奇遇类型）
	var node2 = LevelNode.new("2", "奇遇·森林", 2)
	node2.layer = 1
	data.add_node(node2)

	# 创建节点 3（交易类型）
	var node3 = LevelNode.new("3", "交易·集市", 3)
	node3.layer = 1
	data.add_node(node3)

	# 创建终点（奖励类型）
	var end = LevelNode.new("4", "终点·宝藏", 4)
	end.is_end = true
	end.layer = 2
	data.add_node(end)

	# 创建连接
	start.connections.append("2")
	start.connections.append("3")
	node2.connections.append("4")
	node3.connections.append("4")

	print("【关卡】备用测试数据创建成功，共 %d 个节点" % data.total_nodes)
	return data


## 输入处理
func _input(event):
	if event is InputEventKey and event.pressed:
		# 按 M 键开关地图显示
		if event.keycode == KEY_M:
			_toggle_map_display()
		# 按 N 键切换到下一个节点
		elif event.keycode == KEY_N:
			_transition_to_next_node()
		# 按 R 键重新加载当前节点
		elif event.keycode == KEY_R:
			_reload_current_node()
		# 按 T 键投掷命运骰子
		elif event.keycode == KEY_T:
			_throw_destiny_dice()


## 创建地图显示 UI
func _create_map_display():
	var map_scene = load("res://scenes/ui/level_map_display.tscn")
	if map_scene:
		map_display = map_scene.instantiate()
		add_child(map_display)
		map_display.visible = false
		print("【地图 UI】已创建（默认隐藏）")
	else:
		push_error("【地图 UI】无法加载场景")


## 开关地图显示
func _toggle_map_display():
	is_map_visible = not is_map_visible
	if map_display:
		map_display.visible = is_map_visible
		print("【地图 UI】%s" % ("已显示" if is_map_visible else "已隐藏"))


## 连接关卡转换完成信号（通过 LevelTransitionController 统一处理）
func _connect_transition_signal():
	var level_transition = LevelTransitionController.get_instance()
	if level_transition:
		if not level_transition.on_transition_completed.is_connected(_on_transition_completed):
			level_transition.on_transition_completed.connect(_on_transition_completed)
			print("【关卡转换】已连接转换完成信号")


## 投掷命运骰子
func _throw_destiny_dice():
	if is_rolling_destiny_dice:
		print("【命运骰子】正在投掷中...")
		return

	var level_stage: Node = LevelStage.get_instance()
	if not level_stage or not test_level_data:
		push_error("【命运骰子】LevelStage 或关卡数据未初始化")
		return

	var current_node = level_stage.get_current_node()
	if not current_node or current_node.connections.size() == 0:
		print("【命运骰子】当前节点无连接，可能是终点")
		return

	# 需要先初始化命运骰子流程（创建骰子实例）
	var level_transition = LevelTransitionController.get_instance()
	if level_transition:
		# 检查是否已有骰子实例（可能上一轮已创建）
		var destiny_dice_manager = DestinyDiceManager.get_instance()
		if destiny_dice_manager and destiny_dice_manager.destiny_dice_instances.size() == 0:
			# 创建命运骰子
			level_transition.start_destiny_dice_flow(self)

		is_rolling_destiny_dice = true
		print("\n【命运骰子】开始投掷...")
		level_transition.throw_destiny_dice()


## 关卡转换完成回调
func _on_transition_completed(target_node: LevelNode):
	is_rolling_destiny_dice = false
	print("【关卡转换】已完成，当前节点：%s (类型：%d)" % [target_node.name, target_node.type])


## 切换到下一个节点
func _transition_to_next_node():
	var level_stage: Node = LevelStage.get_instance()
	if not level_stage or not test_level_data:
		return

	var current: LevelNode = level_stage.get_current_node()
	if current and current.connections.size() > 0:
		var next_id = current.connections[0]
		var next_node = test_level_data.get_node(next_id)
		if next_node:
			print("\n【测试】切换到节点：%s (类型：%d)" % [next_node.name, next_node.type])
			level_stage.transition_to_node(next_node)


## 重新加载当前节点
func _reload_current_node():
	var level_stage: Node = LevelStage.get_instance()
	if not level_stage:
		return

	var current = level_stage.get_current_node()
	if current:
		print("\n【测试】重新加载节点：%s" % current.name)
		level_stage.load_level_scene(current, test_level_data)

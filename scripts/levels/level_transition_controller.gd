extends Node
## 关卡转换控制器
## 负责处理命运骰子投掷后的关卡选择和场景切换流程
## 注意：此类通过 autoload 注册为全局单例，可直接使用 LevelTransitionController 访问

# 单例实例
static var _instance: Node = null

# 当前关卡数据
var current_level_data: LevelData = null

# 当前所在节点
var current_node: LevelNode = null

# 目标节点（投掷结果选择的节点）
var target_node: LevelNode = null

# 命运骰子管理器引用
var destiny_dice_manager: Node = null

# 信号：关卡转换开始
signal on_transition_started(from_node: LevelNode, to_node: LevelNode)

# 信号：关卡转换完成
signal on_transition_completed(target_node: LevelNode)

# 信号：Boss 战开始
signal on_boss_battle_started(boss_node: LevelNode)

# 信号：结算界面触发
signal on_game_clear_triggered()

# 配置参数
@export var transition_duration: float = 1.0  # 转换动画时长
@export var fade_color: Color = Color(0, 0, 0, 1)  # 淡入淡出颜色


func _ready():
	_instance = self
	print("[LevelTransitionController] 初始化完成")

	# 连接命运骰子管理器信号
	_connect_destiny_dice_signals()


## 获取单例实例
static func get_instance() -> Node:
	return _instance


## 连接命运骰子管理器信号
func _connect_destiny_dice_signals():
	# 延迟获取，确保 DestinyDiceManager 已初始化
	call_deferred("_deferred_connect")


func _deferred_connect():
	destiny_dice_manager = DestinyDiceManager.get_instance()
	if destiny_dice_manager:
		if not destiny_dice_manager.on_destiny_dice_roll_completed.is_connected(_on_destiny_roll_completed):
			destiny_dice_manager.on_destiny_dice_roll_completed.connect(_on_destiny_roll_completed)
		print("[LevelTransitionController] 已连接命运骰子信号")


## 初始化关卡转换控制器
## @param level_data 当前关卡数据
func initialize(level_data: LevelData):
	current_level_data = level_data
	print("[LevelTransitionController] 关卡数据已加载，节点数：", level_data.total_nodes)


## 设置当前节点
func set_current_node(node: LevelNode):
	current_node = node
	print("[LevelTransitionController] 当前节点：", node.id, " (", node.name, ")")


## 开始命运骰子流程
## @param parent 父节点（用于创建骰子）
## @return 是否成功
func start_destiny_dice_flow(parent: Node) -> bool:
	if not current_node:
		push_error("[LevelTransitionController] 当前节点为空")
		return false

	# 检查是否有连接的下一层节点
	if current_node.connections.size() == 0:
		print("[LevelTransitionController] 当前节点无连接，可能是终点")
		# 触发结算
		on_game_clear_triggered.emit()
		return false

	# 初始化命运骰子管理器
	if not destiny_dice_manager:
		destiny_dice_manager = DestinyDiceManager.get_instance()

	if not destiny_dice_manager:
		push_error("[LevelTransitionController] 命运骰子管理器不存在")
		return false

	var success = destiny_dice_manager.initialize(current_node, current_level_data)
	if not success:
		push_error("[LevelTransitionController] 命运骰子初始化失败")
		return false

	# 创建命运骰子实例
	success = destiny_dice_manager.create_destiny_dice(parent)
	if not success:
		push_error("[LevelTransitionController] 命运骰子创建失败")
		return false

	print("[LevelTransitionController] 命运骰子流程已启动")
	return true


## 投掷命运骰子
func throw_destiny_dice():
	if destiny_dice_manager:
		destiny_dice_manager.throw_destiny_dice()


## 处理命运骰子投掷完成（内部回调）
func _on_destiny_roll_completed(selected_node: LevelNode):
	if not selected_node:
		push_error("[LevelTransitionController] 选择的节点为空")
		return

	target_node = selected_node
	print("[LevelTransitionController] 投掷完成，目标节点：", selected_node.id)

	# 发出关卡转换开始信号
	on_transition_started.emit(current_node, selected_node)

	# 检查是否为 Boss 节点
	if _is_boss_node(selected_node):
		print("[LevelTransitionController] 触发 Boss 战")
		on_boss_battle_started.emit(selected_node)
		# Boss 战后可能需要继续投掷，等待 Boss 战完成信号
	else:
		# 普通节点，直接进行关卡转换
		execute_transition()


## 检查是否为 Boss 节点
func _is_boss_node(node: LevelNode) -> bool:
	if node.data.has("boss_id") and not node.data["boss_id"].is_empty():
		return true
	if node.is_end:
		return true
	return false


## 执行关卡转换
func execute_transition():
	if not target_node:
		push_error("[LevelTransitionController] 目标节点为空")
		return

	print("[LevelTransitionController] 开始关卡转换：", current_node.id, " -> ", target_node.id)

	# 1. 更新当前节点
	current_node = target_node

	# 2. 更新命运骰子管理器的当前节点
	if destiny_dice_manager:
		destiny_dice_manager.current_node = current_node

	# 3. 发出转换完成信号
	on_transition_completed.emit(target_node)

	# 4. 清理命运骰子（在转换完成后）
	if destiny_dice_manager:
		destiny_dice_manager.clear_dice_instances()

	print("[LevelTransitionController] 关卡转换完成")


## Boss 战完成后继续
func on_boss_battle_completed():
	print("[LevelTransitionController] Boss 战完成")

	# 检查 Boss 节点后是否还有后续节点
	if current_node and current_node.connections.size() > 0:
		# 还有后续节点，继续投掷
		print("[LevelTransitionController] Boss 战后继续投掷")
		# 注意：这里需要外部调用 start_destiny_dice_flow 来继续
	else:
		# 没有后续节点，触发结算
		print("[LevelTransitionController] Boss 战后无后续，触发结算")
		on_game_clear_triggered.emit()


## 重置控制器
func reset():
	current_node = null
	target_node = null
	print("[LevelTransitionController] 已重置")


## 获取当前节点
func get_current_node() -> LevelNode:
	return current_node


## 获取目标节点
func get_target_node() -> LevelNode:
	return target_node


## 是否可以进行下一次投掷
func can_throw_again() -> bool:
	if not current_node:
		return false
	return current_node.connections.size() > 0

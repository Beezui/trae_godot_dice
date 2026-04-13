extends Node
## 命运骰子管理器
## 负责生成命运骰子配置、管理投掷流程和关卡转换
## 注意：此类通过 autoload 注册为全局单例，可直接使用 DestinyDiceManager 访问
## 依赖：DestinyDiceConfig (scripts/levels/destiny_dice_config.gd)

# 单例实例
static var _instance: Node = null

# 当前命运骰子配置（使用 Variant 避免类型依赖）
var current_config: Variant = null

# 命运骰子实例（RigidBody3D）
var destiny_dice_instances: Array = []

# 当前所在节点
var current_node: LevelNode = null

# 可到达的下一层节点列表
var connected_nodes: Array[LevelNode] = []

# 关卡数据引用
var level_data: LevelData = null

# 信号：投掷完成
signal on_destiny_dice_roll_completed(selected_node: LevelNode)

# 信号：配置生成完成
signal on_config_generated(config: Variant)

# 配置参数
@export var destiny_dice_scene: PackedScene  # 命运骰子场景
@export var dice_count: int = 1  # 命运骰子数量（通常为 1 个）
@export var use_custom_texture: bool = true  # 是否使用自定义贴图


func _ready():
	_instance = self
	print("[DestinyDiceManager] 初始化完成")


## 获取单例实例
static func get_instance() -> Node:
	return _instance


## 初始化命运骰子
## @param p_current_node 当前所在节点
## @param p_level_data 关卡数据引用
func initialize(p_current_node: LevelNode, p_level_data: LevelData = null) -> bool:
	if not p_current_node:
		push_error("[DestinyDiceManager] 当前节点为空")
		return false

	current_node = p_current_node
	level_data = p_level_data

	# 1. 获取连接的下一层节点
	connected_nodes = _get_connected_nodes(p_current_node, p_level_data)

	if connected_nodes.size() == 0:
		print("[DestinyDiceManager] 没有连接的下一层节点，可能是终点")
		return false

	# 2. 生成命运骰子配置（使用 load 动态加载避免依赖问题）
	var config_script = load("res://scripts/levels/destiny_dice_config.gd")
	if not config_script:
		push_error("[DestinyDiceManager] 无法加载 DestinyDiceConfig")
		return false
	current_config = config_script.new()
	var success = current_config.initialize(p_current_node, connected_nodes)

	if not success:
		push_error("[DestinyDiceManager] 配置生成失败")
		return false

	# 3. 发出配置生成完成信号
	on_config_generated.emit(current_config)

	print("[DestinyDiceManager] 命运骰子初始化完成")
	print("  - 当前节点：", current_node.id)
	print("  - 连接节点：", connected_nodes.size())
	print("  - 是否 Boss 战：", current_config.is_boss_battle)

	return true


## 获取连接的下一层节点
func _get_connected_nodes(p_node: LevelNode, p_level_data: LevelData) -> Array[LevelNode]:
	var result: Array[LevelNode] = []

	if not p_node or p_node.connections.size() == 0:
		return result

	# 从关卡数据中获取连接的节点
	if p_level_data:
		for next_node_id in p_node.connections:
			var next_node = p_level_data.get_node(next_node_id)
			if next_node:
				result.append(next_node)
	else:
		# 没有关卡数据，返回空数组
		print("[DestinyDiceManager] 警告：没有关卡数据，无法获取连接节点")

	return result


## 创建命运骰子实例
## @param parent 父节点
## @return 是否创建成功
func create_destiny_dice(parent: Node) -> bool:
	if not current_config:
		push_error("[DestinyDiceManager] 配置未生成")
		return false

	# 清理现有骰子
	clear_dice_instances()

	# 加载命运骰子场景
	if not destiny_dice_scene:
		# 使用默认骰子场景
		destiny_dice_scene = load("res://scenes/dice_6.tscn")
		if not destiny_dice_scene:
			push_error("[DestinyDiceManager] 无法加载骰子场景")
			return false

	# 创建骰子实例
	for i in range(dice_count):
		var dice = destiny_dice_scene.instantiate()
		if not dice:
			push_error("[DestinyDiceManager] 无法实例化骰子")
			return false

		dice.name = "DestinyDice_%d" % i
		parent.add_child(dice)
		destiny_dice_instances.append(dice)

		# 设置骰子位置（居中排列）
		var spacing = 1.5
		var start_x = -((dice_count - 1) * spacing) / 2
		var x_pos = start_x + (i * spacing)
		dice.position = Vector3(x_pos, 6, 4.75)

		# 应用命运骰子贴图
		_apply_destiny_dice_textures(dice)

	print("[DestinyDiceManager] 创建了 ", destiny_dice_instances.size(), " 个命运骰子")
	return true


## 应用命运骰子贴图
func _apply_destiny_dice_textures(dice: RigidBody3D):
	if not current_config:
		return

	print("[DestinyDiceManager] 应用命运骰子贴图")

	# 使用 DiceTextureManager 应用贴图
	if DiceTextureManager:
		DiceTextureManager.apply_textures_to_dice(dice, current_config.dice_face_config)
	else:
		print("[DestinyDiceManager] 错误：DiceTextureManager 不存在")


## 投掷命运骰子
func throw_destiny_dice():
	if destiny_dice_instances.size() == 0:
		push_error("[DestinyDiceManager] 没有骰子可投掷")
		return

	print("[DestinyDiceManager] 投掷命运骰子")

	# 使用 DiceThrowController 进行投掷
	var throw_controller = DiceThrowController.get_instance()
	if throw_controller:
		throw_controller.throw_normal(destiny_dice_instances, 1.0)
	else:
		# 备用方案：直接投掷
		_throw_direct()


## 直接投掷（备用方案）
func _throw_direct():
	for dice in destiny_dice_instances:
		if dice and is_instance_valid(dice):
			var force = Vector3(
				randf_range(-0.5, 0.5),
				randf_range(3, 5),
				randf_range(-2.5, -1.25)
			)
			var angular_force = Vector3(
				randf_range(-7, 7),
				randf_range(-7, 7),
				randf_range(-7, 7)
			)

			if dice.has_method("roll"):
				dice.roll(force, angular_force)
			elif dice.get_class() == "RigidBody3D":
				dice.gravity_scale = 1.0
				dice.linear_velocity = force
				dice.angular_velocity = angular_force


## 获取投掷结果
## @return 面索引（0-5），-1 表示失败
func get_roll_result() -> int:
	if destiny_dice_instances.size() == 0:
		return -1

	# 获取第一个骰子的结果
	var dice = destiny_dice_instances[0]
	if dice and is_instance_valid(dice) and dice.has_method("get_dice_value"):
		var value = dice.get_dice_value()
		# 骰子值转换为面索引（1-6 -> 0-5）
		var face_index = value - 1
		face_index = clamp(face_index, 0, 5)
		return face_index

	return -1


## 处理投掷完成
func on_roll_completed():
	if not current_config:
		return

	# 获取投掷结果
	var face_index = get_roll_result()
	if face_index < 0:
		push_error("[DestinyDiceManager] 无法获取投掷结果")
		return

	# 设置投掷结果
	current_config.set_roll_result(face_index)

	# 选择节点
	var selected_node_id = current_config.select_node_from_result()

	# 发出完成信号
	var selected_node = _get_node_by_id(selected_node_id)
	if selected_node:
		on_destiny_dice_roll_completed.emit(selected_node)
		print("[DestinyDiceManager] 投掷完成，选择节点：", selected_node_id)
	else:
		push_error("[DestinyDiceManager] 无法找到节点：", selected_node_id)


## 根据 ID 获取节点
func _get_node_by_id(node_id: String) -> LevelNode:
	if level_data:
		return level_data.get_node(node_id)
	return null


## 清理骰子实例
func clear_dice_instances():
	for dice in destiny_dice_instances:
		if dice and is_instance_valid(dice):
			dice.queue_free()
	destiny_dice_instances.clear()


## 重置管理器
func reset():
	clear_dice_instances()
	if current_config:
		current_config = null
	current_node = null
	connected_nodes.clear()
	level_data = null
	print("[DestinyDiceManager] 已重置")


## 检查是否为 Boss 战
func is_boss_battle() -> bool:
	return current_config and current_config.is_boss_battle


## 获取 Boss 贴图 ID
func get_boss_texture_id() -> String:
	if current_config:
		return current_config.boss_texture_id
	return ""

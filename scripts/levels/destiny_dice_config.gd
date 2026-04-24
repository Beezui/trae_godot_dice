extends RefCounted
class_name DestinyDiceConfig
## 命运骰子配置数据结构
## 用于存储命运骰子的生成配置和投掷结果映射
## 注意：此类不是 autoload，需要通过 load() 动态加载

# 骰面配置（6 个面）
# 每个面包含：type(类型), node_ids(该类型对应的节点 ID 列表)
var faces: Array[Dictionary] = []

# 当前所在节点 ID
var current_node_id: String = ""

# 当前所在节点数据
var current_node: LevelNode = null

# 是否为 Boss 战
var is_boss_battle: bool = false

# Boss 专属贴图 ID（如果是 Boss 战）
var boss_texture_id: String = ""

# 类型到节点 ID 列表的映射
# 结构：{1: ["101", "102"], 2: ["103"], 3: ["104"], 4: ["105"]}
# 类型：1=战斗，2=奇遇，3=交易，4=奖励，5=精英战斗，99=Boss/终局
var type_to_nodes_map: Dictionary = {}

# 骰子面配置（用于贴图管理器）
# 结构：{"0": "type_1", "1": "type_1", "2": "type_2", ...}
# 或 Boss 战：{"0": "boss_1001", "1": "boss_1001", ...}
var dice_face_config: Dictionary = {}

# 投掷结果映射（投掷后填充）
var roll_result_face_index: int = -1  # 投掷结果对应的面索引
var roll_result_type: int = -1  # 投掷结果对应的类型
var roll_result_node_ids: Array = []  # 该类型对应的所有节点 ID
var selected_node_id: String = ""  # 最终选择的节点 ID（从结果类型中随机选择）


## 构造函数
func _init():
	pass


## 初始化命运骰子配置
## @param current_node 当前所在节点
## @param connected_nodes 从当前节点可到达的下一层节点列表
func initialize(current_node: LevelNode, connected_nodes: Array[LevelNode]) -> bool:
	if not current_node or connected_nodes.size() == 0:
		push_error("[DestinyDiceConfig] 当前节点或连接节点为空")
		return false

	self.current_node = current_node
	self.current_node_id = current_node.id

	# 1. 统计每种类型的节点数量
	type_to_nodes_map.clear()
	for node in connected_nodes:
		var node_type = node.type
		if node_type not in type_to_nodes_map:
			type_to_nodes_map[node_type] = []
		(type_to_nodes_map[node_type] as Array).append(node.id)

	# 2. 检查是否为 Boss 战（所有连接节点都是 Boss 节点）
	is_boss_battle = _check_is_boss_battle(connected_nodes)

	# 3. 计算每种类型应分配的面数
	var type_face_distribution = _calculate_face_distribution(connected_nodes.size())

	# 4. 生成 6 个骰面的配置
	_generate_faces(type_face_distribution)

	# 5. 生成骰子面配置（用于贴图）
	_generate_dice_face_config()

	print("[DestinyDiceConfig] 初始化完成")
	print("  - 当前节点：", current_node_id, " (", current_node.name, ")")
	print("  - 连接节点数：", connected_nodes.size())
	print("  - 类型分布：", type_to_nodes_map)
	print("  - 面数分配：", type_face_distribution)
	print("  - 骰面配置：", faces)

	return true


## 检查是否为 Boss 战
func _check_is_boss_battle(connected_nodes: Array[LevelNode]) -> bool:
	for node in connected_nodes:
		# 检查节点是否是 Boss 节点（通过 data 中的 boss_id 判断）
		if node.data.has("boss_id") and not node.data["boss_id"].is_empty():
			continue
		# 或者检查节点类型是否为终局
		if node.is_end:
			continue
		# 有一个不是 Boss，就不是 Boss 战
		return false
	return connected_nodes.size() > 0


## 计算面数分配
## @param total_connected_nodes 连接的节点总数
## @return Dictionary {类型：面数}
func _calculate_face_distribution(total_connected_nodes: int) -> Dictionary:
	var distribution = {}
	var remaining_faces = 6

	# 1. 计算每种类型的理想面数（向下取整）
	for type_id in type_to_nodes_map.keys():
		var node_count = (type_to_nodes_map[type_id] as Array).size()
		var ratio = float(node_count) / float(total_connected_nodes)
		var faces_count = int(ratio * 6.0)
		faces_count = maxi(1, faces_count)  # 每种类型至少 1 面
		distribution[type_id] = faces_count
		remaining_faces -= faces_count

	# 2. 剩余面数按类型顺序分配
	for type_id in type_to_nodes_map.keys():
		if remaining_faces <= 0:
			break
		distribution[type_id] += 1
		remaining_faces -= 1

	# 3. 验证总面数
	var total_faces = 0
	for type_id in distribution.keys():
		total_faces += distribution[type_id]

	if total_faces != 6:
		push_error("[DestinyDiceConfig] 面数分配错误：总面数=", total_faces, ", 期望=6")

	return distribution


## 生成 6 个骰面
func _generate_faces(distribution: Dictionary):
	faces.clear()

	var face_index = 0
	for type_id in distribution.keys():
		var face_count = distribution[type_id]
		var node_ids = type_to_nodes_map[type_id] as Array

		for i in range(face_count):
			if face_index >= 6:
				break

			var face_data = {
				"face_index": face_index,
				"type": type_id,
				"node_ids": node_ids.duplicate()
			}
			faces.append(face_data)
			face_index += 1


## 生成骰子面配置（用于贴图管理器）
func _generate_dice_face_config():
	dice_face_config.clear()

	for i in range(6):
		if i < faces.size():
			var face_data = faces[i]
			var type_id = face_data["type"]

			if is_boss_battle:
				# Boss 战：使用 Boss 专属贴图
				# 从连接节点中获取第一个 Boss 的 ID
				if type_to_nodes_map.has(1) and (type_to_nodes_map[1] as Array).size() > 0:
					var boss_node_id = (type_to_nodes_map[1] as Array)[0]
					boss_texture_id = boss_node_id  # 使用节点 ID 作为贴图 ID
				dice_face_config[str(i)] = "boss_" + boss_texture_id
			else:
				# 普通关卡：使用类型贴图
				dice_face_config[str(i)] = "destiny_type_" + str(type_id)


## 设置投掷结果
## @param face_index 投掷结果对应的面索引（0-5）
## @return 是否设置成功
func set_roll_result(face_index: int) -> bool:
	if face_index < 0 or face_index >= faces.size():
		push_error("[DestinyDiceConfig] 无效的面索引：", face_index)
		return false

	roll_result_face_index = face_index
	var face_data = faces[face_index]
	roll_result_type = face_data["type"]
	roll_result_node_ids = (face_data["node_ids"] as Array)

	print("[DestinyDiceConfig] 投掷结果：面=", face_index, ", 类型=", _get_type_name(roll_result_type), ", 可选节点=", roll_result_node_ids)

	return true


## 从投掷结果中随机选择一个节点
func select_node_from_result() -> String:
	if roll_result_node_ids.size() == 0:
		push_error("[DestinyDiceConfig] 投掷结果为空")
		return ""

	if roll_result_node_ids.size() == 1:
		selected_node_id = roll_result_node_ids[0]
	else:
		# 从该类型的多个节点中随机选择一个
		var random_idx = randi() % roll_result_node_ids.size()
		selected_node_id = roll_result_node_ids[random_idx]

	print("[DestinyDiceConfig] 选择节点：", selected_node_id)
	return selected_node_id


## 获取类型名称
func _get_type_name(type_id: int) -> String:
	match type_id:
		1: return "战斗"
		2: return "奇遇"
		3: return "交易"
		4: return "奖励"
		5: return "精英战斗"
		99: return "Boss"
		_: return "未知"


## 获取类型颜色
func _get_type_color(type_id: int) -> Color:
	match type_id:
		1: return Color(1, 0.3, 0.3)  # 红色 - 战斗
		2: return Color(0.3, 0.6, 1)  # 蓝色 - 奇遇
		3: return Color(1, 0.8, 0.3)  # 黄色 - 交易
		4: return Color(0.3, 1, 0.5)  # 绿色 - 奖励
		5: return Color(0.8, 0.2, 0.2)  # 深红色 - 精英战斗
		99: return Color(0.5, 0, 0.8)  # 紫色 - Boss
		_: return Color(0.5, 0.5, 0.5)  # 灰色 - 未知


## 转换为字典
func to_dict() -> Dictionary:
	return {
		"faces": faces,
		"current_node_id": current_node_id,
		"is_boss_battle": is_boss_battle,
		"boss_texture_id": boss_texture_id,
		"type_to_nodes_map": type_to_nodes_map,
		"dice_face_config": dice_face_config,
		"roll_result_face_index": roll_result_face_index,
		"roll_result_type": roll_result_type,
		"roll_result_node_ids": roll_result_node_ids,
		"selected_node_id": selected_node_id
	}


## 从字典创建
static func from_dict(dict_data: Dictionary) -> RefCounted:
	var config = _new_instance()
	config.faces = dict_data.get("faces", [])
	config.current_node_id = dict_data.get("current_node_id", "")
	config.is_boss_battle = dict_data.get("is_boss_battle", false)
	config.boss_texture_id = dict_data.get("boss_texture_id", "")
	config.type_to_nodes_map = dict_data.get("type_to_nodes_map", {})
	config.dice_face_config = dict_data.get("dice_face_config", {})
	config.roll_result_face_index = dict_data.get("roll_result_face_index", -1)
	config.roll_result_type = dict_data.get("roll_result_type", -1)
	config.roll_result_node_ids = dict_data.get("roll_result_node_ids", [])
	config.selected_node_id = dict_data.get("selected_node_id", "")
	return config


## 创建新实例（辅助函数）
static func _new_instance() -> RefCounted:
	return RefCounted.new()

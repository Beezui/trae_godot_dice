class_name LevelData
extends RefCounted
## 关卡数据结构
## 用于存储整局游戏的关卡地图信息

# 关卡基本信息
var nodes: Array[LevelNode] = []  # 所有节点列表
var nodes_map: Dictionary = {}  # ID -> LevelNode 的快速查找表
var start_node_id: String = ""  # 起始节点 ID
var end_node_ids: Array[String] = []  # 所有终点节点 ID 列表

# 生成参数
var total_nodes: int = 0  # 总节点数
var core_node_count: int = 0  # 核心节点数量
var random_node_count: int = 0  # 随机节点数量
var difficulty: int = 1  # 难度等级
var seed_value: int = 0  # 随机种子
var target_total: int = 35  # 目标总节点数（30 + 难度*5）

# 路径信息
var all_paths: Array = []  # 所有可能的路径列表
var longest_path: Array = []  # 最长路径
var shortest_path: Array = []  # 最短路径

# 路径查找保护
const MAX_PATH_COUNT = 1000  # 最大路径数量限制
const MAX_RECURSION_DEPTH = 500  # 最大递归深度

# 验证状态
var is_valid: bool = false  # 是否通过验证
var validation_errors: Array[String] = []  # 验证错误信息


## 构造函数
func _init(p_difficulty: int = 1, p_seed: int = 0):
	difficulty = p_difficulty
	seed_value = p_seed
	target_total = 30 + difficulty * 5


## 添加节点
func add_node(node: LevelNode) -> void:
	if node == null:
		return
	nodes.append(node)
	nodes_map[node.id] = node
	if node.is_start:
		start_node_id = node.id
	if node.is_end:
		if node.id not in end_node_ids:
			end_node_ids.append(node.id)
	if node.is_core:
		core_node_count += 1
	else:
		random_node_count += 1
	total_nodes = nodes.size()


## 根据 ID 获取节点
func get_node(node_id: String) -> LevelNode:
	if nodes_map.has(node_id):
		return nodes_map[node_id]
	return null


## 清除所有数据
func clear() -> void:
	nodes.clear()
	nodes_map.clear()
	start_node_id = ""
	end_node_ids.clear()
	all_paths.clear()
	longest_path.clear()
	shortest_path.clear()
	validation_errors.clear()
	is_valid = false
	total_nodes = 0
	core_node_count = 0
	random_node_count = 0


## 查找所有路径（DFS）
func find_all_paths() -> void:
	all_paths.clear()
	if start_node_id == "":
		push_error("[LevelData] 起始节点 ID 为空")
		return
	
	var current_path: Array[String] = []
	_dfs_find_paths(start_node_id, current_path)
	
	# 找出最长和最短路径
	if all_paths.size() > 0:
		longest_path = all_paths[0]
		shortest_path = all_paths[0]
		for path in all_paths:
			if path.size() > longest_path.size():
				longest_path = path
			if path.size() < shortest_path.size():
				shortest_path = path


## DFS 查找所有路径
func _dfs_find_paths(current_id: String, current_path: Array[String], depth: int = 0) -> void:
	# 递归深度保护
	if depth > MAX_RECURSION_DEPTH:
		push_warning("[LevelData] 达到最大递归深度，停止搜索")
		return
	
	# 路径数量保护
	if all_paths.size() >= MAX_PATH_COUNT:
		push_warning("[LevelData] 达到最大路径数量限制 (", MAX_PATH_COUNT, ")，停止搜索")
		return
	
	current_path.append(current_id)
	var node = get_node(current_id)
	
	if node == null:
		current_path.pop_back()
		return
	
	# 如果是终点节点，保存路径
	if node.is_end or node.connections.size() == 0:
		all_paths.append(current_path.duplicate())
	else:
		# 继续深度优先搜索
		for next_id in node.connections:
			# 避免循环路径
			if next_id not in current_path:
				_dfs_find_paths(next_id, current_path, depth + 1)
	
	current_path.pop_back()


## 验证所有路径
func validate() -> bool:
	validation_errors.clear()
	is_valid = true
	
	# 1. 检查是否有起始节点
	if start_node_id == "":
		validation_errors.append("缺少起始节点")
		is_valid = false
	
	# 2. 检查是否有终点节点
	if end_node_ids.size() == 0:
		validation_errors.append("缺少终点节点")
		is_valid = false
	
	# 3. 查找所有路径
	find_all_paths()
	
	# 4. 检查是否所有路径都包含起点和终点
	for path in all_paths:
		if path.size() == 0:
			continue
		if path[0] != start_node_id:
			validation_errors.append("路径不包含起始节点：" + str(path))
			is_valid = false
		if path[-1] not in end_node_ids:
			validation_errors.append("路径不包含终点节点：" + str(path))
			is_valid = false
	
	# 5. 检查路径长度是否在允许范围内（±10%）
	var min_allowed = int(target_total * 0.9)
	var max_allowed = int(target_total * 1.1)
	for path in all_paths:
		if path.size() < min_allowed or path.size() > max_allowed:
			validation_errors.append(
				"路径长度超出范围：" + str(path.size()) + 
				" (目标：" + str(target_total) + 
				", 允许：" + str(min_allowed) + "-" + str(max_allowed) + ")"
			)
			is_valid = false
	
	# 6. 检查是否有循环路径（已在 DFS 中避免）
	
	return is_valid


## 计算节点层级（用于可视化布局）
func calculate_layers() -> void:
	if start_node_id == "":
		return
	
	# 使用 BFS 计算每个节点的层级
	var queue: Array[String] = [start_node_id]
	var visited: Dictionary = {}
	visited[start_node_id] = true
	
	var start_node = get_node(start_node_id)
	if start_node:
		start_node.layer = 0
	
	while queue.size() > 0:
		var current_id = queue.pop_front()
		var current_node = get_node(current_id)
		if current_node == null:
			continue
		
		for next_id in current_node.connections:
			if not visited.has(next_id):
				visited[next_id] = true
				var next_node = get_node(next_id)
				if next_node:
					next_node.layer = current_node.layer + 1
				queue.append(next_id)


## 获取某一层的所有节点
func get_nodes_by_layer(layer: int) -> Array[LevelNode]:
	var result: Array[LevelNode] = []
	for node in nodes:
		if node.layer == layer:
			result.append(node)
	return result


## 获取最大层级
func get_max_layer() -> int:
	var max_layer = 0
	for node in nodes:
		if node.layer > max_layer:
			max_layer = node.layer
	return max_layer


## 转换为字典（用于序列化）
func to_dict() -> Dictionary:
	var nodes_data = []
	for node in nodes:
		nodes_data.append(node.to_dict())
	
	return {
		"nodes": nodes_data,
		"start_node_id": start_node_id,
		"end_node_ids": end_node_ids,
		"total_nodes": total_nodes,
		"core_node_count": core_node_count,
		"random_node_count": random_node_count,
		"difficulty": difficulty,
		"seed_value": seed_value,
		"target_total": target_total,
		"all_paths": all_paths,
		"longest_path": longest_path,
		"shortest_path": shortest_path,
		"is_valid": is_valid,
		"validation_errors": validation_errors
	}


## 从字典创建关卡数据
static func from_dict(dict_data: Dictionary) -> LevelData:
	var level = LevelData.new()
	level.start_node_id = dict_data.get("start_node_id", "")
	level.end_node_ids = Array(dict_data.get("end_node_ids", []))
	level.total_nodes = dict_data.get("total_nodes", 0)
	level.core_node_count = dict_data.get("core_node_count", 0)
	level.random_node_count = dict_data.get("random_node_count", 0)
	level.difficulty = dict_data.get("difficulty", 1)
	level.seed_value = dict_data.get("seed_value", 0)
	level.target_total = dict_data.get("target_total", 35)
	level.all_paths = Array(dict_data.get("all_paths", []))
	level.longest_path = Array(dict_data.get("longest_path", []))
	level.shortest_path = Array(dict_data.get("shortest_path", []))
	level.is_valid = dict_data.get("is_valid", false)
	level.validation_errors = Array(dict_data.get("validation_errors", []))
	
	# 恢复节点
	if dict_data.has("nodes"):
		for node_dict in dict_data["nodes"]:
			var node = LevelNode.from_dict(node_dict)
			level.add_node(node)
	
	return level


## 打印调试信息
func print_debug_info() -> void:
	print("====================")
	print("[LevelData] 关卡数据")
	print("====================")
	print("难度：", difficulty)
	print("种子：", seed_value)
	print("目标总量：", target_total)
	print("实际总量：", total_nodes)
	print("核心节点：", core_node_count)
	print("随机节点：", random_node_count)
	print("起始节点：", start_node_id)
	print("终点节点：", end_node_ids)
	print("路径数量：", all_paths.size())
	if longest_path.size() > 0:
		print("最长路径：", longest_path.size(), " - ", longest_path)
	if shortest_path.size() > 0:
		print("最短路径：", shortest_path.size(), " - ", shortest_path)
	print("验证状态：", "通过" if is_valid else "失败")
	if validation_errors.size() > 0:
		print("验证错误：")
		for error in validation_errors:
			print("  - ", error)
	print("====================")

class_name LevelValidator
extends RefCounted
## 关卡验证器
## 负责验证生成的关卡地图是否合法
##
## 验证职责划分：
## - LevelData.validate(): 基础数据完整性检查（起点、终点、连通性）
## - LevelValidator.validate(): 完整的游戏规则验证（路径长度、节点分布、阶段收敛等）

var config: Dictionary = {}

# 验证配置常量
const MIN_PATH_LENGTH_RATIO = 0.8  # 最短路径长度比例（相对于目标）
const MAX_PATH_LENGTH_RATIO = 1.2  # 最长路径长度比例
const MAX_CONSECUTIVE_SAME_TYPE = 5  # 最大连续同类型节点数
const MAX_REWARD_TRADE_RATIO = 0.5  # 奖励/交易节点最大比例


## 构造函数
func _init(p_config: Dictionary = {}):
	config = p_config
	if config.is_empty():
		config = {
			"min_path_length_ratio": MIN_PATH_LENGTH_RATIO,
			"max_path_length_ratio": MAX_PATH_LENGTH_RATIO,
			"max_consecutive_same_type": MAX_CONSECUTIVE_SAME_TYPE,
			"max_reward_trade_ratio": MAX_REWARD_TRADE_RATIO
		}


## 验证关卡数据（完整验证）
func validate(level_data: LevelData) -> bool:
	level_data.validation_errors.clear()
	level_data.is_valid = true

	# 1. 先执行基础验证（调用 LevelData.validate）
	if not level_data.validate():
		for error in level_data.validation_errors:
			if error not in level_data.validation_errors:
				level_data.validation_errors.append(error)
		if not level_data.is_valid:
			return false

	# 2. 查找所有路径（如果还没找）
	if level_data.all_paths.size() == 0:
		level_data.find_all_paths()

	# 3. 检查路径长度（相对于目标和最大层级）
	if not _validate_path_lengths(level_data):
		level_data.is_valid = false

	# 4. 检查循环路径
	if _has_cycle(level_data):
		level_data.validation_errors.append("检测到循环路径")
		level_data.is_valid = false

	# 5. 验证节点类型分布
	if not _validate_node_types(level_data):
		level_data.is_valid = false

	# 6. 验证核心节点类型（只能是战斗或奇遇）
	if not _validate_core_node_types(level_data):
		level_data.is_valid = false

	# 7. 验证阶段收敛性
	if not _validate_stage_convergence(level_data):
		level_data.is_valid = false

	return level_data.is_valid


## 验证路径长度
func _validate_path_lengths(level_data: LevelData) -> bool:
	var min_allowed = int(level_data.target_total * config.get("min_path_length_ratio", MIN_PATH_LENGTH_RATIO))
	var max_allowed = int(level_data.target_total * config.get("max_path_length_ratio", MAX_PATH_LENGTH_RATIO))

	# 同时使用最大层级作为参考
	var max_layer = level_data.get_max_layer()
	var layer_based_min = int(max_layer * 0.3)
	var layer_based_max = int(max_layer * 1.2)

	# 取更宽松的范围
	min_allowed = mini(min_allowed, layer_based_min)
	max_allowed = maxi(max_allowed, layer_based_max)

	var valid_path_found = false
	for path in level_data.all_paths:
		if path.size() >= min_allowed and path.size() <= max_allowed:
			valid_path_found = true
			break

	if not valid_path_found:
		level_data.validation_errors.append(
			"没有路径在允许范围内：需要至少一条路径长度在 " +
			str(min_allowed) + "-" + str(max_allowed) +
			" (目标：" + str(level_data.target_total) +
			", 最大层数：" + str(max_layer) + ", 总节点数：" + str(level_data.total_nodes) + ")"
		)
		return false

	return true


## 检查是否有循环路径
func _has_cycle(level_data: LevelData) -> bool:
	var visited: Dictionary = {}
	var rec_stack: Dictionary = {}
	
	for node in level_data.nodes:
		visited[node.id] = false
		rec_stack[node.id] = false
	
	for node in level_data.nodes:
		if visited.has(node.id) and not visited[node.id]:
			if _dfs_cycle(node.id, level_data, visited, rec_stack):
				return true
	
	return false


## DFS 检测循环
func _dfs_cycle(
	node_id: String, 
	level_data: LevelData, 
	visited: Dictionary, 
	rec_stack: Dictionary
) -> bool:
	# 确保键存在
	if not visited.has(node_id):
		visited[node_id] = false
	if not rec_stack.has(node_id):
		rec_stack[node_id] = false
	
	visited[node_id] = true
	rec_stack[node_id] = true
	
	var node = level_data.get_node(node_id)
	if node == null:
		return false
	
	for next_id in node.connections:
		# 确保下一个节点的键存在
		if not visited.has(next_id):
			visited[next_id] = false
		if not rec_stack.has(next_id):
			rec_stack[next_id] = false
		
		if not visited[next_id]:
			if _dfs_cycle(next_id, level_data, visited, rec_stack):
				return true
		elif rec_stack[next_id]:
			return true
	
	rec_stack[node_id] = false
	return false


## 验证节点类型分布
func _validate_node_types(level_data: LevelData) -> bool:
	var valid = true
	
	# 检查所有路径
	for path in level_data.all_paths:
		# 只检查主路径（长度在允许范围内的路径）
		var min_allowed = int(level_data.target_total * 0.9)
		var max_allowed = int(level_data.target_total * 1.1)
		
		if path.size() < min_allowed or path.size() > max_allowed:
			continue  # 跳过分支/捷径路径
		
		var consecutive_count = 0
		var last_type = -1
		var reward_trade_count = 0
		
		for node_id in path:
			var node = level_data.get_node(node_id)
			if node == null:
				continue
			
			# 检查连续同类型节点（最多允许 5 个连续）
			if node.type == last_type:
				consecutive_count += 1
				if consecutive_count > 5:
					level_data.validation_errors.append(
						"检测到过多连续同类型节点（>" + str(consecutive_count) + " 个）"
					)
					valid = false
			else:
				consecutive_count = 1
				last_type = node.type
			
			# 检查奖励/交易节点比例（不超过 30%）
			if node.type == 3 or node.type == 4:
				reward_trade_count += 1
		
		# 检查奖励/交易节点比例
		if path.size() > 0:
			var ratio = float(reward_trade_count) / float(path.size())
			if ratio > 0.5:  # 不超过 50%
				level_data.validation_errors.append(
					"奖励/交易节点比例过高：" + str(ratio)
				)
				valid = false
	
	return valid


## 验证核心节点类型
func _validate_core_node_types(level_data: LevelData) -> bool:
	var valid = true

	for node in level_data.nodes:
		if node.is_core:
			# 核心节点只能是战斗（1）或奇遇（2）
			if node.type != 1 and node.type != 2:
				level_data.validation_errors.append(
					"核心节点类型错误：" + node.id + " 类型为 " + str(node.type)
				)
				valid = false

	return valid


## 验证每个阶段路径收敛到终局节点
func _validate_stage_convergence(level_data: LevelData) -> bool:
	var valid = true
	
	# 找出所有阶段节点（Boss节点和终局节点）
	var stage_end_nodes: Array[String] = []
	
	for node in level_data.nodes:
		# Boss节点（layer >= 50）或终局节点（is_end = true）
		if node.layer >= 50 or node.is_end:
			stage_end_nodes.append(node.id)
	
	if stage_end_nodes.size() == 0:
		level_data.validation_errors.append("没有找到阶段终局节点")
		return false
	
	# 验证每条路径是否都到达某个阶段终局节点
	for path in level_data.all_paths:
		if path.size() == 0:
			continue
		
		var end_node_id = path[-1]
		
		# 检查路径终点是否是阶段终局节点
		var is_valid_end = false
		for end_id in stage_end_nodes:
			if end_node_id == end_id:
				is_valid_end = true
				break
		
		if not is_valid_end:
			level_data.validation_errors.append(
				"路径未到达阶段终局节点：路径 " + str(path) + " 终点 " + str(end_node_id)
			)
			valid = false
	
	return valid


## 验证节点连接完整性
func validate_connections(level_data: LevelData) -> bool:
	var valid = true
	
	for node in level_data.nodes:
		# 检查连接是否都指向存在的节点
		for next_id in node.connections:
			if level_data.get_node(next_id) == null:
				level_data.validation_errors.append(
					"节点 " + node.id + " 连接到不存在的节点：" + next_id
				)
				valid = false
		
		# 检查反向连接
		for prev_id in node.previous_nodes:
			if level_data.get_node(prev_id) == null:
				level_data.validation_errors.append(
					"节点 " + node.id + " 被不存在的节点指向：" + prev_id
				)
				valid = false
	
	return valid


## 打印验证报告
func print_validation_report(level_data: LevelData) -> void:
	print("====================")
	print("[LevelValidator] 验证报告")
	print("====================")
	print("验证状态：", "通过" if level_data.is_valid else "失败")
	print("路径数量：", level_data.all_paths.size())
	
	if level_data.validation_errors.size() > 0:
		print("\n错误列表:")
		for error in level_data.validation_errors:
			print("  - ", error)
	else:
		print("\n无错误")
	
	print("====================")

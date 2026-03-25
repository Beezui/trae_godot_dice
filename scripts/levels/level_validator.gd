class_name LevelValidator
extends RefCounted
## 关卡验证器
## 负责验证生成的关卡地图是否合法

var config: Dictionary = {}


## 构造函数
func _init(p_config: Dictionary = {}):
	config = p_config


## 验证关卡数据
func validate(level_data: LevelData) -> bool:
	level_data.validation_errors.clear()
	level_data.is_valid = true
	
	# 1. 检查是否有起始节点
	if level_data.start_node_id == "":
		level_data.validation_errors.append("缺少起始节点")
		level_data.is_valid = false
	
	# 2. 检查是否有终点节点
	if level_data.end_node_ids.size() == 0:
		level_data.validation_errors.append("缺少终点节点")
		level_data.is_valid = false
	
	# 3. 查找所有路径
	level_data.find_all_paths()
	
	# 4. 检查路径合法性
	for path in level_data.all_paths:
		if path.size() == 0:
			continue
		
		# 检查是否包含起始节点
		if path[0] != level_data.start_node_id:
			level_data.validation_errors.append("路径不包含起始节点：" + str(path))
			level_data.is_valid = false
		
		# 检查是否包含终点节点
		if path[-1] not in level_data.end_node_ids:
			level_data.validation_errors.append("路径不包含终点节点：" + str(path))
			level_data.is_valid = false
	
	# 5. 检查路径长度
	# 只要求至少有一条路径在允许范围内（±10%），允许分支/捷径存在
	var min_allowed = int(level_data.target_total * 0.9)
	var max_allowed = int(level_data.target_total * 1.1)
	var valid_path_found = false
	
	for path in level_data.all_paths:
		if path.size() >= min_allowed and path.size() <= max_allowed:
			valid_path_found = true
			break
	
	if not valid_path_found:
		level_data.validation_errors.append(
			"没有路径在允许范围内：需要至少一条路径长度在 " + 
			str(min_allowed) + "-" + str(max_allowed) + " 之间"
		)
		level_data.is_valid = false
	
	# 6. 检查是否有循环路径
	if _has_cycle(level_data):
		level_data.validation_errors.append("检测到循环路径")
		level_data.is_valid = false
	
	# 7. 检查节点类型分布
	if not _validate_node_types(level_data):
		level_data.is_valid = false
	
	# 8. 检查核心节点仅包含战斗和奇遇
	if not _validate_core_node_types(level_data):
		level_data.is_valid = false
	
	return level_data.is_valid


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

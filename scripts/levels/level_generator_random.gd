class_name LevelGeneratorRandom
extends RefCounted
## 随机节点生成器
## 负责在核心节点之间插入随机节点

var random_nodes_config: Array = []  # 随机节点配置列表
var scenes_config: Array = []  # 场景配置列表
var config: Dictionary = {}  # 生成配置


## 构造函数
func _init(p_config: Dictionary = {}):
	config = p_config
	if config.is_empty():
		config = {
			"min_random_between_core": 1,
			"max_random_between_core": 3,
			"avoid_consecutive_reward_trade": true,
			"max_consecutive_same_type": 2
		}


## 加载配置文件
func load_configs() -> Error:
	# 加载 random_nodes.json
	var file = FileAccess.open("res://table/random_nodes.json", FileAccess.READ)
	if file == null:
		push_error("[LevelGeneratorRandom] 无法打开 random_nodes.json")
		return FileAccess.get_open_error()
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[LevelGeneratorRandom] 解析 random_nodes.json 失败：", json.get_error_message())
		return ERR_PARSE_ERROR
	
	var data = json.get_data()
	if data is Dictionary and data.has("random_nodes"):
		random_nodes_config = data["random_nodes"]
	else:
		push_error("[LevelGeneratorRandom] random_nodes.json 格式错误")
		return ERR_INVALID_DATA
	
	# 加载 scenes.json
	var scenes_file = FileAccess.open("res://table/scenes.json", FileAccess.READ)
	if scenes_file == null:
		return FileAccess.get_open_error()
	
	json_text = scenes_file.get_as_text()
	scenes_file.close()
	
	parse_result = json.parse(json_text)
	if parse_result != OK:
		return ERR_PARSE_ERROR
	
	data = json.get_data()
	if data is Dictionary and data.has("scenes"):
		scenes_config = data["scenes"]
	
	print("[LevelGeneratorRandom] 配置加载成功")
	print("  - 随机节点配置：", random_nodes_config.size(), " 个")
	
	return OK


## 在核心节点链中插入随机节点
func insert_random_nodes(
	core_chain: Array[LevelNode], 
	target_total: int,
	seed_value: int = 0
) -> Array[LevelNode]:
	if seed_value > 0:
		seed(seed_value)
	
	var full_chain: Array[LevelNode] = []
	var random_count_needed = target_total - core_chain.size()
	var consecutive_type_count = 0
	var last_type = -1
	
	print("[LevelGeneratorRandom] 需要插入随机节点：", random_count_needed, " 个")
	
	# 随机节点计数器，用于生成唯一 ID
	var random_node_counter = 1
	
	# 插入随机节点到核心节点链中
	for i in range(core_chain.size()):
		var core_node = core_chain[i]
		full_chain.append(core_node)
		last_type = core_node.type
		consecutive_type_count = 1
		
		# 在两个核心节点之间插入随机节点
		if i < core_chain.size() - 1:
			# 计算这个间隙应该插入的数量
			var remaining_core = core_chain.size() - i - 1  # 剩余核心节点数
			
			# 计算当前间隙应该插入的节点数
			# 剩余随机节点数 / 剩余间隙数
			var remaining_slots = remaining_core
			var avg_per_slot = 0
			if remaining_slots > 0 and random_count_needed > 0:
				avg_per_slot = int(float(random_count_needed) / float(remaining_slots))
			
			# 当前间隙至少插入 1 个，最多插入剩余数量
			var count = maxi(1, avg_per_slot)
			count = mini(count, random_count_needed)
			
			print("  在核心节点 ", core_node.id, " 后插入 ", count, " 个随机节点")
			
			for j in range(count):
				var random_node = _pick_random_node(last_type, consecutive_type_count)
				if random_node:
					random_node.is_core = false
					# 生成唯一的 ID，使用 R 前缀避免与核心节点冲突
					random_node.id = "R" + str(random_node_counter)
					random_node_counter += 1
					random_node.previous_nodes.append(full_chain[-1].id)
					full_chain.append(random_node)
					
					# 更新连续类型计数
					if random_node.type == last_type:
						consecutive_type_count += 1
					else:
						consecutive_type_count = 1
						last_type = random_node.type
					
					random_count_needed -= 1
	
	# 如果还有剩余的随机节点，全部插入到最后一个节点之后
	if random_count_needed > 0:
		print("  在最后一个节点后额外插入 ", random_count_needed, " 个随机节点")
		for j in range(random_count_needed):
			var random_node = _pick_random_node(last_type, consecutive_type_count)
			if random_node:
				random_node.is_core = false
				# 生成唯一的 ID，使用 R 前缀避免与核心节点冲突
				random_node.id = "R" + str(random_node_counter)
				random_node_counter += 1
				random_node.previous_nodes.append(full_chain[-1].id)
				full_chain.append(random_node)
				
				if random_node.type == last_type:
					consecutive_type_count += 1
				else:
					consecutive_type_count = 1
					last_type = random_node.type
	
	print("[LevelGeneratorRandom] 随机节点插入完成，总节点数：", full_chain.size())
	
	return full_chain


## 根据权重随机选择节点
func _pick_random_node(last_type: int = -1, consecutive_count: int = 0) -> LevelNode:
	if random_nodes_config.size() == 0:
		return null
	
	# 计算总权重
	var total_weight = 0.0
	for config_item in random_nodes_config:
		total_weight += config_item.get("weight", 1.0)
	
	if total_weight <= 0:
		return null
	
	# 随机选择一个权重位置
	var rand_weight = randf() * total_weight
	var current_weight = 0.0
	
	# 过滤不合适的节点（避免连续同类型）
	var valid_configs = []
	for config_item in random_nodes_config:
		var node_type = config_item.get("type", 1)
		
		# 检查是否违反连续类型限制
		if config.get("avoid_consecutive_reward_trade", true):
			# 避免连续奖励或交易节点
			if (node_type == 3 or node_type == 4) and last_type == node_type:
				continue
		
		# 检查最大连续同类型限制
		var max_consecutive = config.get("max_consecutive_same_type", 2)
		if node_type == last_type and consecutive_count >= max_consecutive:
			continue
		
		valid_configs.append(config_item)
	
	if valid_configs.size() == 0:
		valid_configs = random_nodes_config
	
	# 重新计算有效配置的总权重
	total_weight = 0.0
	for config_item in valid_configs:
		total_weight += config_item.get("weight", 1.0)
	
	rand_weight = randf() * total_weight
	current_weight = 0.0
	
	for config_item in valid_configs:
		current_weight += config_item.get("weight", 1.0)
		if rand_weight <= current_weight:
			return _create_node_from_config(config_item)
	
	# 默认返回第一个
	return _create_node_from_config(valid_configs[0])


## 从配置创建节点
func _create_node_from_config(config_item: Dictionary) -> LevelNode:
	var node = LevelNode.new()
	node.load_from_dict(config_item)
	
	# 补充场景路径信息
	var scene_id = config_item.get("scene", "")
	if scene_id != "":
		var scene_config = _find_scene_by_id(scene_id)
		if scene_config.has("path"):
			node.data["scene_path"] = "res://scenes/游戏场景/" + scene_config["path"] + ".tscn"
	
	return node


## 根据 ID 查找场景配置
func _find_scene_by_id(scene_id: String) -> Dictionary:
	for scene in scenes_config:
		if scene.get("id") == scene_id:
			return scene
	return {}


## 清空配置
func clear() -> void:
	random_nodes_config.clear()
	scenes_config.clear()
	config.clear()

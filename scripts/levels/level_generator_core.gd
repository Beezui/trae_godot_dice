class_name LevelGeneratorCore
extends RefCounted
## 核心节点生成器
## 负责动态生成网状多分支关卡结构（不使用 core_nodes.json）

var boss_config: Array = []  # Boss 配置列表
var scenes_config: Array = []  # 场景配置列表
var config: Dictionary = {}   # 生成配置

# 每个阶段的目标层级数
const LAYERS_PER_STAGE_MIN = 15
const LAYERS_PER_STAGE_MAX = 20

# 每层节点数范围
const NODES_PER_LAYER_MIN = 2
const NODES_PER_LAYER_MAX = 6


## 构造函数
func _init(p_config: Dictionary = {}):
	config = p_config


## 加载配置文件
func load_configs() -> Error:
	# 加载 boss.json
	var boss_file = FileAccess.open("res://table/boss.json", FileAccess.READ)
	if boss_file == null:
		push_error("[LevelGeneratorCore] 无法打开 boss.json")
		return FileAccess.get_open_error()
	
	var json_text = boss_file.get_as_text()
	boss_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[LevelGeneratorCore] 解析 boss.json 失败")
		return ERR_PARSE_ERROR
	
	var data = json.get_data()
	if data is Dictionary and data.has("bosses"):
		boss_config = data["bosses"]
	
	# 加载 scenes.json
	var scenes_file = FileAccess.open("res://table/scenes.json", FileAccess.READ)
	if scenes_file == null:
		push_error("[LevelGeneratorCore] 无法打开 scenes.json")
		return FileAccess.get_open_error()
	
	json_text = scenes_file.get_as_text()
	scenes_file.close()
	
	parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[LevelGeneratorCore] 解析 scenes.json 失败")
		return ERR_PARSE_ERROR
	
	data = json.get_data()
	if data is Dictionary and data.has("scenes"):
		scenes_config = data["scenes"]
	
	return OK


## 生成核心节点骨架（网状结构）
func generate_core_chain(target_total: int, difficulty: int = 1, seed_value: int = 0) -> Array[LevelNode]:
	if seed_value > 0:
		seed(seed_value)
	
	var core_chain: Array[LevelNode] = []
	
	# 1. 确定阶段数（根据难度）
	var stage_count = _calculate_stage_count(difficulty)
	# var stage_count = 1  # 临时简化为 1 个阶段
	
	# 2. 生成每个阶段
	var current_node_id = 1
	var previous_stage_end_nodes: Array[LevelNode] = []
	var global_layer_counter = 0  # 全局层级计数器
	
	for stage in range(stage_count):
		var is_first_stage = (stage == 0)
		var is_last_stage = (stage == stage_count - 1)
		
		# 每个阶段层级数（15-20 层）
		var stage_layer_count = randi_range(LAYERS_PER_STAGE_MIN, LAYERS_PER_STAGE_MAX)
		# var stage_layer_count = 5  # 临时简化为 5 层
		print("[LevelGeneratorCore] === 阶段 ", stage + 1, ": ", stage_layer_count, "层 (全局层：", global_layer_counter + 1, "-", global_layer_counter + stage_layer_count, ") ===")
		
		# 本阶段节点
		var stage_nodes: Array[LevelNode] = []
		
		if is_first_stage:
			# 第一阶段：创建起点
			var start_node = _create_start_node(current_node_id)
			stage_nodes.append(start_node)
			current_node_id += 1
			previous_stage_end_nodes = [start_node]
		
		# 生成每层的节点（15-20 层，每层 2-6 个节点）
		for layer in range(stage_layer_count):
			# 使用全局层级编号
			var global_layer = global_layer_counter + layer + 1
			# 每层节点数在 2-6 之间浮动
			var nodes_in_layer = randi_range(NODES_PER_LAYER_MIN, NODES_PER_LAYER_MAX)
			
			for i in range(nodes_in_layer):
				var node = _create_layer_node(current_node_id, stage + 1, global_layer)
				stage_nodes.append(node)
				current_node_id += 1
		
		# 更新全局层级计数器
		global_layer_counter += stage_layer_count
		
		# 连接层级（1 对 3 或 3 对 1，允许跨 1 层）
		_connect_layers_with_cross(stage_nodes, is_first_stage, previous_stage_end_nodes)
		
		# 添加到总链
		for node in stage_nodes:
			core_chain.append(node)
		
		# 找到本阶段终点节点
		var stage_end_nodes = _find_stage_end_nodes(stage_nodes, is_last_stage)
		
		if not is_last_stage:
			# 添加 Boss 节点作为阶段终点
			# Boss 的 layer 应该是本阶段最后一个普通节点的 layer+1
			var boss_layer = global_layer_counter  # 本阶段最后一层的 layer 值
			var boss_node = _create_boss_node(current_node_id, stage + 1, difficulty, boss_layer)
			core_chain.append(boss_node)
			current_node_id += 1
			
			# 连接本阶段最后节点到 Boss
			for end_node in stage_end_nodes:
				end_node.connections.append(boss_node.id)
				boss_node.previous_nodes.append(end_node.id)
			
			previous_stage_end_nodes = [boss_node]
		else:
			# 最后一阶段：添加终点
			var end_node = _create_final_node(current_node_id, stage + 1)
			core_chain.append(end_node)
			current_node_id += 1
			
			for end_node_stage in stage_end_nodes:
				end_node_stage.connections.append(end_node.id)
				end_node.previous_nodes.append(end_node_stage.id)
	
	print("[LevelGeneratorCore] 核心节点链生成完成，共 ", core_chain.size(), " 个节点")
	
	# 打印所有节点的 layer 值，用于调试
	print("\n[LevelGeneratorCore] 所有节点的 layer 值：")
	for node in core_chain:
		print("  节点#", node.id, " (", node.name, ") layer=", node.layer)
	
	# 打印连接信息
	var total_connections = 0
	for node in core_chain:
		total_connections += node.connections.size()
	print("\n[LevelGeneratorCore] 总连接数：", total_connections)
	
	# 验证：检查是否有同层连接
	var same_layer_connections = _check_same_layer_connections(core_chain)
	if same_layer_connections > 0:
		push_error("[LevelGeneratorCore] ❌ 检测到 ", same_layer_connections, " 个同层连接！")
	else:
		print("[LevelGeneratorCore] ✓ 无同层连接")
	
	return core_chain


## 计算阶段数（3-4 个）
func _calculate_stage_count(difficulty: int) -> int:
	return 3 if difficulty < 3 else 4


## 创建起点节点
func _create_start_node(node_id: int) -> LevelNode:
	var node = LevelNode.new()
	node.id = str(node_id)
	node.name = "起始点"
	node.type = 2  # 奇遇类型
	node.is_core = true
	node.is_start = true
	node.is_end = false
	node.layer = 0
	node.connections = [] as Array[String]
	node.previous_nodes = [] as Array[String]
	return node


## 创建层级节点
func _create_layer_node(node_id: int, stage: int, layer: int) -> LevelNode:
	var node = LevelNode.new()
	node.id = str(node_id)
	node.name = "阶段" + str(stage) + "-" + str(layer)
	node.type = randi_range(1, 2)  # 战斗或奇遇
	node.is_core = true
	node.is_start = false
	node.is_end = false
	node.layer = layer
	node.connections = [] as Array[String]
	node.previous_nodes = [] as Array[String]
	return node


## 创建终点节点
func _create_final_node(node_id: int, stage: int) -> LevelNode:
	var node = LevelNode.new()
	node.id = str(node_id)
	node.name = "终局"
	node.type = 1  # 战斗类型
	node.is_core = true
	node.is_start = false
	node.is_end = true
	node.layer = 100
	node.connections = [] as Array[String]
	node.previous_nodes = [] as Array[String]
	return node


## 创建 Boss 节点
func _create_boss_node(node_id: int, stage: int, difficulty: int, boss_layer: int) -> LevelNode:
	var valid_bosses: Array = []
	for boss in boss_config:
		if boss.get("level", 0) == stage and boss.get("difficulty", 0) <= difficulty:
			valid_bosses.append(boss)
	
	if valid_bosses.size() == 0:
		valid_bosses = boss_config
	
	var boss = _pick_boss_by_weight(valid_bosses)
	
	var node = LevelNode.new()
	node.id = str(node_id)
	node.name = "BOSS-" + (boss.get("name", "Boss") if boss else "Boss")
	node.type = 1  # 战斗类型
	node.is_core = true
	node.is_start = false
	node.is_end = false
	node.layer = boss_layer  # Boss 在本阶段的最后一层
	node.connections = [] as Array[String]
	node.previous_nodes = [] as Array[String]
	
	node.data["boss_id"] = boss.get("id", "") if boss else ""
	node.data["hero_id"] = boss.get("hero_id", "") if boss else ""
	node.data["scene_id"] = boss.get("scene_id", "") if boss else ""
	
	return node


## 按权重随机选择 Boss
func _pick_boss_by_weight(bosses: Array) -> Dictionary:
	if bosses.size() == 0:
		return {}
	
	var total_weight = 0.0
	for boss in bosses:
		total_weight += boss.get("weight", 1.0)
	
	var rand_weight = randf() * total_weight
	var current_weight = 0.0
	
	for boss in bosses:
		current_weight += boss.get("weight", 1.0)
		if rand_weight <= current_weight:
			return boss
	
	return bosses[0]


## 连接各层级（排序无交叉算法）
func _connect_layers_with_cross(nodes: Array[LevelNode], is_first_stage: bool, previous_stage_end_nodes: Array[LevelNode] = []):
	print("\n[LevelGeneratorCore] === 开始连接层级（排序无交叉算法）===")
	
	var layers_dict = {}
	for node in nodes:
		var layer = node.layer
		if layer not in layers_dict:
			layers_dict[layer] = [] as Array[LevelNode]
		(layers_dict[layer] as Array[LevelNode]).append(node)
	
	var layers = layers_dict.keys()
	layers.sort()
	
	print("[LevelGeneratorCore] 共有 ", layers.size(), " 个层级")
	
	# 打印每层的节点
	for layer in layers:
		var layer_nodes = layers_dict[layer] as Array[LevelNode]
		var node_info = []
		for n in layer_nodes:
			node_info.append("节点#" + n.id + "(" + n.name + ",层" + str(n.layer) + ")")
		print("  层", layer, ": ", node_info)
	
	# 特殊处理：起点节点（layer=0）连接到所有第 1 层节点
	if 0 in layers_dict and 1 in layers_dict:
		var start_nodes = layers_dict[0] as Array[LevelNode]
		var layer1_nodes = layers_dict[1] as Array[LevelNode]
		
		if start_nodes.size() == 1:  # 确保只有一个起点
			var start_node = start_nodes[0]
			print("\n[LevelGeneratorCore] --- 起点连接到所有第 1 层节点 ---")
			
			# 起点连接到所有第 1 层节点
			for layer1_node in layer1_nodes:
				if not layer1_node.id in start_node.connections:
					start_node.connections.append(layer1_node.id)
					layer1_node.previous_nodes.append(start_node.id)
					print("  起点 -> 节点#", layer1_node.id, " (", layer1_node.name, ")")
			
			# 从第 1 层开始继续连接后续层级
			for i in range(1, layers.size() - 1):
				var current_layer = layers[i]
				var next_layer = layers[i + 1]
				var current_nodes = layers_dict[current_layer] as Array[LevelNode]
				var next_nodes = layers_dict[next_layer] as Array[LevelNode]
				
				print("\n[LevelGeneratorCore] --- 连接层", current_layer, " -> 层", next_layer, " ---")
				_connect_two_layers_sorted(current_nodes, next_nodes, current_layer, next_layer)
		else:
			push_error("❌ 起点节点数量不为 1：", start_nodes.size())
			# 使用普通连接逻辑
			_connect_all_layers_sequentially(layers_dict, layers)
	elif previous_stage_end_nodes.size() > 0:
		# 非第一阶段：前一个阶段的 Boss 连接到本阶段的第 1 层
		var first_layer = layers[0]
		var first_layer_nodes = layers_dict[first_layer] as Array[LevelNode]
		
		print("\n[LevelGeneratorCore] --- 前阶段 Boss 连接到本阶段第", first_layer, "层 ---")
		
		# Boss 连接到本阶段所有第 1 层节点
		for boss_node in previous_stage_end_nodes:
			for layer_node in first_layer_nodes:
				if not layer_node.id in boss_node.connections:
					boss_node.connections.append(layer_node.id)
					layer_node.previous_nodes.append(boss_node.id)
					print("  Boss 节点#", boss_node.id, " -> 节点#", layer_node.id, " (层", first_layer, ")")
		
		# 连接本阶段后续层级
		for i in range(0, layers.size() - 1):
			var current_layer = layers[i]
			var next_layer = layers[i + 1]
			var current_nodes = layers_dict[current_layer] as Array[LevelNode]
			var next_nodes = layers_dict[next_layer] as Array[LevelNode]
			
			print("\n[LevelGeneratorCore] --- 连接层", current_layer, " -> 层", next_layer, " ---")
			_connect_two_layers_sorted(current_nodes, next_nodes, current_layer, next_layer)
	else:
		# 没有起点节点，使用普通连接逻辑
		_connect_all_layers_sequentially(layers_dict, layers)
	
	# 跨层级连接（暂时禁用，因为随机选择会破坏顺序导致交叉）
	# 如果需要跨层连接，必须使用顺序分配而不是随机选择
	if false and layers.size() >= 3:
		print("\n[LevelGeneratorCore] --- 跨层级连接（虚拟空白节点） ---")
		for i in range(layers.size() - 2):
			var current_layer = layers[i]
			var skip_layer = layers[i + 2]
			var current_nodes = layers_dict[current_layer] as Array[LevelNode]
			var skip_nodes = layers_dict[skip_layer] as Array[LevelNode]
			var middle_layer = layers[i + 1]
			var middle_nodes = layers_dict[middle_layer] as Array[LevelNode]
			
			if current_nodes.size() == 0 or skip_nodes.size() == 0:
				continue
			
			# 跨层连接：只有当中层节点存在时才允许跨层
			# 模拟：从 current_nodes 连接到 skip_nodes，视为通过 middle_nodes 的"空白节点"
			# 每个中层节点最多允许 1 个跨层连接通过
			var cross_connections_added = 0
			var max_cross_connections = maxi(1, middle_nodes.size() / 2)  # 最多允许中层节点数的一半
			
			for middle_node in middle_nodes:
				if cross_connections_added >= max_cross_connections:
					break
				
				# 随机选择一个当前层节点和一个跳过层节点
				var from_node = current_nodes[randi() % current_nodes.size()]
				var to_node = skip_nodes[randi() % skip_nodes.size()]
				
				# 避免重复连接
				if not to_node.id in from_node.connections:
					from_node.connections.append(to_node.id)
					to_node.previous_nodes.append(from_node.id)
					print("  跨层连接（通过层", middle_layer, "）: 节点#", from_node.id, " -> 节点#", to_node.id)
					cross_connections_added += 1


## 通用逐层连接（用于非标准情况）
func _connect_all_layers_sequentially(layers_dict: Dictionary, layers: Array):
	for i in range(layers.size() - 1):
		var current_layer = layers[i]
		var next_layer = layers[i + 1]
		var current_nodes = layers_dict[current_layer] as Array[LevelNode]
		var next_nodes = layers_dict[next_layer] as Array[LevelNode]
		
		print("\n[LevelGeneratorCore] --- 连接层", current_layer, " -> 层", next_layer, " ---")
		_connect_two_layers_sorted(current_nodes, next_nodes, current_layer, next_layer)


## 连接两层节点（随机偏移区间分配算法）
## 核心思路：在保证不交叉的前提下增加随机性，打破对称性
func _connect_two_layers_sorted(from_nodes: Array[LevelNode], to_nodes: Array[LevelNode], from_layer: int, to_layer: int):
	if from_nodes.size() == 0 or to_nodes.size() == 0:
		return
	
	# 验证：确保不是同一层
	if from_layer == to_layer:
		push_error("❌ 尝试连接同一层的节点！层号：", from_layer)
		return
	
	print("    连接层", from_layer, " (", from_nodes.size(), "个节点) -> 层", to_layer, " (", to_nodes.size(), "个节点)")
	
	var total_from = from_nodes.size()
	var total_to = to_nodes.size()
	
	# 1. 始终从上到下连接（保持物理位置一致，避免交叉）
	var ordered_from_nodes = from_nodes.duplicate()
	
	# 2. 核心算法：带随机偏移的顺序区间分配
	# 原则：
	# - 每个 from_node 连接连续的 to_node 区间
	# - 区间之间不重叠（除了共享边界）
	# - 确保所有 to_node 都被覆盖
	# - 添加随机偏移打破对称性
	
	# 3. 计算每个 from_node 应该连接几个 to_node
	var connections_per_from = []
	if total_from <= total_to:
		# from 少 to 多：平均分配，每个 from 连接多个连续的 to
		var base = total_to / total_from
		var extra = total_to % total_from
		for i in range(total_from):
			var count = base + (1 if i < extra else 0)
			connections_per_from.append(maxi(1, count))
	else:
		# from 多 to 少：每个 from 只连接 1 个 to，多个 from 共享 to
		# 将 from_nodes 平均分配到 to_nodes 上
		var from_per_to = []
		var remaining_from = total_from
		
		for t in range(total_to):
			var count = ceil(float(remaining_from) / (total_to - t))
			count = mini(count, remaining_from)
			from_per_to.append(maxi(1, count))
			remaining_from -= count
		
		# 为每个 from 分配对应的 to 索引
		var to_assign_index = 0
		var assigned_count = 0
		for t in range(total_to):
			var count = from_per_to[t]
			for f in range(count):
				if assigned_count < total_from:
					connections_per_from.append(1)  # 每个 from 连接 1 个 to
					assigned_count += 1
	
	# 4. 添加随机偏移（打破对称性的关键）
	# 随机偏移量：0 到 total_to/3 之间，确保不会偏移太多导致交叉
	var random_offset = 0
	if total_to >= 3:
		# 允许小幅度随机偏移
		random_offset = randi() % (total_to / 3 + 1)
	
	# 5. 按顺序分配 to_node 区间（带随机偏移）
	var to_index = random_offset
	var from_assigned_to_current_to = 0  # 当前 to 已经分配了几个 from
	var current_to_from_limit = 0  # 当前 to 最多分配几个 from
	
	if total_from > total_to:
		# 计算第一个 to 应该分配几个 from
		current_to_from_limit = ceil(float(total_from) / total_to)
	
	# 6. 添加连接模式随机性（进一步打破对称性）
	# 小概率跳过某些连接，让路径更自然
	var skip_chance = 0.1  # 10% 的概率跳过连接
	
	for i in range(total_from):
		var from_node = ordered_from_nodes[i]
		var count = connections_per_from[i]
		
		print("      节点#", from_node.id, " (层", from_layer, ") 连接 ", count, " 个目标节点:")
		
		for j in range(count):
			if to_index < total_to:
				# 随机跳过（但确保每个节点至少有一个连接）
				var should_skip = (randf() < skip_chance) and (j < count - 1) and (i < total_from - 1)
				
				if not should_skip:
					var to_node = to_nodes[to_index]
					if not to_node.id in from_node.connections:
						from_node.connections.append(to_node.id)
						to_node.previous_nodes.append(from_node.id)
						print("        -> 连接到节点#", to_node.id, " (层", to_layer, ") ✓")
					
					# 计算是否需要移动到下一个 to_node
					if total_from <= total_to:
						# from 少 to 多：每个 from 连接多个 to，每次连接后移动
						to_index += 1
					else:
						# from 多 to 少：每个 to 被多个 from 共享
						from_assigned_to_current_to += 1
						
						# 如果当前 to 已达到分配数量，移动到下一个
						if from_assigned_to_current_to >= current_to_from_limit:
							to_index += 1
							from_assigned_to_current_to = 0
							
							# 计算下一个 to 的分配数量
							if to_index < total_to:
								var remaining_from_count = total_from - (i + 1)
								var remaining_to_count = total_to - to_index
								if remaining_to_count > 0:
									current_to_from_limit = ceil(float(remaining_from_count) / remaining_to_count)
									current_to_from_limit = maxi(1, current_to_from_limit)
				else:
					# 跳过当前连接，直接移动到下一个 to_node
					if total_from <= total_to:
						to_index += 1
			else:
				# to_index 已超出范围，连接到最后一个 to_node
				var to_node = to_nodes[total_to - 1]
				if not to_node.id in from_node.connections:
					from_node.connections.append(to_node.id)
					to_node.previous_nodes.append(from_node.id)
					print("        -> 连接到节点#", to_node.id, " (层", to_layer, ") ✓")
	
	# 6. 确保所有 to_node 都被连接（补充连接）
	# 检查是否有 to_node 没有被任何 from_node 连接
	for i in range(total_to):
		var to_node = to_nodes[i]
		if to_node.previous_nodes.size() == 0:
			# 这个 to_node 没有被连接，补充连接到最后一个 from_node
			var last_from_node = ordered_from_nodes[ordered_from_nodes.size() - 1]
			if not to_node.id in last_from_node.connections:
				last_from_node.connections.append(to_node.id)
				to_node.previous_nodes.append(last_from_node.id)
				print("        -> 补充连接到节点#", to_node.id, " (层", to_layer, ") ✓")


## 查找阶段终点节点
func _find_stage_end_nodes(nodes: Array[LevelNode], is_last_stage: bool) -> Array[LevelNode]:
	var max_layer = 0
	for node in nodes:
		if node.layer > max_layer:
			max_layer = node.layer
	
	var end_nodes: Array[LevelNode] = []
	for node in nodes:
		if node.layer == max_layer:
			end_nodes.append(node)
	return end_nodes


## 检查同层连接（用于验证）
func _check_same_layer_connections(nodes: Array[LevelNode]) -> int:
	var count = 0
	var nodes_map = {}
	for node in nodes:
		nodes_map[node.id] = node
	
	for node in nodes:
		for next_id in node.connections:
			var next_node = nodes_map.get(next_id) as LevelNode
			if next_node and next_node.layer == node.layer:
				count += 1
				push_error("❌ 同层连接：节点#", node.id, " (层", node.layer, ", 名：", node.name, ") -> 节点#", next_id, " (层", next_node.layer, ", 名：", next_node.name, ")")
	
	if count > 0:
		push_error("❌ 共发现 ", count, " 个同层连接")
		# 打印所有节点的层级分布，帮助调试
		var layer_dict = {}
		for node in nodes:
			if node.layer not in layer_dict:
				layer_dict[node.layer] = []
			layer_dict[node.layer].append(node.id)
		
		push_error("层级分布详情：")
		var sorted_layers = layer_dict.keys()
		sorted_layers.sort()
		for layer in sorted_layers:
			var node_ids = layer_dict[layer]
			if node_ids.size() > 1:
				push_error("  层", layer, ": ", node_ids.size(), " 个节点 (ID: ", ", ".join(node_ids), ")")
	
	return count


## 获取 Boss 配置列表
func get_boss_config() -> Array:
	return boss_config


## 清空配置
func clear() -> void:
	boss_config.clear()
	scenes_config.clear()
	config.clear()

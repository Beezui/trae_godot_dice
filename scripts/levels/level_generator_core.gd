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

	# 2. 生成每个阶段
	var current_node_id = 1
	var previous_stage_end_nodes: Array[LevelNode] = []
	var global_layer_counter = 0  # 全局层级计数器

	for stage in range(stage_count):
		var is_first_stage = (stage == 0)
		var is_last_stage = (stage == stage_count - 1)

		# 每个阶段层级数（15-20 层）
		var stage_layer_count = randi_range(LAYERS_PER_STAGE_MIN, LAYERS_PER_STAGE_MAX)

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
		# 增强随机性：完全随机，不再使用正弦函数平滑过渡
		for layer in range(stage_layer_count):
			# 使用全局层级编号
			var global_layer = global_layer_counter + layer + 1

			# 完全随机：每层节点数在 2-6 之间独立随机
			var nodes_in_layer = randi_range(NODES_PER_LAYER_MIN, NODES_PER_LAYER_MAX)

			for i in range(nodes_in_layer):
				var node = _create_layer_node(current_node_id, stage + 1, global_layer)
				stage_nodes.append(node)
				current_node_id += 1

		# 更新全局层级计数器
		global_layer_counter += stage_layer_count

		# 连接层级
		_connect_layers_with_cross(stage_nodes, is_first_stage, previous_stage_end_nodes)

		# 添加到总链
		for node in stage_nodes:
			core_chain.append(node)

		# 找到本阶段终点节点（普通节点的最大层）
		var stage_end_nodes = _find_stage_end_nodes(stage_nodes, is_last_stage)

		if not is_last_stage:
			# 添加 Boss 节点作为阶段终点 - Boss 单独一层
			var boss_layer = global_layer_counter + 1  # Boss 在新的独立层
			var boss_node = _create_boss_node(current_node_id, stage + 1, difficulty, boss_layer)
			core_chain.append(boss_node)
			current_node_id += 1

			# 连接本阶段最后节点到 Boss
			for end_node in stage_end_nodes:
				end_node.connections.append(boss_node.id)
				boss_node.previous_nodes.append(end_node.id)

			# Boss 作为下一阶段的起点
			previous_stage_end_nodes = [boss_node]
			# 更新全局层级计数器（包含 Boss 层）
			global_layer_counter += 1
		else:
			# 最后一阶段：添加终点
			var end_node = _create_final_node(current_node_id, stage + 1)
			core_chain.append(end_node)
			current_node_id += 1

			for end_node_stage in stage_end_nodes:
				end_node_stage.connections.append(end_node.id)
				end_node.previous_nodes.append(end_node_stage.id)

	print("[LevelGeneratorCore] 核心节点链生成完成，共 ", core_chain.size(), " 个节点")

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
	node.type = _get_node_type_for_layer(stage, layer)  # 根据阶段和层级计算节点类型
	node.is_core = true
	node.is_start = false
	node.is_end = false
	node.layer = layer
	node.connections = [] as Array[String]
	node.previous_nodes = [] as Array[String]
	return node


## 根据阶段和层级计算节点类型（带随机种子）
## 返回：1=战斗，2=奇遇，3=交易，4=奖励
func _get_node_type_for_layer(stage: int, layer: int) -> int:
	# 使用阶段和层级作为随机种子，保证同一位置始终生成相同类型
	seed(stage * 1000 + layer)

	# 基础概率分布（可根据设计调整）：
	# 战斗：45%  (主要玩法)
	# 奇遇：30%  (剧情/事件)
	# 交易：15%  (商店/补给)
	# 奖励：10%  (奖励/宝藏)
	var rand = randf()

	if rand < 0.45:
		return 1  # 战斗
	elif rand < 0.75:
		return 2  # 奇遇
	elif rand < 0.90:
		return 3  # 交易
	else:
		return 4  # 奖励


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


## 通用逐层连接（用于非标准情况）
func _connect_all_layers_sequentially(layers_dict: Dictionary, layers: Array):
	for i in range(layers.size() - 1):
		var current_layer = layers[i]
		var next_layer = layers[i + 1]
		var current_nodes = layers_dict[current_layer] as Array[LevelNode]
		var next_nodes = layers_dict[next_layer] as Array[LevelNode]

		print("\n[LevelGeneratorCore] --- 连接层", current_layer, " -> 层", next_layer, " ---")
		_connect_two_layers_sorted(current_nodes, next_nodes, current_layer, next_layer)


## 连接两层节点（重构版：保证不交叉的区间分配）
## 核心原则：
## 1. 按节点 ID 排序（保证顺序一致）
## 2. 每个 from 连接一个连续的 to 区间
## 3. 区间起点严格递增（不交叉的关键）
## 4. 允许区间邻接或轻微重叠（在边界处形成多对一）
## 5. 添加随机性：区间长度浮动
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

	# 1. 按节点 ID 排序（保证顺序一致）
	var ordered_from_nodes = from_nodes.duplicate()
	var ordered_to_nodes = to_nodes.duplicate()
	ordered_from_nodes.sort_custom(func(a, b): return int(a.id) < int(b.id))
	ordered_to_nodes.sort_custom(func(a, b): return int(a.id) < int(b.id))

	# 2. 计算每个 from 的理想连接数
	var avg_connections = float(total_to) / float(total_from)

	# 3. 分配区间：严格不交叉算法（参考算法推导.txt）
	# 核心原则：
	#   - 顺序分配：每个 from 连接连续的 to 区间
	#   - 关键约束：from_i 的第一个连接点 = from_{i-1} 的最后一个连接点 或 其 +1
	#   - 这样保证：如果 from 按 ID 排序，to 也按 ID 排序，则不会交叉
	#
	# 算法步骤：
	#   1. 计算 k = total_to / total_from（平均每 from 连接几个 to）
	#   2. 随机选择起始方向（顺序或倒序，这里用顺序）
	#   3. 依次分配：from_i 连接 [start, start+count)，其中 start = from_{i-1} 的 end 或 end-1（重叠）
	#   4. 保证每个 from 至少连接 1 个，每个 to 至少被连接 1 次

	var from_connections: Array[Dictionary] = []
	var to_coverage: Array[int] = []
	for t in range(total_to):
		to_coverage.append(0)

	# 计算平均连接数 k
	var k = float(total_to) / float(total_from)
	var current_idx = 0  # 当前分配起点

	for i in range(total_from):
		var remaining_from = total_from - i
		var remaining_to = total_to - current_idx

		# 计算这个 from 应该连接的 to 数量
		var count: int
		if remaining_from == 1:
			# 最后一个 from：连接所有剩余的 to
			count = maxi(1, remaining_to)
		else:
			# 其他 from：根据 k 值随机，但要给后面留足够的 to
			var min_needed = remaining_from - 1  # 后面每个 from 至少需要 1 个
			var max_allowed = remaining_to - min_needed
			max_allowed = maxi(1, max_allowed)

			var min_count = maxi(1, int(k * 0.5))
			var max_count = int(k * 1.5)
			if max_count < min_count:
				max_count = min_count
			if max_count > max_allowed:
				max_count = max_allowed

			count = randi_range(min_count, max_count)
			count = maxi(1, count)

		# 计算区间
		var start_idx = current_idx
		var end_idx = mini(total_to, start_idx + count)

		# 确保至少连接一个
		if end_idx <= start_idx:
			if start_idx < total_to:
				end_idx = start_idx + 1
			else:
				# 没有剩余的 to 了，必须重叠
				start_idx = maxi(0, total_to - 1)
				end_idx = total_to

		from_connections.append({
			"from_idx": i,
			"start_idx": start_idx,
			"end_idx": end_idx,
			"count": end_idx - start_idx
		})

		for t in range(start_idx, end_idx):
			to_coverage[t] += 1

		# 更新下一个起点：通常前进，小概率重叠 1 个形成多对一
		if i < total_from - 1:
			if end_idx < total_to:
				if randf() < 0.3:
					# 重叠 1 个：从 end_idx - 1 开始
					current_idx = maxi(0, end_idx - 1)
				else:
					# 前进：从 end_idx 开始
					current_idx = end_idx
			else:
				# 已经到末尾了，后面的 from 必须重叠
				current_idx = total_to - 1

	# 4. 检查是否有未覆盖的 to（补充连接）
	var uncovered_to = []
	for t in range(total_to):
		if to_coverage[t] == 0:
			uncovered_to.append(t)

	if uncovered_to.size() > 0:
		# 将所有未覆盖的 to 分配给最后一个 from 节点
		var last_conn_idx = from_connections.size() - 1
		var last_conn = from_connections[last_conn_idx]
		var last_from_node = ordered_from_nodes[last_conn["from_idx"]]

		for t in uncovered_to:
			if t < 0 or t >= total_to:
				continue

			if t >= last_conn["end_idx"]:
				# 在最后一个区间之后：扩展最后一个区间
				last_conn["end_idx"] = t + 1
				last_conn["count"] = last_conn["end_idx"] - last_conn["start_idx"]
				to_coverage[t] = 1
				if last_from_node.id not in ordered_to_nodes[t].connections:
					last_from_node.connections.append(ordered_to_nodes[t].id)
					ordered_to_nodes[t].previous_nodes.append(last_from_node.id)
			else:
				# 在最后一个区间之前：找到能覆盖它的 from
				for conn_idx in range(from_connections.size() - 1, -1, -1):
					var conn = from_connections[conn_idx]
					if t < conn["start_idx"]:
						conn["start_idx"] = t
						conn["count"] = conn["end_idx"] - conn["start_idx"]
						to_coverage[t] = 1
						var from_node = ordered_from_nodes[conn["from_idx"]]
						if from_node.id not in ordered_to_nodes[t].connections:
							from_node.connections.append(ordered_to_nodes[t].id)
							ordered_to_nodes[t].previous_nodes.append(from_node.id)
						break

	# 重新计算 to_coverage（因为扩展可能覆盖了多个）
	for t in range(total_to):
		to_coverage[t] = 0
	for conn in from_connections:
		for t in range(conn["start_idx"], conn["end_idx"]):
			if t < total_to:
				to_coverage[t] += 1

	# 5. 执行连接
	var connections_made = 0

	print("      分配区间：")
	for conn in from_connections:
		var from_node = ordered_from_nodes[conn["from_idx"]]
		var connected_to = []

		for t in range(conn["start_idx"], conn["end_idx"]):
			if t >= total_to:
				break
			var to_node = ordered_to_nodes[t]
			if to_node.id not in from_node.connections:
				from_node.connections.append(to_node.id)
				to_node.previous_nodes.append(from_node.id)
				connected_to.append(to_node.id)
				connections_made += 1

		print("        节点#", from_node.id, " -> [", conn["start_idx"], "-", conn["end_idx"], "] = {", ", ".join(connected_to), "} (一对", connected_to.size(), ")")

	# 7. 打印连接统计
	var one_to_one = 0
	var one_to_multi = 0
	var multi_to_one_count = 0

	for conn in from_connections:
		if conn["count"] == 1:
			one_to_one += 1
		else:
			one_to_multi += 1

	for c in to_coverage:
		if c > 1:
			multi_to_one_count += 1

	print("      连接统计：一对一=", one_to_one, " 一对多=", one_to_multi, " 多对一=", multi_to_one_count)
	print("      本层连接总数：", connections_made)


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

class_name LevelGeneratorCore
extends RefCounted
## 核心节点生成器
## 负责从配置文件中加载并生成核心节点骨架

var core_nodes_config: Array = []  # 核心节点配置列表
var scenes_config: Array = []  # 场景配置列表
var config: Dictionary = {}  # 生成配置


## 构造函数
func _init(p_config: Dictionary = {}):
	config = p_config
	if config.is_empty():
		# 使用默认配置
		config = {
			"core_node_ratio": 0.35,
			"min_random_between_core": 1,
			"max_random_between_core": 3
		}


## 加载配置文件
func load_configs() -> Error:
	# 加载 core_nodes.json
	var core_nodes_file = FileAccess.open("res://table/core_nodes.json", FileAccess.READ)
	if core_nodes_file == null:
		push_error("[LevelGeneratorCore] 无法打开 core_nodes.json")
		return FileAccess.get_open_error()
	
	var json_text = core_nodes_file.get_as_text()
	core_nodes_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[LevelGeneratorCore] 解析 core_nodes.json 失败：", json.get_error_message())
		return ERR_PARSE_ERROR
	
	var data = json.get_data()
	if data is Dictionary and data.has("core_nodes"):
		core_nodes_config = data["core_nodes"]
	else:
		push_error("[LevelGeneratorCore] core_nodes.json 格式错误")
		return ERR_INVALID_DATA
	
	# 加载 scenes.json
	var scenes_file = FileAccess.open("res://table/scenes.json", FileAccess.READ)
	if scenes_file == null:
		push_error("[LevelGeneratorCore] 无法打开 scenes.json")
		return FileAccess.get_open_error()
	
	json_text = scenes_file.get_as_text()
	scenes_file.close()
	
	parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[LevelGeneratorCore] 解析 scenes.json 失败：", json.get_error_message())
		return ERR_PARSE_ERROR
	
	data = json.get_data()
	if data is Dictionary and data.has("scenes"):
		scenes_config = data["scenes"]
	else:
		push_error("[LevelGeneratorCore] scenes.json 格式错误")
		return ERR_INVALID_DATA
	
	print("[LevelGeneratorCore] 配置加载成功")
	print("  - 核心节点配置：", core_nodes_config.size(), " 个")
	print("  - 场景配置：", scenes_config.size(), " 个")
	
	return OK


## 生成核心节点骨架
func generate_core_chain(target_total: int, seed_value: int = 0) -> Array[LevelNode]:
	if seed_value > 0:
		seed(seed_value)
	
	var core_chain: Array[LevelNode] = []
	
	# 1. 找到起始节点
	var start_nodes = _find_start_nodes()
	if start_nodes.size() == 0:
		push_error("[LevelGeneratorCore] 未找到起始节点")
		return core_chain
	
	# 随机选择一个起始节点
	var start_config = start_nodes[randi() % start_nodes.size()]
	var start_node = _create_node_from_config(start_config)
	start_node.is_core = true
	core_chain.append(start_node)
	
	# 2. 构建核心节点链
	var current_config = start_config
	var max_iterations = 100  # 防止无限循环
	var iterations = 0
	
	while iterations < max_iterations:
		iterations += 1
		
		# 如果是终点节点，停止
		if current_config.get("is_end", false):
			break
		
		# 从 next 中随机选择一个
		var next_ids = current_config.get("next", [])
		if next_ids.size() == 0:
			break
		
		var next_id = next_ids[randi() % next_ids.size()]
		var next_config = _find_node_by_id(next_id)
		
		if next_config == null:
			push_warning("[LevelGeneratorCore] 未找到节点配置：", next_id)
			break
		
		# 创建节点
		var next_node = _create_node_from_config(next_config)
		next_node.is_core = true
		next_node.previous_nodes.append(current_config["id"])
		core_chain.append(next_node)
		
		# 更新当前节点
		current_config = next_config
	
	print("[LevelGeneratorCore] 核心节点链生成完成，共 ", core_chain.size(), " 个节点")
	
	return core_chain


## 查找所有起始节点
func _find_start_nodes() -> Array:
	var result = []
	for config in core_nodes_config:
		if config.get("is_start", false):
			result.append(config)
	return result


## 根据 ID 查找节点配置
func _find_node_by_id(node_id: String) -> Dictionary:
	for config in core_nodes_config:
		if config.get("id") == node_id:
			return config
	return {}


## 从配置创建节点
func _create_node_from_config(config: Dictionary) -> LevelNode:
	var node = LevelNode.new()
	node.load_from_dict(config)
	
	# 补充场景路径信息
	var scene_id = config.get("scene", "")
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


## 获取核心节点配置列表
func get_core_nodes_config() -> Array:
	return core_nodes_config


## 清空配置
func clear() -> void:
	core_nodes_config.clear()
	scenes_config.clear()
	config.clear()

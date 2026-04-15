class_name LevelSceneConfig
extends Node
## 关卡场景配置管理器
## 负责读取 random_nodes.json 和 scenes.json，根据节点类型随机选择场景配置

## 配置数据
var random_nodes_config: Array = []  # random_nodes.json 数据
var scenes_config: Dictionary = {}    # scenes.json 数据 (id -> scene 映射)

## 路径
const CONFIG_PATH_RANDOM_NODES = "res://table/random_nodes.json"
const CONFIG_PATH_SCENES = "res://table/scenes.json"
const SCENE_BASE_PATH = "res://scenes/游戏场景/"


func _ready():
	load_config()


## 加载配置文件
func load_config() -> void:
	_load_random_nodes()
	_load_scenes()
	print("【场景配置】加载完成，random_nodes: %d 条，scenes: %d 条" % [random_nodes_config.size(), scenes_config.size()])


## 加载 random_nodes.json
func _load_random_nodes() -> void:
	var file = FileAccess.open(CONFIG_PATH_RANDOM_NODES, FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_data)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("random_nodes"):
				random_nodes_config = data["random_nodes"]
			else:
				push_error("【场景配置】random_nodes.json 格式错误")
		else:
			push_error("【场景配置】解析 random_nodes.json 失败：%s" % json.get_error_message())
	else:
		push_error("【场景配置】无法打开 random_nodes.json")


## 加载 scenes.json
func _load_scenes() -> void:
	var file = FileAccess.open(CONFIG_PATH_SCENES, FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_data)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("scenes"):
				for scene in data["scenes"]:
					var id = str(scene["id"])
					scenes_config[id] = scene
			else:
				push_error("【场景配置】scenes.json 格式错误")
		else:
			push_error("【场景配置】解析 scenes.json 失败：%s" % json.get_error_message())
	else:
		push_error("【场景配置】无法打开 scenes.json")


## 根据节点类型随机选择场景配置
## @param node_type 节点类型（LevelNodeType.Type）
## @return 选中的场景配置字典，包含 scene_id, scene_path, npcs 等
func select_scene_config(node_type: int) -> Dictionary:
	# 筛选出对应类型的所有配置
	var candidates: Array = []
	for config in random_nodes_config:
		if config.has("type") and int(config["type"]) == node_type:
			candidates.append(config)

	if candidates.is_empty():
		push_error("【场景配置】未找到类型 %d 的配置" % node_type)
		return {}

	if candidates.size() == 1:
		return _build_scene_config(candidates[0])

	# 按权重随机选择
	var selected = _weighted_random_select(candidates)
	return _build_scene_config(selected)


## 权重随机选择
func _weighted_random_select(candidates: Array) -> Dictionary:
	var total_weight = 0.0
	for config in candidates:
		var weight = config.get("weight", 1.0)
		total_weight += float(weight)

	var rand_value = randf() * total_weight
	var current_weight = 0.0

	for config in candidates:
		var weight = config.get("weight", 1.0)
		current_weight += float(weight)
		if rand_value <= current_weight:
			return config

	# 兜底返回最后一个
	return candidates[candidates.size() - 1]


## 构建完整的场景配置（包含场景路径）
func _build_scene_config(config: Dictionary) -> Dictionary:
	var result = config.duplicate()

	var scene_id = str(config.get("scene", ""))
	if scenes_config.has(scene_id):
		var scene_info = scenes_config[scene_id]
		var scene_path = SCENE_BASE_PATH + scene_info["path"] + ".tscn"
		result["scene_path"] = scene_path
		result["scene_name"] = scene_info["name"]
	else:
		push_error("【场景配置】场景 ID %s 未在 scenes.json 中找到" % scene_id)
		result["scene_path"] = ""
		result["scene_name"] = ""

	# 处理 NPC 列表
	var npc_list: Array[String] = []
	if config.has("npc"):
		for npc_id in config["npc"]:
			npc_list.append(str(npc_id))
	result["npc_ids"] = npc_list

	return result


## 获取所有可用的节点类型
func get_available_types() -> Array:
	var types: Array = []
	for config in random_nodes_config:
		var t = int(config.get("type", 0))
		if t not in types:
			types.append(t)
	return types

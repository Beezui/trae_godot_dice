class_name LevelNode
extends RefCounted
## 关卡节点数据结构
## 用于存储单个关卡节点的所有信息

# 基本信息
var id: String = ""  # 节点 ID
var name: String = ""  # 节点名称
var type: int = 1  # 节点类型：1=战斗，2=奇遇，3=交易，4=奖励
var is_core: bool = false  # 是否为核心节点
var description: String = ""  # 节点描述

# 位置信息（用于可视化）
var position: Vector2 = Vector2.ZERO  # 2D 位置
var layer: int = 0  # 所在层级（用于布局）

# 连接关系
var connections: Array[String] = []  # 可到达的下一个节点 ID 列表
var previous_nodes: Array[String] = []  # 指向上一个节点的 ID 列表（用于反向查找）

# 节点数据
var data: Dictionary = {}  # 包含敌人、NPC、场景等具体数据
## data 结构示例：
## {
##     "scene_id": "1",
##     "scene_path": "res://scenes/游戏场景/场景 1.tscn",
##     "enemies": ["1", "2"],
##     "npcs": ["1"],
##     "rewards": []
## }

# 状态信息
var is_start: bool = false  # 是否为起始节点
var is_end: bool = false  # 是否为终点节点
var visited: bool = false  # 是否已被访问（用于路径查找）

# 随机种子（用于可重复生成）
var seed_value: int = 0


## 构造函数
func _init(p_id: String = "", p_name: String = "", p_type: int = 1):
	id = p_id
	name = p_name
	type = p_type


## 从配置字典加载数据
func load_from_dict(config: Dictionary) -> void:
	if config.has("id"):
		id = config["id"]
	if config.has("name"):
		name = config["name"]
	if config.has("type"):
		var val = config["type"]
		if typeof(val) == TYPE_STRING:
			type = int(val)
		else:
			type = int(val)
	if config.has("des"):
		description = config["des"]
	if config.has("is_start"):
		var val = config["is_start"]
		if typeof(val) == TYPE_STRING:
			is_start = (val == "1" or val == "true")
		else:
			is_start = bool(val)
	if config.has("is_end"):
		var val = config["is_end"]
		if typeof(val) == TYPE_STRING:
			is_end = (val == "1" or val == "true")
		else:
			is_end = bool(val)
	if config.has("next"):
		connections.clear()
		for item in config["next"]:
			connections.append(String(item))
	if config.has("enemy"):
		var enemies: Array[String] = []
		for item in config["enemy"]:
			enemies.append(String(item))
		data["enemies"] = enemies
	if config.has("Npc"):
		var npcs: Array[String] = []
		for item in config["Npc"]:
			npcs.append(String(item))
		data["npcs"] = npcs
	if config.has("scene"):
		data["scene_id"] = config["scene"]
	if config.has("weight"):
		data["weight"] = config["weight"]


## 复制节点数据
func duplicate() -> LevelNode:
	var new_node = LevelNode.new()
	new_node.id = id
	new_node.name = name
	new_node.type = type
	new_node.is_core = is_core
	new_node.description = description
	new_node.position = position
	new_node.layer = layer
	new_node.connections = connections.duplicate()
	new_node.previous_nodes = previous_nodes.duplicate()
	new_node.data = data.duplicate()
	new_node.is_start = is_start
	new_node.is_end = is_end
	new_node.seed_value = seed_value
	return new_node


## 获取节点类型的中文名称
func get_type_name() -> String:
	match type:
		1: return "战斗"
		2: return "奇遇"
		3: return "交易"
		4: return "奖励"
		_: return "未知"


## 获取节点类型的颜色
func get_type_color() -> Color:
	match type:
		1: return Color(1, 0.3, 0.3)  # 红色 - 战斗
		2: return Color(0.3, 0.6, 1)  # 蓝色 - 奇遇
		3: return Color(1, 0.8, 0.3)  # 黄色 - 交易
		4: return Color(0.3, 1, 0.5)  # 绿色 - 奖励
		_: return Color(1, 1, 1)  # 白色 - 未知


## 转换为字典（用于序列化）
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"type": type,
		"is_core": is_core,
		"description": description,
		"position": {"x": position.x, "y": position.y},
		"layer": layer,
		"connections": connections,
		"previous_nodes": previous_nodes,
		"data": data,
		"is_start": is_start,
		"is_end": is_end,
		"seed_value": seed_value
	}


## 从字典创建节点
static func from_dict(dict_data: Dictionary) -> LevelNode:
	var node = LevelNode.new()
	node.id = dict_data.get("id", "")
	node.name = dict_data.get("name", "")
	node.type = dict_data.get("type", 1)
	node.is_core = dict_data.get("is_core", false)
	node.description = dict_data.get("description", "")
	if dict_data.has("position"):
		node.position = Vector2(dict_data["position"].get("x", 0), dict_data["position"].get("y", 0))
	node.layer = dict_data.get("layer", 0)
	node.connections = Array(dict_data.get("connections", []))
	node.previous_nodes = Array(dict_data.get("previous_nodes", []))
	node.data = dict_data.get("data", {})
	node.is_start = dict_data.get("is_start", false)
	node.is_end = dict_data.get("is_end", false)
	node.seed_value = dict_data.get("seed_value", 0)
	return node

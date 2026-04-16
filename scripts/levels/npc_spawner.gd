class_name NPCSpawner
extends Node3D
## NPC 生成器
## 负责从 hero.json 读取角色配置，在场景内随机位置生成 NPC

## 配置数据
var hero_config: Dictionary = {}  # hero.json 数据 (id -> hero 映射)

## 路径
const CONFIG_PATH_HERO = "res://table/hero.json"

## NPC 场景路径（使用简易 NPC 场景，避免重复加载地面和围墙）
const NPC_SCENE_PATH = "res://scenes/npc_scene.tscn"

## 生成范围配置
var spawn_min_x = -10.0
var spawn_max_x = 10.0
var spawn_min_z = -6.0
var spawn_max_z = 6.0
var spawn_y = 0.0  # 地面高度


## 加载 hero.json 配置
func load_hero_config() -> void:
	var file = FileAccess.open(CONFIG_PATH_HERO, FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_data)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("heroes"):
				for hero in data["heroes"]:
					var id = str(hero["id"])
					hero_config[id] = hero
				print("【NPC 生成器】加载 hero 配置：%d 条" % hero_config.size())
			else:
				push_error("【NPC 生成器】hero.json 格式错误")
		else:
			push_error("【NPC 生成器】解析 hero.json 失败：%s" % json.get_error_message())
	else:
		push_error("【NPC 生成器】无法打开 hero.json")


## 在场景中生成 NPC
## @param npc_ids NPC ID 列表
## @param scene_parent 场景父节点
## @param boundary BoundarySystem 节点（用于确定生成范围）
func spawn_npcs(npc_ids: Array[String], scene_parent: Node, boundary: Node3D) -> void:
	# 加载配置
	load_hero_config()

	# 根据 BoundarySystem 计算生成范围
	_update_spawn_range(boundary)

	# 生成每个 NPC
	for npc_id in npc_ids:
		if not hero_config.has(npc_id):
			push_error("【NPC 生成器】未找到英雄 ID: %s" % npc_id)
			continue

		var hero_data = hero_config[npc_id]
		_spawn_single_npc(hero_data, scene_parent)


## 更新生成范围
func _update_spawn_range(boundary: Node3D) -> void:
	if boundary == null:
		return

	# 获取地面碰撞体的尺寸
	var ground = boundary.get_node("Ground")
	if ground and ground.shape is BoxShape3D:
		var size = ground.shape.size
		spawn_min_x = -size.x / 2.0 + 2.0  # 留边距
		spawn_max_x = size.x / 2.0 - 2.0
		spawn_min_z = -size.z / 2.0 + 2.0
		spawn_max_z = size.z / 2.0 - 2.0
		spawn_y = 0.0  # 地面高度


## 生成单个 NPC
func _spawn_single_npc(hero_data: Dictionary, scene_parent: Node) -> void:
	# 创建 NPC 节点（使用 Character3D 或类似的节点）
	var npc = _create_npc_instance(hero_data)
	if npc == null:
		return

	# 随机位置
	var spawn_pos = _get_random_spawn_position()
	npc.position = spawn_pos

	# 添加到场景
	scene_parent.add_child(npc)

	print("【NPC 生成器】生成 NPC：%s at %s" % [hero_data.get("name", "Unknown"), spawn_pos])


## 创建 NPC 实例
func _create_npc_instance(hero_data: Dictionary) -> Node3D:
	# 这里需要根据实际的 NPC 场景来创建
	# 目前使用 character_test_arena.tscn 作为模板
	# 后续可能需要创建专门的 NPC 场景

	var npc_scene = load(NPC_SCENE_PATH)
	if not npc_scene:
		push_error("【NPC 生成器】无法加载 NPC 场景：%s" % NPC_SCENE_PATH)
		return null

	var npc = npc_scene.instantiate()

	# 设置 NPC 数据
	if npc.has_method("set_hero_data"):
		npc.set_hero_data(hero_data)

	# 设置 NPC 名称
	if npc.has_method("set_name"):
		npc.set_name(hero_data.get("name", "NPC"))

	return npc


## 获取随机生成位置
func _get_random_spawn_position() -> Vector3:
	var x = randf_range(spawn_min_x, spawn_max_x)
	var z = randf_range(spawn_min_z, spawn_max_z)
	return Vector3(x, spawn_y, z)


## 清理所有 NPC
func clear_all_npcs() -> void:
	for child in get_children():
		if child is Node3D:
			child.queue_free()
	print("【NPC 生成器】清理所有 NPC")

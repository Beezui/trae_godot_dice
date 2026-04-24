extends Node3D
## 核心关卡场景节点
## 统一管理场景加载、切换和 NPC 生成
## 所有关卡场景都作为此节点的子节点动态加载
## 通过 autoload 注册为全局单例，使用 LevelStage 访问

## 单例实例
static var _instance: Node3D = null

## 当前加载的场景
var current_scene: Node3D = null

## 场景配置管理器
var scene_config: Node = null

## NPC 生成器
var npc_spawner: Node3D = null

## 当前节点数据
var current_node: LevelNode = null

## 当前关卡数据
var level_data: LevelData = null


static func get_instance() -> Node:
	return _instance


func _ready():
	if _instance == null:
		_instance = self
		_initialize()


## 初始化
func _initialize():
	print("=== 核心关卡节点初始化 ===")

	# 创建场景配置管理器
	scene_config = LevelSceneConfig.new()
	scene_config.name = "SceneConfig"
	add_child(scene_config)

	# 创建 NPC 生成器
	npc_spawner = NPCSpawner.new()
	npc_spawner.name = "NPCSpawner"
	add_child(npc_spawner)

	print("【核心关卡节点】初始化完成")


## 加载关卡场景
## @param p_node 关卡节点数据
## @param p_level_data 关卡数据
## @return 是否加载成功
func load_level_scene(p_node: LevelNode, p_level_data: LevelData) -> bool:
	current_node = p_node
	level_data = p_level_data

	print("【核心关卡节点】加载节点：%s (类型：%s)" % [p_node.name, LevelNodeType.get_type_name(p_node.type)])

	# 1. 清理所有子节点（保留 SceneConfig 和 NPCSpawner）
	_clear_all_children()
	current_scene = null

	# 2. 根据节点类型选择场景配置
	if scene_config == null:
		push_error("【核心关卡节点】场景配置管理器未初始化")
		return false

	var scene_cfg = scene_config.select_scene_config(p_node.type)
	if scene_cfg.is_empty():
		push_error("【核心关卡节点】未找到节点类型 %d 的场景配置" % p_node.type)
		return false

	# 3. 加载场景
	var scene_path = scene_cfg.get("scene_path", "")
	if scene_path == "":
		push_error("【核心关卡节点】场景路径为空")
		return false

	var scene_resource = load(scene_path)
	if not scene_resource:
		push_error("【核心关卡节点】无法加载场景：%s" % scene_path)
		return false

	current_scene = scene_resource.instantiate()
	current_scene.name = scene_cfg.get("scene_name", "LoadedScene")
	add_child(current_scene)

	print("【核心关卡节点】场景加载成功：%s" % scene_cfg.get("scene_name", ""))
	print("【核心关卡节点】当前 LevelStage 子节点数：%d" % get_child_count())
	print("【核心关卡节点】当前场景子节点数：%d" % current_scene.get_child_count())

	# 4. 生成 NPC
	var npc_ids = scene_cfg.get("npc_ids", [])
	if npc_ids.size() > 0 and npc_spawner:
		_spawn_npcs(npc_ids)

	return true


## 清理当前场景
func _unload_current_scene():
	if current_scene:
		print("【核心关卡节点】清理旧场景：%s" % current_scene.name)

		# 清理 NPC
		if npc_spawner:
			npc_spawner.clear_all_npcs()

		# 移除并销毁场景
		current_scene.queue_free()
		current_scene = null


## 清理所有子节点（保留 SceneConfig 和 NPCSpawner）
func _clear_all_children():
	print("【核心关卡节点】开始清理子节点，当前子节点数：%d" % get_child_count())
	for child in get_children():
		if child != scene_config and child != npc_spawner:
			print("【核心关卡节点】清理子节点：%s" % child.name)
			child.queue_free()
	print("【核心关卡节点】清理完成，剩余子节点数：%d" % get_child_count())


## 生成 NPC
func _spawn_npcs(npc_ids: Array[String]):
	if npc_spawner == null:
		push_error("【核心关卡节点】NPC 生成器未初始化")
		return

	if current_scene == null:
		push_error("【核心关卡节点】当前场景未加载")
		return

	# 在场景中查找 BoundarySystem 作为生成范围参考
	var boundary = current_scene.get_node("BoundarySystem")
	if not boundary:
		push_error("【核心关卡节点】未找到 BoundarySystem，无法确定生成范围")
		return

	# 调用 NPCSpawner 的 spawn_npcs 方法
	npc_spawner.spawn_npcs(npc_ids, current_scene, boundary)
	print("【核心关卡节点】生成 NPC：%d 个" % npc_ids.size())


## 切换节点
## @param target_node 目标节点
## @return 是否切换成功
func transition_to_node(target_node: LevelNode) -> bool:
	if level_data == null:
		push_error("【核心关卡节点】关卡数据未初始化")
		return false

	return load_level_scene(target_node, level_data)


## 获取当前场景
func get_current_scene() -> Node3D:
	return current_scene


## 获取当前节点
func get_current_node() -> LevelNode:
	return current_node

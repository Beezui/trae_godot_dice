class_name LevelGenerator
extends Node
## 关卡生成器 - 全局单例
## 负责统一管理关卡生成，提供全局访问接口

# 单例实例
static var instance = null

# 组件
var core_generator: LevelGeneratorCore = null
var random_generator: LevelGeneratorRandom = null
var validator: LevelValidator = null

# 当前生成的关卡数据
var current_level_data: LevelData = null

# 配置
var config: Dictionary = {}
var config_path = "res://config/level_generation_config.json"

# 信号
signal level_generated(level_data: LevelData)  # 关卡生成完成
signal generation_started()  # 生成开始
signal generation_completed(level_data: LevelData)  # 生成完成
signal generation_failed(error_message: String)  # 生成失败


func _ready():
	# 注册单例实例
	instance = self
	
	# 加载配置
	_load_config()
	
	# 初始化组件
	core_generator = LevelGeneratorCore.new(config)
	random_generator = LevelGeneratorRandom.new(config)
	validator = LevelValidator.new(config)
	
	# 加载配置文件
	var err_core = core_generator.load_configs()
	var err_random = random_generator.load_configs()
	
	if err_core != OK or err_random != OK:
		push_error("[LevelGenerator] 配置文件加载失败")
	
	print("[LevelGenerator] 初始化完成")


## 加载配置文件
func _load_config() -> void:
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_warning("[LevelGenerator] 无法打开配置文件，使用默认配置")
		config = {
			"base_nodes": 30,
			"nodes_per_difficulty": 5,
			"fluctuation_range": 0.1,
			"core_node_ratio": 0.35,
			"min_random_between_core": 1,
			"max_random_between_core": 3,
			"avoid_consecutive_reward_trade": true,
			"max_consecutive_same_type": 2
		}
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_text) == OK:
		config = json.get_data()
		print("[LevelGenerator] 配置加载成功")
	else:
		push_warning("[LevelGenerator] 解析配置文件失败，使用默认配置")
		config = {
			"base_nodes": 30,
			"nodes_per_difficulty": 5,
			"fluctuation_range": 0.1,
			"core_node_ratio": 0.35,
			"min_random_between_core": 1,
			"max_random_between_core": 3,
			"avoid_consecutive_reward_trade": true,
			"max_consecutive_same_type": 2
		}


## 生成关卡（主要接口）
func generate_level(difficulty: int = 1, seed_value: int = 0) -> LevelData:
	emit_signal("generation_started")

	print("[LevelGenerator] 开始生成关卡")
	print("  - 难度：", difficulty)
	print("  - 种子：", seed_value)

	# 创建关卡数据
	current_level_data = LevelData.new(difficulty, seed_value)

	# 1. 生成核心节点骨架（包含所有节点，已分配不同类型）
	var core_chain = core_generator.generate_core_chain(
		current_level_data.target_total,
		difficulty,
		seed_value
	)

	if core_chain.size() == 0:
		emit_signal("generation_failed", "核心节点生成失败")
		return null

	print("[LevelGenerator] 核心节点生成完成：", core_chain.size(), " 个节点")

	# 2. 添加到关卡数据
	for node in core_chain:
		current_level_data.add_node(node)

	# 3. 验证
	var is_valid = validator.validate(current_level_data)

	# 4. 打印调试信息
	current_level_data.print_debug_info()
	validator.print_validation_report(current_level_data)

	# 5. 发射信号
	if is_valid:
		emit_signal("level_generated", current_level_data)
		emit_signal("generation_completed", current_level_data)
		print("[LevelGenerator] 关卡生成成功 ✓")
	else:
		emit_signal("generation_failed", "关卡验证失败")
		print("[LevelGenerator] 关卡生成失败 ✗")

	return current_level_data


## 建立节点连接关系
func _build_connections(chain: Array[LevelNode]) -> void:
	for i in range(chain.size() - 1):
		var current = chain[i]
		var next = chain[i + 1]
		
		# 如果当前节点的 connections 中没有下一个节点，添加
		if next.id not in current.connections:
			current.connections.append(next.id)
		
		# 如果下一个节点的 previous_nodes 中没有当前节点，添加
		if current.id not in next.previous_nodes:
			next.previous_nodes.append(current.id)


## 重新生成关卡（使用相同参数）
func regenerate_level() -> LevelData:
	if current_level_data == null:
		push_error("[LevelGenerator] 没有已生成的关卡数据")
		return null
	
	return generate_level(current_level_data.difficulty, current_level_data.seed_value)


## 获取当前关卡数据
func get_current_level() -> LevelData:
	return current_level_data


## 清除当前关卡数据
func clear_current_level() -> void:
	if current_level_data:
		current_level_data.clear()
	current_level_data = null


## 获取配置值
func get_config_value(key: String, default_value = null):
	if config.has(key):
		return config[key]
	return default_value


## 更新配置
func update_config(new_config: Dictionary) -> void:
	for key in new_config.keys():
		config[key] = new_config[key]


## 保存配置到文件
func save_config() -> Error:
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	var json = JSON.new()
	var json_text = json.stringify(config, "  ")
	file.store_string(json_text)
	file.close()
	
	return OK


## 静态方法：获取单例实例
static func get_instance():
	if instance == null:
		# 如果单例未初始化，尝试从场景树获取
		var tree = Engine.get_main_loop()
		if tree:
			var root = tree.get_root()
			for child in root.get_children():
				if child is LevelGenerator:
					instance = child
					break
	return instance

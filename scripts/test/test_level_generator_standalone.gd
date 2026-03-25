@tool
extends EditorScript
## 关卡生成器独立测试脚本
## 在编辑器中直接运行，不依赖场景

func _run():
	print("====================")
	print("[EditorTest] 关卡生成器测试")
	print("====================")
	
	# 加载配置
	var config_file = FileAccess.open("res://config/level_generation_config.json", FileAccess.READ)
	var config = {}
	if config_file:
		var json = JSON.new()
		if json.parse(config_file.get_as_text()) == OK:
			config = json.get_data()
		config_file.close()
	
	# 创建生成器
	var core_gen = LevelGeneratorCore.new(config)
	var random_gen = LevelGeneratorRandom.new(config)
	var validator = LevelValidator.new(config)
	
	# 加载配置
	print("\n[1] 加载配置文件...")
	if core_gen.load_configs() != OK:
		print("  ✗ 核心节点配置加载失败")
		return
	print("  ✓ 核心节点配置加载成功")
	
	if random_gen.load_configs() != OK:
		print("  ✗ 随机节点配置加载失败")
		return
	print("  ✓ 随机节点配置加载成功")
	
	# 生成核心节点链
	print("\n[2] 生成核心节点骨架...")
	var seed_value = 12345
	var target_total = 35
	var core_chain = core_gen.generate_core_chain(target_total, seed_value)
	print("  ✓ 生成核心节点：", core_chain.size(), " 个")
	
	for node in core_chain:
		print("    - ", node.id, ": ", node.name, " (类型:", node.get_type_name(), ")")
	
	# 插入随机节点
	print("\n[3] 插入随机节点...")
	var full_chain = random_gen.insert_random_nodes(core_chain, target_total, seed_value)
	print("  ✓ 总节点数：", full_chain.size(), " 个")
	
	# 统计类型
	var type_count = {}
	for node in full_chain:
		type_count[node.type] = type_count.get(node.type, 0) + 1
	
	print("\n  节点类型分布:")
	for type_id in type_count.keys():
		var type_name = ""
		match type_id:
			1: type_name = "战斗"
			2: type_name = "奇遇"
			3: type_name = "交易"
			4: type_name = "奖励"
		print("    - ", type_name, ": ", type_count[type_id], " 个")
	
	# 创建关卡数据并验证
	print("\n[4] 创建关卡数据并验证...")
	var level_data = LevelData.new(1, seed_value)
	for node in full_chain:
		level_data.add_node(node)
	
	# 建立连接
	for i in range(full_chain.size() - 1):
		full_chain[i].connections.append(full_chain[i + 1].id)
	
	# 验证
	var is_valid = validator.validate(level_data)
	
	if is_valid:
		print("  ✓ 验证通过")
		print("  - 路径数量：", level_data.all_paths.size())
		print("  - 最长路径：", level_data.longest_path.size() if level_data.longest_path.size() > 0 else 0)
		print("  - 最短路径：", level_data.shortest_path.size() if level_data.shortest_path.size() > 0 else 0)
	else:
		print("  ✗ 验证失败")
		if level_data.validation_errors.size() > 0:
			print("  错误:")
			for error in level_data.validation_errors:
				print("    - ", error)
	
	print("\n====================")
	print("[EditorTest] 测试完成")
	print("====================\n")

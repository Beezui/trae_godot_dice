@tool
extends EditorScript
## 验证节点类型分配测试脚本

func _run():
	print("====================")
	print("[验证测试] 节点类型分配验证")
	print("====================\n")

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
	var validator = LevelValidator.new(config)

	# 加载配置
	print("[1] 加载配置文件...")
	if core_gen.load_configs() != OK:
		print("  ✗ 配置加载失败")
		return
	print("  ✓ 配置加载成功\n")

	# 多次生成统计类型分布
	print("[2] 生成 5 次关卡统计类型分布...")
	var total_type_count = {}

	for test_idx in range(1, 6):
		var seed_value = test_idx * 1000
		var core_chain = core_gen.generate_core_chain(35, 1, seed_value)

		# 统计本次类型
		var type_count = {}
		for node in core_chain:
			type_count[node.type] = type_count.get(node.type, 0) + 1

		# 累加
		for type_id in type_count.keys():
			total_type_count[type_id] = total_type_count.get(type_id, 0) + type_count[type_id]

		print("  测试 #", test_idx, " (seed=", seed_value, "): 共", core_chain.size(), " 节点")
		print("    战斗:", type_count.get(1, 0), " 奇遇:", type_count.get(2, 0),
			  " 交易:", type_count.get(3, 0), " 奖励:", type_count.get(4, 0))

	# 总统计
	print("\n[3] 总计类型分布:")
	var total_nodes = 0
	for type_id in total_type_count.keys():
		total_nodes += total_type_count[type_id]

	var type_names = {1: "战斗", 2: "奇遇", 3: "交易", 4: "奖励"}
	for type_id in [1, 2, 3, 4]:
		var count = total_type_count.get(type_id, 0)
		var percentage = float(count) / float(total_nodes) * 100.0
		print("  ", type_names.get(type_id, "未知"), ": ", count, " 个 (", round(percentage), "%)")

	# 验证 4 种类型都出现
	print("\n[4] 验证结果:")
	var all_types_present = (total_type_count.get(1, 0) > 0 and
							 total_type_count.get(2, 0) > 0 and
							 total_type_count.get(3, 0) > 0 and
							 total_type_count.get(4, 0) > 0)

	if all_types_present:
		print("  ✓ 所有 4 种节点类型均已生成")
	else:
		print("  ✗ 部分节点类型未生成:")
		if total_type_count.get(1, 0) == 0: print("    - 缺少战斗类型")
		if total_type_count.get(2, 0) == 0: print("    - 缺少奇遇类型")
		if total_type_count.get(3, 0) == 0: print("    - 缺少交易类型")
		if total_type_count.get(4, 0) == 0: print("    - 缺少奖励类型")

	# 打印一个具体示例
	print("\n[5] 示例关卡节点列表 (seed=12345):")
	var example_chain = core_gen.generate_core_chain(35, 1, 12345)
	for node in example_chain:
		print("  节点#", node.id, " - 层", node.layer, ": ", node.get_type_name(), " (", node.name, ")")

	print("\n====================")
	print("[验证测试] 完成")
	print("====================\n")

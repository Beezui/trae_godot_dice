@tool
extends EditorScript
## 关卡生成器测试脚本
## 在编辑器中直接运行测试

func _run():
	print("====================")
	print("[Test] 开始测试关卡生成器")
	print("====================")
	
	# 手动加载配置
	var config = {
		"base_nodes": 30,
		"nodes_per_difficulty": 5,
		"fluctuation_range": 0.1,
		"core_node_ratio": 0.35,
		"min_random_between_core": 1,
		"max_random_between_core": 3,
		"avoid_consecutive_reward_trade": true,
		"max_consecutive_same_type": 2
	}
	
	# 创建生成器组件
	var core_gen = LevelGeneratorCore.new(config)
	var random_gen = LevelGeneratorRandom.new(config)
	var validator = LevelValidator.new(config)
	
	# 加载配置
	var err_core = core_gen.load_configs()
	var err_random = random_gen.load_configs()
	
	if err_core != OK:
		print("[Test] 核心节点配置加载失败")
		return
	
	if err_random != OK:
		print("[Test] 随机节点配置加载失败")
		return
	
	print("[Test] 配置加载成功")
	
	# 生成核心节点链
	var core_chain = core_gen.generate_core_chain(35, 12345)
	print("[Test] 核心节点生成：", core_chain.size(), " 个")
	
	for node in core_chain:
		print("  - ", node.id, ": ", node.name, " (类型:", node.type, ")")
	
	print("====================")
	print("[Test] 测试完成")
	print("====================")

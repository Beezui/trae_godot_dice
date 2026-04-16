class_name BattleTestScene
extends BattleSceneBase
## 测试战斗场景
## 用于验证战斗框架功能

## 测试用英雄 ID
@export var test_hero_id: int = 1
## 测试用敌人 ID
@export var test_enemy_id: int = 2


func _ready():
	print("【BattleTestScene】测试战斗场景已就绪")
	super._ready()

	# 创建测试用 LevelNode
	var test_level_node = _create_test_level_node()

	# 初始化战斗
	initialize_battle(test_level_node, [test_hero_id])

	# 连接信号
	on_battle_completed.connect(_on_battle_completed)

	# 开始战斗流程
	await get_tree().create_timer(1.0).timeout
	start_battle_flow()


func _create_test_level_node() -> LevelNode:
	"""创建测试用关卡节点"""
	var level_node = LevelNode.new("test_001", "测试战斗", 1)

	# 配置敌人数据
	level_node.data = {
		"scene_id": "1",
		"scene_path": "res://scenes/battle/battle_scene_base.tscn",
		"enemies": [str(test_enemy_id)],  # 敌人 ID 列表
		"npcs": [],
		"rewards": []
	}

	return level_node


func _on_battle_completed(victory: bool):
	"""战斗完成回调"""
	if victory:
		print("【BattleTestScene】测试胜利！")
	else:
		print("【BattleTestScene】测试失败...")

	# 清理战斗
	await get_tree().create_timer(3.0).timeout
	cleanup_battle()

	# 重新加载场景
	get_tree().reload_current_scene()


func spawn_enemies():
	"""生成敌人（重写基类方法）"""
	print("【BattleTestScene】生成敌人...")
	# 敌人由 BattleManager 在初始化时加载


func spawn_player_dices():
	"""生成玩家骰子（重写基类方法）"""
	print("【BattleTestScene】生成玩家骰子...")
	# 骰子由 BattleManager 在准备阶段生成

extends Node

## 奖励结算 UI 调用示例
## 此脚本展示如何使用 RewardSettlementUI 显示奖励
## 在实际集成时，可以根据关卡类型（战斗/奖励/奇遇/贸易）调用不同的方法

# 预加载 UI 场景
const REWARD_UI_SCENE: PackedScene = preload("res://scenes/ui/reward_settlement_ui.tscn")

# UI 实例引用
var _reward_ui: Control = null


func _ready():
	# 示例：3秒后自动显示奖励
	await get_tree().create_timer(3.0).timeout
	_show_example_rewards()


## 显示奖励的示例方法
func _show_example_rewards():
	# 实例化 UI
	_reward_ui = REWARD_UI_SCENE.instantiate()

	# 添加到场景树
	var canvas = get_tree().root
	canvas.add_child(_reward_ui)

	# 准备示例奖励数据
	var example_rewards = [
		{"id": "101", "amount": 1},  # 火焰术
		{"id": "301", "amount": 3},  # 生命药水 x3
		{"id": "201", "amount": 1},  # 力量护符
	]

	# 模拟从道具表获取数据（实际使用时需要从 TableManager 或 DataManager 获取）
	var item_table = _get_mock_item_table()

	# 显示奖励
	_reward_ui.show_rewards(example_rewards, item_table)

	# 设置标题
	_reward_ui.set_title("战斗胜利！获得以下奖励：")

	# 连接确认按钮信号
	_reward_ui.on_confirm_pressed.connect(_on_reward_confirm)
	_reward_ui.on_reward_hovered.connect(_on_reward_hover)
	_reward_ui.on_reward_hover_exited.connect(_on_reward_hover_exit)


## 模拟道具表数据（实际使用时从 TableManager 获取）
func _get_mock_item_table() -> Dictionary:
	return {
		"101": {"name": "火焰术", "type": "技能书", "price": 100, "description": "学习火焰技能", "icon": "fire_skill.png"},
		"201": {"name": "力量护符", "type": "宝物", "price": 200, "description": "增加力量属性", "icon": "amulet_str.png"},
		"301": {"name": "生命药水", "type": "消耗品", "price": 30, "description": "恢复少量生命值", "icon": "potion_hp_small.png"},
	}


## 确认按钮点击
func _on_reward_confirm():
	print("玩家确认领取奖励")
	# TODO: 在此处添加奖励发放逻辑
	# - 添加道具到玩家背包
	# - 添加金币到玩家账户
	# - 更新玩家数据

	# 关闭 UI
	if _reward_ui:
		_reward_ui.hide_ui()
		_reward_ui.queue_free()
		_reward_ui = null

	# TODO: 继续游戏流程（如投掷命运骰子）


## 奖励项悬停
func _on_reward_hover(data: Dictionary):
	print("悬停奖励: ", data.get("name", ""))


## 奖励项悬停结束
func _on_reward_hover_exit():
	print("悬停结束")


# ==========================================
# 以下是实际使用时需要的接口预留
# ==========================================

## 根据关卡类型决定是否显示奖励
## @param level_type: String 关卡类型 ("battle", "reward", "encounter", "trade")
## @param rewards: Array 奖励数据
func show_rewards_by_level_type(level_type: String, rewards: Array) -> void:
	# 贸易关卡不显示奖励
	if level_type == "trade":
		print("贸易关卡，不显示奖励")
		return

	# 战斗/奖励/奇遇关卡显示奖励
	if level_type in ["battle", "reward", "encounter"]:
		# TODO: 接入实际的道具表数据
		_show_rewards(rewards, {})


## 内部方法：显示奖励
func _show_rewards(rewards: Array, item_table: Dictionary):
	if rewards.is_empty():
		return

	_reward_ui = REWARD_UI_SCENE.instantiate()
	get_tree().root.add_child(_reward_ui)
	_reward_ui.show_rewards(rewards, item_table)
	_reward_ui.on_confirm_pressed.connect(_on_reward_confirm)


## 从道具表加载道具数据
## @param item_ids: Array[String] 道具ID列表
## @return Dictionary 道具ID到道具数据的映射
func load_item_data_from_table(item_ids: Array[String]) -> Dictionary:
	# TODO: 实现从 TableManager 或数据管理器加载道具数据
	# 示例：
	# var table_manager = get_node("/root/TableManager")
	# return table_manager.get_items_by_ids(item_ids)
	return {}


## 添加奖励到玩家背包
## @param rewards: Array 奖励数据
func add_rewards_to_inventory(rewards: Array) -> void:
	# TODO: 实现将奖励添加到玩家背包
	# 示例：
	# var player_data = get_node("/root/PlayerData")
	# for reward in rewards:
	#     player_data.add_item(reward["id"], reward.get("amount", 1))
	pass


## 添加金币到玩家账户
## @param gold_amount: int 金币数量
func add_gold_to_player(gold_amount: int) -> void:
	# TODO: 实现添加金币
	# 示例：
	# var player_data = get_node("/root/PlayerData")
	# player_data.add_gold(gold_amount)
	pass

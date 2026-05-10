extends Node
## 战斗掉落池管理器 (Autoload 单例)
## 根据关卡阶段从掉落池随机生成奖励列表

# 掉落池配置缓存
var _pools: Array = []
var _loaded: bool = false


func _ready():
	_load_drop_pools()


## 加载掉落池配置
func _load_drop_pools():
	if _loaded:
		return

	var json_path = "res://table/battle_drop_pools.json"
	if not FileAccess.file_exists(json_path):
		push_error("【BattleRewardPool】找不到掉落池配置: ", json_path)
		return

	var file = FileAccess.open(json_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("【BattleRewardPool】解析掉落池配置失败")
		return

	var data = json.get_data()
	if data and data.has("battle_drop_pools"):
		_pools = data["battle_drop_pools"]
		print("【BattleRewardPool】加载 ", _pools.size(), " 个掉落池")
	else:
		push_error("【BattleRewardPool】掉落池配置缺少 'battle_drop_pools' 字段")

	_loaded = true


## 根据阶段生成奖励
## @param stage 关卡阶段
## @return Array[Dictionary]: [{id: "gold", amount: 100}, {id: "101", amount: 1}, ...]
func generate_rewards(stage: int) -> Array:
	if not _loaded:
		_load_drop_pools()

	if _pools.is_empty():
		push_warning("【BattleRewardPool】掉落池为空，无法生成奖励")
		return []

	# 查找对应阶段的池配置（如果没有精确匹配，使用第一个）
	var pool = _find_pool(stage)

	var rewards: Array = []

	# 1. 必定掉落金币
	var gold_amount = randi() % (pool["gold_max"] - pool["gold_min"] + 1) + pool["gold_min"]
	rewards.append({"id": "gold", "amount": int(gold_amount)})

	# 2. 从道具池权重随机
	var item_pool = pool.get("item_pool", [])
	if not item_pool.is_empty():
		var max_items = pool.get("max_items", 1)
		for i in range(max_items):
			if _weighted_random_roll(item_pool):
				rewards.append(_weighted_random_select(item_pool))

	# 3. 遗物掉落
	var relic_weight = pool.get("relic_weight", 0)
	if relic_weight > 0:
		var total_weight = _calc_total_weight(item_pool) + relic_weight
		if randi() % total_weight < relic_weight:
			rewards.append({"id": "relic", "name": "遗物", "type": "遗物", "amount": 1})

	return rewards


## 查找对应阶段的掉落池
func _find_pool(stage: int) -> Dictionary:
	for pool in _pools:
		if pool.get("stage", -1) == stage:
			return pool
	# 回退到第一个池
	if not _pools.is_empty():
		return _pools[0]
	return {}


## 从权重池中随机选择一个奖励
func _weighted_random_select(pool: Array) -> Dictionary:
	var total_weight = 0
	for item in pool:
		total_weight += item.get("weight", 1)

	if total_weight == 0:
		return {"id": str(pool[0]["id"]), "amount": 1}

	var roll = randi() % total_weight
	var cumulative = 0

	for item in pool:
		cumulative += item.get("weight", 1)
		if roll < cumulative:
			return {"id": str(item["id"]), "amount": 1}

	return {"id": str(pool[-1]["id"]), "amount": 1}


## 权重随机（决定是否掉落道具）
func _weighted_random_roll(pool: Array) -> bool:
	if pool.is_empty():
		return false
	return true


## 计算权重池总和
func _calc_total_weight(pool: Array) -> int:
	var total = 0
	for item in pool:
		total += item.get("weight", 1)
	return total

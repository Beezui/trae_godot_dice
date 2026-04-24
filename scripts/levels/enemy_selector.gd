extends Node
## 敌人选择器单例
## 根据当前阶段从 hero.csv 中随机选择敌人
## 规则：
##   1. 只选择 stage <= 当前阶段的敌人
##   2. 同 stage 敌人权重 ×2
##   3. type=2(普通敌人)、3(精英敌人)、4(Boss)

## 角色类型枚举
const TYPE_PLAYER = 1      # 玩家角色
const TYPE_NORMAL_ENEMY = 2 # 普通敌人
const TYPE_ELITE_ENEMY = 3  # 精英敌人
const TYPE_BOSS = 4         # Boss
const TYPE_MERCHANT = 5     # 商人

## 敌人缓存（加载一次后缓存）
var _enemy_pool: Array[Dictionary] = []
var _is_loaded: bool = false

## 获取单例实例
static var _instance: EnemySelector = null

static func get_instance() -> EnemySelector:
	return _instance


func _ready():
	_instance = self
	print("[EnemySelector] 初始化完成")


## 加载敌人池
## @param stage 当前阶段（1-4）
## @return 是否加载成功
func load_enemy_pool(stage: int) -> bool:
	if stage < 1 or stage > 4:
		push_error("[EnemySelector] 阶段值无效：", stage)
		return false

	# 加载 hero.json
	var json_file = FileAccess.open("res://table/hero.json", FileAccess.READ)
	if json_file == null:
		push_error("[EnemySelector] 无法打开 hero.json")
		return false

	var json_text = json_file.get_as_text()
	json_file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[EnemySelector] 解析 hero.json 失败")
		return ERR_PARSE_ERROR

	var data = json.get_data()
	if not (data is Dictionary and data.has("heroes")):
		push_error("[EnemySelector] hero.json 格式错误")
		return false

	var all_heroes = data["heroes"] as Array

	# 筛选敌人（排除玩家角色）
	_enemy_pool.clear()
	for hero in all_heroes:
		if not (hero is Dictionary):
			continue

		var hero_type = hero.get("type", 1) as int
		var hero_stage = hero.get("stage", 1) as int

		# 只选择敌人类型（type >= 2）
		if hero_type < 2:
			continue

		# 只选择 stage <= 当前阶段的敌人
		if hero_stage > stage:
			continue

		_enemy_pool.append(hero)

	if _enemy_pool.size() == 0:
		push_warning("[EnemySelector] 阶段 ", stage, " 没有可用的敌人")
		return false

	print("[EnemySelector] 阶段 ", stage, " 加载了 ", _enemy_pool.size(), " 个敌人")
	return true


## 根据阶段随机选择一个敌人
## @param stage 当前阶段（1-4）
## @return 敌人配置字典，空字典表示失败
func select_enemy(stage: int) -> Dictionary:
	if _enemy_pool.size() == 0:
		# 尝试重新加载
		if not load_enemy_pool(stage):
			return {}

	# 计算权重
	var weighted_pool: Array[Dictionary] = []
	for enemy in _enemy_pool:
		var enemy_stage = enemy.get("stage", 1) as int
		var weight = 1.0

		# 同 stage 敌人权重 ×2
		if enemy_stage == stage:
			weight = 2.0

		weighted_pool.append({
			"enemy": enemy,
			"weight": weight
		})

	# 按权重随机选择
	var selected = _pick_by_weight(weighted_pool)
	if selected.is_empty():
		return {}

	print("[EnemySelector] 选择敌人：", selected.get("name", "Unknown"),
		  " (type=", selected.get("type"), ", stage=", selected.get("stage"), ")")
	return selected


## 按权重随机选择
func _pick_by_weight(weighted_pool: Array[Dictionary]) -> Dictionary:
	if weighted_pool.size() == 0:
		return {}

	var total_weight = 0.0
	for item in weighted_pool:
		total_weight += item["weight"]

	var rand = randf() * total_weight
	var current_weight = 0.0

	for item in weighted_pool:
		current_weight += item["weight"]
		if rand <= current_weight:
			return item["enemy"] as Dictionary

	# 理论上不会到这里
	return weighted_pool[0]["enemy"] as Dictionary


## 根据阶段随机选择商人
## @param stage 当前阶段（1-4）
## @return 商人配置字典，空字典表示失败
func select_merchant(stage: int) -> Dictionary:
	if _enemy_pool.size() == 0:
		# 尝试重新加载
		if not load_enemy_pool(stage):
			return {}

	# 筛选商人（type == 5 且 stage 匹配）
	var merchant_pool: Array[Dictionary] = []
	for hero in _enemy_pool:
		var hero_type = hero.get("type", 1) as int
		var hero_stage = hero.get("stage", 1) as int
		if hero_type == EnemySelector.TYPE_MERCHANT and hero_stage <= stage:
			var weight = 1.0
			if hero_stage == stage:
				weight = 2.0
			merchant_pool.append({"enemy": hero, "weight": weight})

	if merchant_pool.size() == 0:
		push_warning("[EnemySelector] 阶段 ", stage, " 没有可用的商人")
		return {}

	var selected = _pick_by_weight(merchant_pool)
	print("[EnemySelector] 选择商人：", selected.get("name", "Unknown"),
		  " (type=", selected.get("type"), ", stage=", selected.get("stage"), ")")
	return selected


## 清空缓存
func clear():
	_enemy_pool.clear()
	_is_loaded = false


## 获取敌人类型名称
static func get_type_name(type: int) -> String:
	match type:
		TYPE_PLAYER: return "玩家"
		TYPE_NORMAL_ENEMY: return "普通敌人"
		TYPE_ELITE_ENEMY: return "精英敌人"
		TYPE_BOSS: return "Boss"
		TYPE_MERCHANT: return "商人"
		_: return "未知"


## 获取敌人类型颜色
static func get_type_color(type: int) -> Color:
	match type:
		TYPE_PLAYER: return Color(0.3, 0.8, 0.3)    # 绿色 - 玩家
		TYPE_NORMAL_ENEMY: return Color(1, 0.3, 0.3)  # 红色 - 普通敌人
		TYPE_ELITE_ENEMY: return Color(1, 0.5, 0.0)   # 橙色 - 精英敌人
		TYPE_BOSS: return Color(0.8, 0.0, 0.8)        # 紫色 - Boss
		TYPE_MERCHANT: return Color(1.0, 0.84, 0.0)   # 金色 - 商人
		_: return Color(1, 1, 1)                  # 白色 - 未知

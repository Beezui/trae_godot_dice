extends Node
## 奇遇管理器 (Autoload 单例)
## 负责加载奇遇配置、管理奇遇流程、执行效果

# 数据缓存
var adventure_events: Dictionary = {}  # id -> event data
var adventure_results: Dictionary = {}  # id -> result data

# 当前奇遇状态
var current_event: Dictionary = {}
var current_result_ids: Array = []
var current_results: Array = []  # 解析后的结果列表

# 引用
var character_manager = null
var dice_csv_reader = null


func _ready():
	print("【奇遇管理器】奇遇管理器初始化")
	load_adventure_data()


## 获取单例
static func get_instance() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("AdventureManager")


## 加载奇遇数据
func load_adventure_data():
	_load_adventure_events()
	_load_adventure_results()
	print("【奇遇管理器】加载完成，事件数: ", adventure_events.size(), ", 结果数: ", adventure_results.size())


func _load_adventure_events():
	var json_path = "res://table/adventure_events.json"
	var file = FileAccess.open(json_path, FileAccess.READ)

	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_text)

		if parse_result != OK:
			push_error("【奇遇管理器】解析 adventure_events.json 失败: ", json.get_error_message())
			return

		var data = json.get_data()
		if not data is Dictionary or not data.has("adventure_events"):
			push_error("【奇遇管理器】adventure_events.json 缺少 'adventure_events' 数组")
			return

		var events_array = data["adventure_events"]
		for event_data in events_array:
			if event_data is Dictionary and event_data.has("id"):
				var event_id = str(event_data["id"])
				adventure_events[event_id] = event_data

		print("【奇遇管理器】JSON 加载完成，事件数: ", adventure_events.size())
	else:
		push_error("【奇遇管理器】无法打开 adventure_events.json")


func _load_adventure_results():
	var json_path = "res://table/adventure_results.json"
	var file = FileAccess.open(json_path, FileAccess.READ)

	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_text)

		if parse_result != OK:
			push_error("【奇遇管理器】解析 adventure_results.json 失败: ", json.get_error_message())
			return

		var data = json.get_data()
		if not data is Dictionary or not data.has("adventure_results"):
			push_error("【奇遇管理器】adventure_results.json 缺少 'adventure_results' 数组")
			return

		var results_array = data["adventure_results"]
		for result_data in results_array:
			if result_data is Dictionary and result_data.has("id"):
				var result_id = str(result_data["id"])
				adventure_results[result_id] = result_data

		print("【奇遇管理器】JSON 加载完成，结果数: ", adventure_results.size())
	else:
		push_error("【奇遇管理器】无法打开 adventure_results.json")


## 获取奇遇事件
func get_adventure_event(event_id: String) -> Dictionary:
	return adventure_events.get(event_id, {})


## 获取奇遇结果
func get_adventure_result(result_id: String) -> Dictionary:
	return adventure_results.get(result_id, {})


## 获取奇遇结果列表
func get_adventure_results(event_id: String) -> Array:
	var event = adventure_events.get(event_id, {})
	if event.is_empty():
		return []

	var result_ids = event.get("results", [])
	var results: Array = []
	for rid in result_ids:
		var result = adventure_results.get(str(rid), {})
		if not result.is_empty():
			results.append(result)
	return results


## 开始奇遇
func start_adventure(event_id: String) -> bool:
	var event = adventure_events.get(event_id, {})
	if event.is_empty():
		push_error("【奇遇管理器】找不到奇遇事件: ", event_id)
		return false

	current_event = event
	current_result_ids = event.get("results", [])
	current_results = get_adventure_results(event_id)

	print("【奇遇管理器】开始奇遇: ", event.get("name", ""), ", 选项数: ", current_results.size())
	return true


## 获取奇遇骰子面配置
## 根据选项数量动态生成骰面，平均分配
## 返回: { "values": [1,1,2,2,3,3], "textures": [...] }
func get_adventure_dice_config(result_count: int) -> Dictionary:
	var values = []
	var textures = []

	# 每个选项在骰面上分配的面数（6面骰，平均分配）
	var faces_per_result = 6 / result_count
	var remainder = 6 % result_count

	var face_idx = 0
	for i in range(result_count):
		var count = faces_per_result
		# 余数分配给前面的选项
		if i < remainder:
			count += 1
		for j in range(count):
			values.append(i + 1)
			textures.append("adventure_" + str(i + 1))
			face_idx += 1

	# 确保是6面
	while values.size() < 6:
		values.append(result_count)
		textures.append("adventure_" + str(result_count))

	return {
		"values": values,
		"textures": textures
	}


## 根据骰子面索引获取结果
## face_value 是骰子朝上面的值（1-6）
func get_result_from_face(face_value: int) -> Dictionary:
	var dice_config = get_adventure_dice_config(current_result_ids.size())
	var values = dice_config["values"]

	# face_value 是 1-6，对应 values 数组索引
	if face_value < 1 or face_value > values.size():
		push_error("【奇遇管理器】无效的骰子面值: ", face_value)
		return {}

	var result_index = values[face_value - 1] - 1
	if result_index < 0 or result_index >= current_results.size():
		push_error("【奇遇管理器】无效的结果索引: ", result_index)
		return {}

	return current_results[result_index]


## 执行效果
## 根据结果的 effect 和 params 执行对应的效果
## 支持的效果类型：
##   - 单一效果：hp_add, hp_minus, gold_add, gold_minus, str_add, str_minus, agi_add, agi_minus, int_add, int_minus, item_add, item_minus, all_add, all_minus, all_attr_add
##   - 组合效果：用 _and_ 连接，如 gold_add_and_hp_minus
func execute_effect(result_id: String) -> Dictionary:
	var result = adventure_results.get(result_id, {})
	if result.is_empty():
		push_error("【奇遇管理器】找不到结果: ", result_id)
		return {"success": false}

	var effect = result.get("effect", "")
	var params = result.get("params", {})
	var des = _replace_params(result.get("des", ""), params)

	print("【奇遇管理器】执行效果: ", effect, ", 参数: ", params)

	# 处理组合效果（_and_ 分隔）
	var effects = effect.split("_and_")
	var applied_effects: Array = []

	for single_effect in effects:
		var effect_result = _apply_single_effect(single_effect, params, des)
		if effect_result.get("success", false):
			applied_effects.append(effect_result)

	print("【奇遇管理器】效果执行完成: ", des)
	return {"success": true, "effects": applied_effects, "des": des}


## 替换描述中的参数占位符
func _replace_params(text: String, params: Dictionary) -> String:
	var result = text
	for key in params:
		var placeholder = "【" + key + "】"
		result = result.replace(placeholder, str(params[key]))
	return result


## 执行单个效果
func _apply_single_effect(effect_type: String, params: Dictionary, des: String) -> Dictionary:
	var effect_result = {"effect": effect_type, "success": false}

	# 获取 CharacterManager
	if not character_manager:
		character_manager = Engine.get_main_loop().root.get_node_or_null("CharacterManager")

	if not character_manager:
		push_error("【奇遇管理器】CharacterManager 不可用")
		return effect_result

	var player_characters = character_manager.get("player_characters")
	if not player_characters or player_characters.size() == 0:
		push_error("【奇遇管理器】没有玩家角色")
		return effect_result

	# 获取参数值
	var p1_val = _get_param_value(params, "p1")
	var p2_val = _get_param_value(params, "p2")
	var p3_val = _get_param_value(params, "p3")
	var p4_val = _get_param_value(params, "p4")

	match effect_type:
		"hp_add":
			for char in player_characters:
				if char and char.has_method("heal"):
					char.heal(p1_val)
					effect_result["success"] = true
					effect_result["target"] = char.name
					effect_result["value"] = p1_val

		"hp_minus":
			for char in player_characters:
				if char and char.has_method("take_damage"):
					char.take_damage(p1_val)
					effect_result["success"] = true
					effect_result["target"] = char.name
					effect_result["value"] = -p1_val

		"gold_add":
			_apply_gold_change(p1_val)
			effect_result["success"] = true
			effect_result["value"] = p1_val

		"gold_minus":
			_apply_gold_change(-p1_val)
			effect_result["success"] = true
			effect_result["value"] = -p1_val

		"str_add":
			_apply_stat_add("str", p1_val)
			effect_result["success"] = true

		"str_minus":
			_apply_stat_add("str", -p1_val)
			effect_result["success"] = true

		"agi_add":
			_apply_stat_add("agi", p1_val)
			effect_result["success"] = true

		"agi_minus":
			_apply_stat_add("agi", -p1_val)
			effect_result["success"] = true

		"int_add":
			_apply_stat_add("int", p1_val)
			effect_result["success"] = true

		"int_minus":
			_apply_stat_add("int", -p1_val)
			effect_result["success"] = true

		"item_add":
			print("【奇遇管理器】获得道具: ", p1_val, "（道具系统待实现）")
			effect_result["success"] = true
			effect_result["item_id"] = p1_val

		"item_buy":
			_apply_gold_change(-p1_val)
			print("【奇遇管理器】消耗 ", p1_val, " 金币获得道具: ", p2_val, "（道具系统待实现）")
			effect_result["success"] = true
			effect_result["gold_cost"] = p1_val
			effect_result["item_id"] = p2_val

		"all_add":
			# 仅修改 str/agi/int 属性，不包含 HP
			_apply_stat_add("str", p1_val)
			_apply_stat_add("agi", p1_val)
			_apply_stat_add("int", p1_val)
			effect_result["success"] = true

		"all_attr_add":
			# 修改 str/agi/int 属性，不包含 HP（HP 需要单独指定 hp_add）
			_apply_stat_add("str", p1_val)
			_apply_stat_add("agi", p1_val)
			_apply_stat_add("int", p1_val)
			effect_result["success"] = true

		"hp_add_and_gold_add":
			# 组合效果：HP 增加 + 金币增加
			# p1 = HP 值, p2 = 金币值
			for char in player_characters:
				if char and char.has_method("heal"):
					char.heal(p1_val)
			_apply_gold_change(p2_val)
			effect_result["success"] = true

		"hp_add_and_attr_add":
			# 组合效果：HP 增加 + 全属性增加
			# p1 = HP 值, p2 = 属性值
			for char in player_characters:
				if char and char.has_method("heal"):
					char.heal(p1_val)
			_apply_stat_add("str", p2_val)
			_apply_stat_add("agi", p2_val)
			_apply_stat_add("int", p2_val)
			effect_result["success"] = true

		"gold_and_attr_add":
			# 组合效果：金币增加 + 全属性增加
			# p1 = 金币值, p2 = 属性值
			_apply_gold_change(p1_val)
			_apply_stat_add("str", p2_val)
			_apply_stat_add("agi", p2_val)
			_apply_stat_add("int", p2_val)
			effect_result["success"] = true

		"all_minus":
			_apply_stat_add("str", -p1_val)
			_apply_stat_add("agi", -p1_val)
			_apply_stat_add("int", -p1_val)
			effect_result["success"] = true

		_:
			push_warning("【奇遇管理器】未知效果类型: ", effect_type)

	return effect_result


## 对所有玩家角色应用金币变化
func _apply_gold_change(amount: int):
	var player_characters = character_manager.get("player_characters")
	if not player_characters or player_characters.size() == 0:
		return
	# 只改变第一个玩家角色的金币
	var char = player_characters[0]
	if char and "gold" in char:
		char.gold += amount
		print("【奇遇管理器】金币变化: ", amount, ", 当前金币: ", char.gold)


## 对所有玩家角色应用属性变化
func _apply_stat_add(attr_type: String, amount: int):
	var player_characters = character_manager.get("player_characters")
	if not player_characters or player_characters.size() == 0:
		return
	for char in player_characters:
		if not char:
			continue
		# 修改所有骰子面的属性值
		match attr_type:
			"str":
				for i in range(char.attr_str.size()):
					char.attr_str[i] = int(char.attr_str[i]) + amount
			"agi":
				for i in range(char.attr_agi.size()):
					char.attr_agi[i] = int(char.attr_agi[i]) + amount
			"int":
				for i in range(char.attr_int.size()):
					char.attr_int[i] = int(char.attr_int[i]) + amount
		print("【奇遇管理器】", char.name, " ", attr_type, " 变化: ", amount)


## 获取参数值
## 如果参数是字符串，尝试转换为整数
func _get_param_value(params: Dictionary, key: String) -> int:
	if params.has(key):
		var val = params[key]
		if val is int:
			return val
		elif val is String:
			return val.to_int()
	return 0


## 结束奇遇
func end_adventure():
	current_event = {}
	current_result_ids = []
	current_results = []
	print("【奇遇管理器】奇遇结束")

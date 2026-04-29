extends Node
## PlayerData - 玩家数据管理（Autoload 单例）
## 管理玩家拥有的空白骰子实例、技能分配、金币、道具等
## 注意：通过 PlayerData 全局变量访问

# ============================================================================
# 数据结构
# ============================================================================

## 骰子实例数据：{ instance_id: { template_id, name, effect_type, p1-p4, faces } }
## faces: [skill_id, skill_id, ...] 6 个面，"0" 表示未配置
var dice_instances = {}

## 玩家已解锁的技能 ID 列表
var unlocked_skills = []

## 玩家金币
var gold = 0

## 道具列表（预留）
var items = []

## 下一次 instance_id 分配
var _next_instance_id = 10001


# ============================================================================
# 初始化
# ============================================================================

func _ready():
	push_error("[PlayerData] ===== _ready() has been called! =====")
	_print("PlayerData 玩家数据系统已就绪")
	_init_test_data()


## 初始化测试数据（开发阶段使用，后续会被存档加载取代）
func _init_test_data():
	if dice_instances.size() > 0:
		_print("已有骰子实例，跳过测试数据初始化")
		return

	_print("【测试】开始初始化测试数据...")

	# 解锁所有技能
	var skill_reader = preload("res://scripts/skill_csv_reader.gd").new()
	var all_skills = skill_reader.get_all_skills()
	_print("技能数据加载：", all_skills.size(), " 个")
	for skill_id in all_skills.keys():
		unlocked_skills.append(str(skill_id))
	_print("解锁技能：", unlocked_skills.size(), " 个：", unlocked_skills)

	# 创建空白骰子模板实例
	var template_ids = ["6001", "6002", "6003", "6004", "6005", "6006"]
	for template_id in template_ids:
		var instance_id = create_dice_instance(template_id)
		_print("创建骰子实例：template_id=", template_id, " -> instance_id=", instance_id)
	_print("骰子实例总数：", dice_instances.size(), "，keys=", dice_instances.keys())


@warning_ignore("shadowed_global_identifier")
func _print(arg1, arg2=null, arg3=null, arg4=null, arg5=null, arg6=null, arg7=null, arg8=null):
	var args = [arg1]
	for a in [arg2, arg3, arg4, arg5, arg6, arg7, arg8]:
		if a != null:
			args.append(a)
	var prefix = "[PlayerData] "
	args[0] = prefix + str(args[0])
	match args.size():
		1: print(args[0])
		2: print(args[0], args[1])
		3: print(args[0], args[1], args[2])
		4: print(args[0], args[1], args[2], args[3])
		5: print(args[0], args[1], args[2], args[3], args[4])
		6: print(args[0], args[1], args[2], args[3], args[4], args[5])
		7: print(args[0], args[1], args[2], args[3], args[4], args[5], args[6])
		8: print(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])


# ============================================================================
# 骰子实例管理
# ============================================================================

## 创建骰子实例（从空白骰子模板）
## @param template_id 空白骰子模板 ID（来自 BlankDices.json）
## @param assign_skill_ids 可选：预分配技能 ID 数组（6 个）
## @return instance_id
func create_dice_instance(template_id: String, assign_skill_ids: Array = []) -> int:
	var blank_reader = preload("res://scripts/blank_dice_csv_reader.gd").new()
	var template = blank_reader.get_blank_dice_config(template_id)
	if template.is_empty():
		push_error("[PlayerData] 空白骰子模板不存在：", template_id)
		return -1

	var instance_id = _next_instance_id
	_next_instance_id += 1

	# 初始化 6 面为空
	var faces = ["0", "0", "0", "0", "0", "0"]
	for i in range(min(assign_skill_ids.size(), 6)):
		if assign_skill_ids[i] != null and str(assign_skill_ids[i]) != "0":
			faces[i] = str(assign_skill_ids[i])

	dice_instances[instance_id] = {
		"template_id": str(template_id),
		"name": template.get("name", "未知骰子"),
		"description": template.get("description", ""),
		"effect_type": template.get("effect_type", ""),
		"p1": template.get("p1", "0"),
		"p2": template.get("p2", "0"),
		"p3": template.get("p3", "0"),
		"p4": template.get("p4", "0"),
		"texture": template.get("texture", ""),
		"icon": template.get("icon", ""),
		"faces": faces
	}

	_print("创建骰子实例：instance_id=", instance_id, " 模板=", template.get("name", ""))
	return instance_id


## 获取骰子实例数据
## @param instance_id 骰子实例 ID
## @return Dictionary 骰子实例数据（含 template_id, faces 等）
func get_dice_instance(instance_id: int) -> Dictionary:
	return dice_instances.get(instance_id, {})


## 删除骰子实例
## @param instance_id 骰子实例 ID
func remove_dice_instance(instance_id: int):
	if dice_instances.has(instance_id):
		var name = dice_instances[instance_id].get("name", "")
		dice_instances.erase(instance_id)
		_print("删除骰子实例：instance_id=", instance_id, " 名称=", name)


## 获取所有骰子实例 ID
func get_all_dice_instance_ids() -> Array:
	return dice_instances.keys()


## 获取骰子实例数量
func get_dice_instance_count() -> int:
	return dice_instances.size()


# ============================================================================
# 技能分配管理
# ============================================================================

## 分配技能到骰子某面
## @param instance_id 骰子实例 ID
## @param face_index 面索引 (0-5)
## @param skill_id 技能 ID，传 "0" 或空表示清除
func assign_skill_to_face(instance_id: int, face_index: int, skill_id: String):
	if not dice_instances.has(instance_id):
		push_error("[PlayerData] 骰子实例不存在：instance_id=", instance_id)
		return

	if face_index < 0 or face_index > 5:
		push_error("[PlayerData] 面索引超出范围：", face_index)
		return

	var instance = dice_instances[instance_id]
	var old_skill = instance["faces"][face_index]
	instance["faces"][face_index] = str(skill_id) if skill_id != null else "0"

	_print("分配技能：实例=", instance.get("name", ""), " 面=", face_index,
		" 旧技能=", old_skill, " → 新技能=", instance["faces"][face_index])


## 获取骰子某面分配的技能 ID
## @param instance_id 骰子实例 ID
## @param face_index 面索引 (0-5)
## @return String 技能 ID，"0" 表示未配置
func get_skill_on_face(instance_id: int, face_index: int) -> String:
	if not dice_instances.has(instance_id):
		return "0"

	var instance = dice_instances[instance_id]
	var faces = instance.get("faces", [])
	if face_index < 0 or face_index >= faces.size():
		return "0"

	return str(faces[face_index])


## 获取骰子所有面的技能 ID 数组
## @param instance_id 骰子实例 ID
## @return Array 技能 ID 数组（6 个）
func get_all_skills_on_dice(instance_id: int) -> Array:
	if not dice_instances.has(instance_id):
		return ["0", "0", "0", "0", "0", "0"]
	return dice_instances[instance_id].get("faces", ["0", "0", "0", "0", "0", "0"]).duplicate()


# ============================================================================
# 技能解锁管理
# ============================================================================

## 解锁新技能
## @param skill_id 技能 ID
func unlock_skill(skill_id: String):
	var sid = str(skill_id)
	if not unlocked_skills.has(sid):
		unlocked_skills.append(sid)
		_print("解锁技能：", sid)


## 检查技能是否已解锁
## @param skill_id 技能 ID
## @return bool
func is_skill_unlocked(skill_id: String) -> bool:
	return unlocked_skills.has(str(skill_id))


## 获取所有已解锁技能 ID
func get_all_unlocked_skills() -> Array:
	return unlocked_skills.duplicate()


# ============================================================================
# 金币管理
# ============================================================================

## 获取当前金币
func get_gold() -> int:
	return gold


## 增加金币
func add_gold(amount: int):
	gold += amount
	_print("获得金币：+", amount, " 总计：", gold)


## 消耗金币
## @return bool 是否成功（金币足够）
func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		_print("消耗金币：-", amount, " 剩余：", gold)
		return true
	push_error("[PlayerData] 金币不足：需要 ", amount, " 拥有 ", gold)
	return false


# ============================================================================
# 道具管理（预留）
# ============================================================================

## 添加道具
func add_item(item_id: String, quantity: int = 1):
	items.append({"id": item_id, "quantity": quantity})
	_print("获得道具：", item_id, " x", quantity)


## 获取道具数量
func get_item_count(item_id: String) -> int:
	var total = 0
	for item in items:
		if item.get("id", "") == item_id:
			total += item.get("quantity", 0)
	return total


## 消耗道具
func spend_item(item_id: String, quantity: int = 1) -> bool:
	var total = get_item_count(item_id)
	if total >= quantity:
		# 简化实现：直接移除指定数量的道具条目
		var removed = 0
		var i = items.size() - 1
		while i >= 0 and removed < quantity:
			var item = items[i]
			if item.get("id", "") == item_id:
				var qty = item.get("quantity", 0)
				if qty <= (quantity - removed):
					removed += qty
					items.remove_at(i)
				else:
					item["quantity"] = qty - (quantity - removed)
					removed = quantity
			i -= 1
		_print("消耗道具：", item_id, " x", quantity)
		return true
	return false


# ============================================================================
# 被动效果查询
# ============================================================================

## 获取骰子实例的被动效果类型
func get_dice_effect_type(instance_id: int) -> String:
	if not dice_instances.has(instance_id):
		return ""
	return dice_instances[instance_id].get("effect_type", "")


## 获取骰子实例的被动效果参数
## @param instance_id 骰子实例 ID
## @param param_name 参数名 ("p1", "p2", ...)
## @return int 参数值
func get_dice_effect_param(instance_id: int, param_name: String) -> int:
	if not dice_instances.has(instance_id):
		return 0
	var val = dice_instances[instance_id].get(param_name, "0")
	if val is String:
		return val.to_int()
	return val


## 获取骰子实例的模板 ID
func get_dice_template_id(instance_id: int) -> String:
	if not dice_instances.has(instance_id):
		return ""
	return dice_instances[instance_id].get("template_id", "")


# ============================================================================
# 数据持久化（预留）
# ============================================================================

## 保存玩家数据到文件
func save_data(file_path: String = "user://player_data.json"):
	var data = {
		"dice_instances": {},
		"unlocked_skills": unlocked_skills,
		"gold": gold,
		"next_instance_id": _next_instance_id
	}

	# 转换 dice_instances（int key 转 string）
	for instance_id in dice_instances:
		data["dice_instances"][str(instance_id)] = dice_instances[instance_id]

	var json_string = JSON.stringify(data)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_line(json_string)
		file.close()
		_print("数据已保存：", file_path)
	else:
		push_error("[PlayerData] 保存失败：无法打开文件 ", file_path)


## 从文件加载玩家数据
func load_data(file_path: String = "user://player_data.json"):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		_print("存档文件不存在，使用默认数据")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("[PlayerData] 存档解析失败：", json.get_error_message())
		return

	var data = json.get_data()
	if not data is Dictionary:
		push_error("[PlayerData] 存档格式错误")
		return

	# 恢复数据
	unlocked_skills = data.get("unlocked_skills", [])
	gold = data.get("gold", 0)
	_next_instance_id = data.get("next_instance_id", 10001)

	# 恢复 dice_instances（string key 转 int）
	var raw_instances = data.get("dice_instances", {})
	for key in raw_instances:
		var int_key = key.to_int()
		dice_instances[int_key] = raw_instances[key]

	_print("数据已加载：骰子=", dice_instances.size(), " 技能=", unlocked_skills.size(), " 金币=", gold)


## 清除所有数据
func reset():
	dice_instances.clear()
	unlocked_skills.clear()
	items.clear()
	gold = 0
	_next_instance_id = 10001
	_print("数据已重置")

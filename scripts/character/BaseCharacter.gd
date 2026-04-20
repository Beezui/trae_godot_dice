class_name BaseCharacter
extends RefCounted

## 角色唯一标识 (hero_id)
var hero_id: int

## 角色显示名称
var name: String

## 基础属性
var attr_str: Array  # 力量 (6 个面)
var attr_agi: Array  # 敏捷 (6 个面)
var attr_int: Array  # 智力 (6 个面)
var attr_hp: int     # 血量
var current_hp: int  # 当前血量
var attr_mp: int = 50     # 魔法值上限
var current_mp: int = 50  # 当前魔法值
var mp_name: String = "MP"  # MP 显示名称

## 技能槽位数量
var skill_slot: int

## 技能骰子 ID 数组
var skill_dice_ids: Array

## 角色贴图 ID 数组
var texture_ids: Array

## 立绘 ID
var portrait_id: String

## 角色状态贴图 (idle, hit, attack, anger, happy, die)
var hero_textures: Array

## 角色骰子引用
var character_dice: RigidBody3D

## 属性骰子引用 (str, agi, int)
var attribute_dices: Dictionary = {}

## 技能骰子引用
var skill_dices: Array = []

## 是否是玩家控制角色
var is_player: bool = false

## 角色状态 (idle, hit, attack, anger, happy, die)
var current_state: String = "idle"

## 角色骰子缩放比例（默认 1.5 倍）
var dice_scale: Vector3 = Vector3(1.5, 1.5, 1.5)


func _init(data: Dictionary = {}):
	"""
	初始化角色
	:param data: 角色数据字典，包含 hero_id, name, attr_str 等
	"""
	if data.size() > 0:
		load_from_data(data)


func load_from_data(data: Dictionary):
	"""
	从数据字典加载角色信息
	:param data: 来自 hero.json 的数据
	"""
	# 解析 hero_id（从字符串转换为整数）
	var id_value = data.get("id", "0")
	hero_id = int(id_value) if id_value is String else id_value

	name = data.get("name", "未知角色")

	# 解析属性数组
	attr_str = _parse_array(data.get("attr_str", []))
	attr_agi = _parse_array(data.get("attr_agi", []))
	attr_int = _parse_array(data.get("attr_int", []))

	# 解析血量
	var hp_value = data.get("attr_hp", "100")
	attr_hp = int(hp_value) if hp_value is String else hp_value
	current_hp = attr_hp

	# 解析魔法值（如果 hero.json 中有配置）
	var mp_value = data.get("attr_mp", "50")
	attr_mp = int(mp_value) if mp_value is String else mp_value
	current_mp = attr_mp

	# 解析 MP 名称（如果 hero.json 中有配置）
	mp_name = data.get("mp_name", "MP")

	# 解析技能槽位
	var slot_value = data.get("skill_slot", "1")
	skill_slot = int(slot_value) if slot_value is String else slot_value

	# 解析技能骰子 ID
	skill_dice_ids = _parse_array(data.get("skill_dice_id", []))

	# 解析贴图 ID
	texture_ids = _parse_array(data.get("texture", []))

	# 解析立绘 ID
	portrait_id = str(data.get("portrait", "1"))

	# 解析角色状态贴图
	hero_textures = _parse_array(data.get("hero_texture", []))

	print("【BaseCharacter】加载角色数据：", name, " (ID: ", hero_id, ")")


func _parse_array(data) -> Array:
	"""
	解析数组数据，兼容字符串和数组格式
	:param data: 可能是字符串数组或分号分隔的字符串
	:return: 字符串数组
	"""
	if data is Array:
		return data
	elif data is String:
		if data.contains(";"):
			return data.split(";")
		else:
			return [data]
	else:
		return []


func take_damage(damage: int) -> int:
	"""
	承受伤害
	:param damage: 伤害值
	:return: 实际受到的伤害
	"""
	if current_hp <= 0:
		return 0

	current_hp = max(0, current_hp - damage)
	print("【BaseCharacter】", name, " 受到 ", damage, " 点伤害，剩余 HP: ", current_hp)

	# 更新状态为受击
	set_state("hit")

	# 播放受击效果（骰子抖动 + 贴图切换）
	if character_dice and is_instance_valid(character_dice):
		if character_dice.has_method("take_hit_effect"):
			character_dice.take_hit_effect()

	# 更新血条显示（如果骰子已创建）
	update_health_bar()

	return damage


func heal(amount: int) -> int:
	"""
	治疗
	:param amount: 治疗量
	:return: 实际治疗量
	"""
	if current_hp >= attr_hp:
		return 0

	var old_hp = current_hp
	current_hp = min(attr_hp, current_hp + amount)
	var actual_heal = current_hp - old_hp

	print("【BaseCharacter】", name, " 恢复 ", actual_heal, " 点 HP，当前 HP: ", current_hp)

	# 更新血条显示（如果骰子已创建）
	update_health_bar()

	return actual_heal


func is_alive() -> bool:
	"""
	检查是否存活
	:return: true 如果 HP > 0
	"""
	return current_hp > 0


func is_defeated() -> bool:
	"""
	检查是否被击败
	:return: true 如果 HP <= 0
	"""
	return current_hp <= 0


func set_state(state: String):
	"""
	设置角色状态
	:param state: 状态名称 (idle, hit, attack, anger, happy, die)
	"""
	if state in ["idle", "hit", "attack", "anger", "happy", "die"]:
		current_state = state
		print("【BaseCharacter】", name, " 状态变更为：", state)


func set_character_dice_scale(scale: Vector3):
	"""
	设置角色骰子的缩放比例
	注意：直接缩放 RigidBody3D 节点，这样网格和碰撞体会同步缩放
	:param scale: 缩放比例向量
	"""
	if character_dice and is_instance_valid(character_dice):
		# 优先使用骰子自身的 set_dice_scale 方法
		if character_dice.has_method("set_dice_scale"):
			character_dice.set_dice_scale(scale)
			print("【BaseCharacter】调用 dice.set_dice_scale() 设置缩放：", scale)
		else:
			# 备用方案：直接设置根节点缩放
			character_dice.scale = scale
			print("【BaseCharacter】直接设置根节点缩放：", scale)

			# 同步调整碰撞体大小
			var collision_shape = character_dice.get_node_or_null("CollisionShape3D")
			if collision_shape and collision_shape.shape:
				var base_size = Vector3(1, 1, 1)
				collision_shape.shape.size = base_size * scale
				print("【BaseCharacter】碰撞体已同步调整：", collision_shape.shape.size)


func get_attribute_value(attr_type: String, face_index: int = 0) -> int:
	"""
	获取属性值
	:param attr_type: 属性类型 (str, agi, int)
	:param face_index: 骰子面索引 (0-5)
	:return: 属性值
	"""
	match attr_type:
		"str":
			if attr_str.size() > face_index:
				return int(attr_str[face_index]) if attr_str[face_index] is String else attr_str[face_index]
		"agi":
			if attr_agi.size() > face_index:
				return int(attr_agi[face_index]) if attr_agi[face_index] is String else attr_agi[face_index]
		"int":
			if attr_int.size() > face_index:
				return int(attr_int[face_index]) if attr_int[face_index] is String else attr_int[face_index]

	return 0


func get_hp_percentage() -> float:
	"""
	获取血量百分比
	:return: 0.0-1.0 之间的值
	"""
	if attr_hp <= 0:
		return 0.0
	return float(current_hp) / float(attr_hp)


func get_config() -> Dictionary:
	"""
	获取角色配置字典
	:return: 包含角色所有配置的字典
	"""
	return {
		"hero_id": hero_id,
		"name": name,
		"attr_str": attr_str,
		"attr_agi": attr_agi,
		"attr_int": attr_int,
		"attr_hp": attr_hp,
		"current_hp": current_hp,
		"attr_mp": attr_mp,
		"current_mp": current_mp,
		"mp_name": mp_name,
		"skill_slot": skill_slot,
		"skill_dice_ids": skill_dice_ids,
		"texture_ids": texture_ids,
		"portrait_id": portrait_id,
		"hero_textures": hero_textures,
		"dice_scale": dice_scale
	}


## 获取角色骰子缩放比例
func get_dice_scale() -> Vector3:
	"""
	获取角色骰子的缩放比例
	:return: 缩放比例向量
	"""
	return dice_scale


## 设置角色骰子缩放比例
func set_dice_scale(scale: Vector3):
	"""
	设置角色骰子的缩放比例
	:param scale: 缩放比例向量
	"""
	dice_scale = scale
	# 如果骰子已经存在，立即应用缩放
	if character_dice and is_instance_valid(character_dice):
		set_character_dice_scale(scale)


func recover_mp(amount: int) -> int:
	"""
	恢复魔法值
	:param amount: 恢复量
	:return: 实际恢复量
	"""
	if current_mp >= attr_mp:
		return 0

	var old_mp = current_mp
	current_mp = min(attr_mp, current_mp + amount)
	var actual_recover = current_mp - old_mp

	print("【BaseCharacter】", name, " 恢复 ", actual_recover, " 点 MP，当前 MP: ", current_mp)
	return actual_recover


func take_mp_cost(amount: int) -> bool:
	"""
	消耗魔法值
	:param amount: 消耗量
	:return: true 如果消耗成功
	"""
	if not can_afford_mp(amount):
		return false

	current_mp -= amount
	print("【BaseCharacter】", name, " 消耗 ", amount, " 点 MP，剩余 MP: ", current_mp)
	return true


func can_afford_mp(amount: int) -> bool:
	"""
	检查是否有足够 MP
	:param amount: 需要的 MP 量
	:return: true 如果 MP 足够
	"""
	return current_mp >= amount


func update_health_bar():
	"""
	更新角色骰子上的 3D 血条显示
	调用时机：HP 变化时（受到伤害或治疗）
	"""
	if character_dice and is_instance_valid(character_dice):
		if character_dice.has_method("update_hp_text"):
			character_dice.update_hp_text(current_hp, attr_hp)
			print("【BaseCharacter】已更新血条显示：", current_hp, "/", attr_hp)

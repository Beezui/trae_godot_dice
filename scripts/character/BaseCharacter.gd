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
		"skill_slot": skill_slot,
		"skill_dice_ids": skill_dice_ids,
		"texture_ids": texture_ids,
		"portrait_id": portrait_id,
		"hero_textures": hero_textures
	}

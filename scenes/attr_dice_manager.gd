extends Node

var attr_dices: Dictionary = {}
var hero_reader = null
var hero_data: Dictionary = {}

func _ready():
	# 初始化英雄数据读取器
	hero_reader = preload("res://scripts/hero_csv_reader.gd").new()
	hero_data = hero_reader.get_all_heroes()
	print("Attribute Dice Manager initialized")

func create_attribute_dice(hero_id: int, attr_type: String, scene: Node = null) -> Node:
	# 为指定角色创建属性骰子
	if not hero_data.has(str(hero_id)):
		print("Error: Hero not found with ID ", hero_id)
		return null
	
	var hero_info = hero_data[str(hero_id)]
	var hero_attributes = {
		"attr_str": hero_info.get("attr_str", [10, 20, 30, 40, 50, 60]),
		"attr_agi": hero_info.get("attr_agi", [10, 20, 30, 40, 50, 60]),
		"attr_int": hero_info.get("attr_int", [10, 20, 30, 40, 50, 60])
	}
	
	# 处理 texture 字段
	var hero_textures = []
	var texture_data = hero_info.get("texture", [])
	if typeof(texture_data) == TYPE_ARRAY:
		hero_textures = texture_data
	else:
		hero_textures = str(texture_data).split(",")
	
	# 创建属性骰子实例
	var attr_dice_scene = preload("res://scenes/attr_dice.tscn")
	var attr_dice = attr_dice_scene.instantiate()
	
	# 设置属性骰子参数
	attr_dice.attr_type = attr_type
	attr_dice.hero_id = hero_id
	attr_dice.update_attributes(hero_attributes, hero_textures)
	
	# 确保骰子可见
	attr_dice.visible = true
	
	# 添加到场景
	if scene:
		scene.add_child.call_deferred(attr_dice)
	
	# 存储属性骰子
	var key = str(hero_id) + "_" + attr_type
	attr_dices[key] = attr_dice
	
	print("Created attribute dice for hero ", hero_id, " (", attr_type, ")")
	print("Texture paths: ", hero_textures)
	return attr_dice

func get_attribute_dice(hero_id: int, attr_type: String) -> Node:
	# 获取指定角色的属性骰子
	var key = str(hero_id) + "_" + attr_type
	return attr_dices.get(key, null)

func get_all_attribute_dices(hero_id: int) -> Array:
	# 获取指定角色的所有属性骰子
	var dices = []
	for key in attr_dices.keys():
		if key.begins_with(str(hero_id) + "_"):
			dices.append(attr_dices[key])
	return dices

func update_hero_attributes(hero_id: int):
	# 更新角色属性，同时更新对应的属性骰子
	if not hero_data.has(str(hero_id)):
		print("Error: Hero not found with ID ", hero_id)
		return
	
	# 重新读取英雄数据
	hero_data = hero_reader.get_all_heroes()
	var hero_info = hero_data[str(hero_id)]
	var hero_attributes = {
		"attr_str": hero_info.get("attr_str", [10, 20, 30, 40, 50, 60]),
		"attr_agi": hero_info.get("attr_agi", [10, 20, 30, 40, 50, 60]),
		"attr_int": hero_info.get("attr_int", [10, 20, 30, 40, 50, 60])
	}
	
	# 处理texture字段
	var hero_textures = []
	var texture_data = hero_info.get("texture", [])
	if typeof(texture_data) == TYPE_ARRAY:
		hero_textures = texture_data
	else:
		hero_textures = str(texture_data).split(",")
	
	# 更新所有相关的属性骰子
	for key in attr_dices.keys():
		if key.begins_with(str(hero_id) + "_"):
			var dice = attr_dices[key]
			if dice and is_instance_valid(dice):
				dice.update_attributes(hero_attributes, hero_textures)
				print("Updated attribute dice for hero ", hero_id, " (", dice.attr_type, ")")

func remove_attribute_dice(hero_id: int, attr_type: String):
	# 移除指定角色的属性骰子
	var key = str(hero_id) + "_" + attr_type
	if attr_dices.has(key):
		var dice = attr_dices[key]
		if dice and is_instance_valid(dice):
			dice.queue_free()
		attr_dices.erase(key)
		print("Removed attribute dice for hero ", hero_id, " (", attr_type, ")")

func remove_all_attribute_dices(hero_id: int):
	# 移除指定角色的所有属性骰子
	var keys_to_remove = []
	for key in attr_dices.keys():
		if key.begins_with(str(hero_id) + "_"):
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		var dice = attr_dices[key]
		if dice and is_instance_valid(dice):
			dice.queue_free()
		attr_dices.erase(key)
		print("Removed attribute dice: ", key)

func get_hero_attribute(hero_id: int, attr_type: String) -> Array:
	# 获取角色的属性值
	if not hero_data.has(str(hero_id)):
		print("Error: Hero not found with ID ", hero_id)
		return [10, 20, 30, 40, 50, 60]
	
	var hero_info = hero_data[str(hero_id)]
	match attr_type:
		"str":
			return hero_info.get("attr_str", [10, 20, 30, 40, 50, 60])
		"agi":
			return hero_info.get("attr_agi", [10, 20, 30, 40, 50, 60])
		"int":
			return hero_info.get("attr_int", [10, 20, 30, 40, 50, 60])
		_:
			return [10, 20, 30, 40, 50, 60]

func get_hero_textures(hero_id: int) -> Array:
	# 获取角色的骰子贴图
	if not hero_data.has(str(hero_id)):
		print("Error: Hero not found with ID ", hero_id)
		return []
	
	var hero_info = hero_data[str(hero_id)]
	var texture_str = hero_info.get("texture", "")
	return texture_str.split(",")

func refresh_hero_data():
	# 刷新英雄数据
	hero_data = hero_reader.get_all_heroes()
	print("Hero data refreshed")

func get_hero_count() -> int:
	# 获取英雄数量
	return hero_data.size()

func get_hero_info(hero_id: int) -> Dictionary:
	# 获取英雄信息
	return hero_data.get(str(hero_id), {})

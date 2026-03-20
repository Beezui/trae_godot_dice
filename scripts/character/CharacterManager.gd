extends Node

## 角色管理器 (Autoload 单例)
## 负责管理所有角色的创建、生命周期和状态

## 所有角色实例 (按 hero_id 索引)
var characters: Dictionary = {}

## 玩家角色列表
var player_characters: Array = []

## 敌人角色列表
var enemy_characters: Array = []

## 英雄数据缓存
var hero_data_cache: Dictionary = {}


func _ready():
	"""
	初始化角色管理器
	"""
	print("【CharacterManager】角色管理器已就绪")
	_load_hero_data()


func _load_hero_data():
	"""
	从 hero.json 加载英雄数据到缓存
	"""
	var DiceCSVReaderClass = load("res://scripts/hero_csv_reader.gd")
	if DiceCSVReaderClass:
		var reader = DiceCSVReaderClass.new()
		var heroes = reader.get_all_heroes()
		for hero_id in heroes:
			hero_data_cache[hero_id] = heroes[hero_id]
		print("【CharacterManager】已加载 ", heroes.size(), " 个英雄数据到缓存")
	else:
		printerr("【CharacterManager】无法加载 hero_csv_reader.gd")


func create_character(hero_id: int, character_type: String = "player") -> BaseCharacter:
	"""
	创建角色
	:param hero_id: 英雄 ID
	:param character_type: 角色类型 ("player" 或 "enemy")
	:return: 创建的角色实例
	"""
	var hero_key = str(hero_id)
	
	# 从缓存获取英雄数据
	if not hero_data_cache.has(hero_key):
		printerr("【CharacterManager】未找到英雄 ID: ", hero_id, " 的数据")
		return null
	
	var hero_data = hero_data_cache[hero_key]
	
	# 根据类型创建角色
	var character: BaseCharacter
	if character_type == "player":
		character = PlayerCharacter.new(hero_data)
		player_characters.append(character)
	elif character_type == "enemy":
		character = EnemyCharacter.new(hero_data)
		enemy_characters.append(character)
	else:
		printerr("【CharacterManager】未知角色类型：", character_type)
		return null
	
	# 存储到角色字典
	characters[hero_key] = character
	
	print("【CharacterManager】创建 ", character_type, " 角色：", character.name, " (ID: ", hero_id, ")")
	return character


func get_character(hero_id: int) -> BaseCharacter:
	"""
	获取角色实例
	:param hero_id: 英雄 ID
	:return: 角色实例，如果不存在则返回 null
	"""
	var hero_key = str(hero_id)
	if characters.has(hero_key):
		return characters[hero_key]
	return null


func get_player_character(hero_id: int) -> PlayerCharacter:
	"""
	获取玩家角色实例
	:param hero_id: 英雄 ID
	:return: 玩家角色实例，如果不是玩家角色则返回 null
	"""
	var character = get_character(hero_id)
	if character is PlayerCharacter:
		return character
	return null


func get_enemy_character(hero_id: int) -> EnemyCharacter:
	"""
	获取敌人角色实例
	:param hero_id: 英雄 ID
	:return: 敌人角色实例，如果不是敌人角色则返回 null
	"""
	var character = get_character(hero_id)
	if character is EnemyCharacter:
		return character
	return null


func remove_character(hero_id: int) -> bool:
	"""
	移除角色
	:param hero_id: 英雄 ID
	:return: true 如果成功移除
	"""
	var hero_key = str(hero_id)
	
	if not characters.has(hero_key):
		return false
	
	var character = characters[hero_key]
	
	# 从列表中移除
	if character is PlayerCharacter:
		player_characters.erase(character)
	elif character is EnemyCharacter:
		enemy_characters.erase(character)
	
	# 从字典中移除
	characters.erase(hero_key)
	
	print("【CharacterManager】已移除角色：", character.name if character else "未知", " (ID: ", hero_id, ")")
	return true


func get_all_characters() -> Array:
	"""
	获取所有角色
	:return: 所有角色实例数组
	"""
	var all_chars = []
	all_chars.append_array(player_characters)
	all_chars.append_array(enemy_characters)
	return all_chars


func get_all_player_characters() -> Array:
	"""
	获取所有玩家角色
	:return: 玩家角色数组
	"""
	return player_characters.duplicate()


func get_all_enemy_characters() -> Array:
	"""
	获取所有敌人角色
	:return: 敌人角色数组
	"""
	return enemy_characters.duplicate()


func clear_all_characters():
	"""
	清空所有角色
	"""
	characters.clear()
	player_characters.clear()
	enemy_characters.clear()
	print("【CharacterManager】已清空所有角色")


func get_alive_characters() -> Array:
	"""
	获取所有存活的角色
	:return: 存活角色数组
	"""
	var alive_chars = []
	for character in get_all_characters():
		if character.is_alive():
			alive_chars.append(character)
	return alive_chars


func get_defeated_characters() -> Array:
	"""
	获取所有被击败的角色
	:return: 被击败角色数组
	"""
	var defeated_chars = []
	for character in get_all_characters():
		if character.is_defeated():
			defeated_chars.append(character)
	return defeated_chars


func get_hero_data(hero_id: int) -> Dictionary:
	"""
	获取英雄原始数据（从缓存）
	:param hero_id: 英雄 ID
	:return: 英雄数据字典
	"""
	var hero_key = str(hero_id)
	if hero_data_cache.has(hero_key):
		return hero_data_cache[hero_key].duplicate(true)
	return {}


func has_character(hero_id: int) -> bool:
	"""
	检查角色是否存在
	:param hero_id: 英雄 ID
	:return: true 如果角色存在
	"""
	return characters.has(str(hero_id))


func get_character_count() -> int:
	"""
	获取角色总数
	:return: 角色数量
	"""
	return characters.size()

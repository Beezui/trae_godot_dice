extends Node

func _ready():
	print("=== Testing Attribute Dice System ===")
	
	# 测试 1: 初始化 hero_csv_reader
	print("\n1. Testing hero_csv_reader initialization...")
	var hero_reader = preload("res://scripts/hero_csv_reader.gd").new()
	var all_heroes = hero_reader.get_all_heroes()
	print("Hero count: ", hero_reader.get_hero_count())
	print("Heroes: ", all_heroes)
	
	# 测试 2: 读取英雄数据
	print("\n2. Testing hero data reading...")
	var hero_1 = hero_reader.get_hero("1")
	print("Hero 1: ", hero_1)
	
	# 测试 3: 初始化 attr_dice_manager
	print("\n3. Testing attr_dice_manager initialization...")
	var attr_dice_manager = Node3D.new()
	attr_dice_manager.name = "attr_dice_manager"
	attr_dice_manager.script = preload("res://scenes/attr_dice_manager.gd")
	add_child(attr_dice_manager)
	print("attr_dice_manager created")
	
	# 测试 4: 尝试创建属性骰子
	print("\n4. Testing attribute dice creation...")
	var str_dice = attr_dice_manager.create_attribute_dice(1, "str", self)
	print("Strength dice created: ", str_dice != null)
	
	if str_dice:
		print("Strength dice attributes: ")
		print("  attr_type: ", str_dice.attr_type)
		print("  hero_id: ", str_dice.hero_id)
		print("  position: ", str_dice.position)
	
	print("\n=== Test Complete ===")

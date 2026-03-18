extends Node3D

@onready var attr_dice_manager = $attr_dice_manager
var attr_dice = null

func _ready():
	# 打印场景初始化信息
	print("=== Attribute Dice Debug Test ===")
	
	# 获取属性骰子管理器
	if not attr_dice_manager:
		print("Error: attr_dice_manager not found")
		return
	
	# 创建一个力量属性骰子
	print("Creating strength attribute dice...")
	attr_dice = attr_dice_manager.create_attribute_dice(1, "str", self)
	
	if attr_dice:
		attr_dice.position = Vector3(0, 2, 0)
		attr_dice.gravity_scale = 0.0
		print("Created attribute dice successfully")
		print("Attribute type: ", attr_dice.attr_type)
		print("Hero ID: ", attr_dice.hero_id)
		print("Attribute values: ", attr_dice.attr_values)
		print("Attribute textures: ", attr_dice.attr_textures)
	else:
		print("Failed to create attribute dice")
	
	print("=== Debug Test Complete ===")
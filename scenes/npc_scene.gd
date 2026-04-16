extends Node3D
## 简易 NPC 场景
## 仅包含角色模型，没有地面、围墙、骰子等测试场景元素
## 用于在关卡场景中被实例化为 NPC

## 角色数据
var hero_data: Dictionary = {}

## 角色模型节点
var character_model: Node3D = null


func _ready():
	# NPC 场景不需要特殊初始化
	# 所有配置通过 set_hero_data() 进行
	pass


## 设置角色数据
## @param data 英雄数据字典（从 hero.json 读取）
func set_hero_data(data: Dictionary) -> void:
	hero_data = data

	# 设置节点名称
	if data.has("name"):
		name = data["name"]

	# 这里可以扩展：
	# - 加载 3D 角色模型
	# - 设置角色属性
	# - 添加对话功能
	# - 添加交互功能

	print("【NPC】已设置数据：%s" % data.get("name", "Unknown"))


## 获取角色数据
func get_hero_data() -> Dictionary:
	return hero_data


## 获取 NPC 位置
func get_position() -> Vector3:
	return position


## 设置 NPC 位置
func set_position(pos: Vector3) -> void:
	position = pos

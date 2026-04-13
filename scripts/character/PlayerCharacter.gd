class_name PlayerCharacter
extends BaseCharacter

## 是否是玩家控制角色
var is_player_controlled: bool = true


func _init(data: Dictionary = {}):
	super._init(data)
	is_player = true
	is_player_controlled = true
	print("【PlayerCharacter】创建玩家角色：", name if data.size() > 0 else "未命名")


func can_use_skill() -> bool:
	"""
	检查是否可以使用技能
	:return: true 如果角色存活且有技能骰子
	"""
	return is_alive() and skill_dices.size() > 0


func can_attack() -> bool:
	"""
	检查是否可以攻击
	:return: true 如果角色存活
	"""
	return is_alive()


func get_attribute_dice_position(attr_type: String) -> Vector3:
	"""
	获取属性骰子的位置
	:param attr_type: 属性类型 (str, agi, int)
	:return: 骰子位置
	"""
	# 根据属性类型返回不同的位置
	# 这些位置是相对于角色骰子的偏移
	match attr_type:
		"str":
			return Vector3(-2, 0, 2)  # 力量骰子在左侧
		"agi":
			return Vector3(0, 0, 2)   # 敏捷骰子在中间
		"int":
			return Vector3(2, 0, 2)   # 智力骰子在右侧
		_:
			return Vector3(0, 0, 2)


func get_skill_dice_position(index: int) -> Vector3:
	"""
	获取技能骰子的位置
	:param index: 技能骰子索引
	:return: 骰子位置
	"""
	# 技能骰子在角色前方排成一排
	var base_position = Vector3(0, 0, 4)
	var offset = (index - float(skill_dices.size() - 1) / 2.0) * 2.0
	return base_position + Vector3(offset, 0, 0)


func reset_to_idle():
	"""
	重置角色到空闲状态
	"""
	set_state("idle")
	print("【PlayerCharacter】", name, " 重置到空闲状态")

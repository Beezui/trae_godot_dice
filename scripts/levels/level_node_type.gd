class_name LevelNodeType
extends RefCounted
## 节点类型枚举定义
## 用于统一管理和识别关卡节点类型

# 节点类型枚举
enum Type {
	COMBAT = 1,    # 战斗节点
	ADVENTURE = 2, # 奇遇节点
	TRADE = 3,     # 交易节点
	REWARD = 4     # 奖励节点
}

# 类型对应的中文名称
static func get_type_name(type: int) -> String:
	match type:
		Type.COMBAT: return "战斗"
		Type.ADVENTURE: return "奇遇"
		Type.TRADE: return "交易"
		Type.REWARD: return "奖励"
		_: return "未知"

# 类型对应的颜色
static func get_type_color(type: int) -> Color:
	match type:
		Type.COMBAT: return Color(1, 0.3, 0.3)   # 红色 - 战斗
		Type.ADVENTURE: return Color(0.3, 0.6, 1) # 蓝色 - 奇遇
		Type.TRADE: return Color(1, 0.8, 0.3)    # 黄色 - 交易
		Type.REWARD: return Color(0.3, 1, 0.5)   # 绿色 - 奖励
		_: return Color(1, 1, 1)                  # 白色 - 未知

# 从 int 转换为 Type 枚举
static func from_int(value: int) -> int:
	if value >= Type.COMBAT and value <= Type.REWARD:
		return value
	return Type.COMBAT # 默认返回战斗类型

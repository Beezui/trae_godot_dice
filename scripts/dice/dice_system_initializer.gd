extends Node

## 骰子系统初始化器
## 负责注册所有贴图策略和 Autoload 单例


func _ready():
	print("DiceSystemInitializer 初始化开始")
	
	# 注册贴图策略
	_register_texture_strategies()
	
	print("DiceSystemInitializer 初始化完成")


## 注册所有贴图策略
func _register_texture_strategies():
	if not DiceTextureManager:
		print("错误：DiceTextureManager 未初始化")
		return
	
	# 注册数字骰子策略
	var num_strategy = NumDiceStrategy.new()
	DiceTextureManager.register_strategy(BaseDice.DiceType.NUM, num_strategy)
	print("注册数字骰子贴图策略")
	
	# 注册属性骰子策略
	var attr_strategy = AttrDiceStrategy.new()
	DiceTextureManager.register_strategy(BaseDice.DiceType.ATTR, attr_strategy)
	print("注册属性骰子贴图策略")
	
	# 注册技能骰子策略
	var skill_strategy = SkillDiceStrategy.new()
	DiceTextureManager.register_strategy(BaseDice.DiceType.SKILL, skill_strategy)
	print("注册技能骰子贴图策略")
	
	print("所有贴图策略注册完成")

extends RefCounted

## 技能基类
## 所有技能都必须继承此类，实现统一的技能接口

# 技能配置数据
var skill_config: Dictionary = {}
# 技能是否正在执行
var is_executing: bool = false


## 初始化技能
func init(config: Dictionary) -> void:
	skill_config = config


## 执行技能
## 参数：
##   caster: 施法者节点（可选）
##   targets: 目标数组（可选）
##   params: 额外参数（骰子结果、技能配置等）
func execute(caster: Node = null, targets: Array = [], params: Dictionary = {}) -> void:
	is_executing = true
	# 子类必须实现此方法
	push_error("SkillBase.execute() 必须被子类重写")
	is_executing = false


## 清理技能效果
## 在技能结束时调用，清理临时对象
func cleanup() -> void:
	is_executing = false


## 获取技能配置
func get_config() -> Dictionary:
	return skill_config


## 获取技能 ID
func get_skill_id() -> String:
	return skill_config.get("id", "")


## 获取技能名称
func get_skill_name() -> String:
	return skill_config.get("name", "Unknown")

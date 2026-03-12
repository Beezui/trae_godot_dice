extends Node

## 技能管理器
## 统一管理所有技能，提供统一的技能调用接口

# 已注册的技能字典 {skill_id: SkillBase}
var registered_skills: Dictionary = {}
# 技能冷却字典 {skill_id: cooldown_time}
var skill_cooldowns: Dictionary = {}
# 技能 CSV 读取器
var skill_csv_reader: RefCounted


func _ready():
	# 初始化技能 CSV 读取器
	skill_csv_reader = preload("res://scripts/skill_csv_reader.gd").new()
	
	# 自动注册所有技能
	_auto_register_skills()
	
	print("SkillManager 初始化完成，已注册 ", registered_skills.size(), " 个技能")


## 自动注册所有技能
func _auto_register_skills():
	# 从 skill.json 读取所有技能配置
	var all_skills = skill_csv_reader.get_all_skills()
	
	for skill_id in all_skills.keys():
		var skill_config = all_skills[skill_id]
		var skill_instance = _create_skill_instance(skill_id)
		
		if skill_instance:
			skill_instance.init(skill_config)
			register_skill(skill_id, skill_instance)
			print("自动注册技能：", skill_id, " - ", skill_instance.get_skill_name())
		else:
			print("警告：无法创建技能实例：", skill_id)


## 根据技能 ID 创建技能实例
func _create_skill_instance(skill_id: String) -> RefCounted:
	match skill_id:
		"10001":
			return preload("res://skills/fireball_skill.gd").new()
		"10002":
			return preload("res://skills/blizzard_skill.gd").new()
		_:
			print("警告：未知技能 ID: ", skill_id)
			return null


## 注册技能
## 参数：
##   skill_id: 技能 ID
##   skill_instance: 技能实例
func register_skill(skill_id: String, skill_instance: RefCounted) -> void:
	if skill_instance:
		registered_skills[skill_id] = skill_instance
		print("技能已注册：", skill_id)


## 调用技能
## 参数：
##   skill_id: 技能 ID
##   caster: 施法者节点（可选）
##   targets: 目标数组（可选）
##   params: 额外参数（可选，包含骰子结果等）
## 返回：是否成功释放
func use_skill(skill_id: String, caster: Node = null, targets: Array = [], params: Dictionary = {}) -> bool:
	# 检查技能是否存在
	if not registered_skills.has(skill_id):
		print("错误：技能不存在 - ", skill_id)
		return false
	
	# 检查冷却
	if not can_use_skill(skill_id):
		print("技能正在冷却中：", skill_id)
		return false
	
	# 获取技能实例
	var skill = registered_skills[skill_id]
	
	# 执行技能
	skill.execute(caster, targets, params)
	
	# 设置冷却
	_set_cooldown(skill_id)
	
	return true


## 检查技能是否可用
func can_use_skill(skill_id: String) -> bool:
	var cooldown = skill_cooldowns.get(skill_id, 0)
	return cooldown <= 0


## 设置技能冷却
func _set_cooldown(skill_id: String) -> void:
	skill_cooldowns[skill_id] = 1.0  # 默认冷却 1 秒


## 获取技能配置
func get_skill(skill_id: String) -> Dictionary:
	return skill_csv_reader.get_skill(skill_id)


## 更新冷却
func _process(delta: float) -> void:
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = max(0, skill_cooldowns[skill_id] - delta)


## 清除所有冷却
func clear_cooldowns() -> void:
	skill_cooldowns.clear()
	print("技能冷却已清除")


## 获取所有已注册的技能 ID
func get_all_skill_ids() -> Array:
	return registered_skills.keys()


## 获取技能数量
func get_skill_count() -> int:
	return registered_skills.size()

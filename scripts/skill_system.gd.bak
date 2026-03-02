class_name SkillSystem

var skills = {
	"fireball": {
		"name": "火球术",
		"description": "释放一个火球攻击目标",
		"damage": 20,
		"range": 5,
		"cooldown": 2
	},
	"frost": {
		"name": "冰冻术",
		"description": "冻结目标，使其无法行动",
		"duration": 3,
		"range": 3,
		"cooldown": 3
	},
	"lightning": {
		"name": "闪电术",
		"description": "释放闪电攻击多个目标",
		"damage": 15,
		"range": 8,
		"targets": 3,
		"cooldown": 4
	},
	"heal": {
		"name": "治疗术",
		"description": "恢复生命值",
		"heal": 25,
		"range": 4,
		"cooldown": 3
	},
	"shield": {
		"name": "护盾术",
		"description": "创造一个护盾吸收伤害",
		"shield": 30,
		"duration": 5,
		"cooldown": 5
	},
	"strength": {
		"name": "力量术",
		"description": "增强攻击力",
		"buff": 50,
		"duration": 4,
		"cooldown": 4
	},
	"luck": {
		"name": "幸运术",
		"description": "下次投掷必定出现最大点数",
		"effect": "max_result",
		"cooldown": 6
	},
	"control": {
		"name": "控制术",
		"description": "下次投掷可以指定点数",
		"effect": "control_result",
		"cooldown": 8
	}
}

var skill_cooldowns = {}

func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})

func can_use_skill(skill_id: String) -> bool:
	var cooldown = skill_cooldowns.get(skill_id, 0)
	return cooldown <= 0

func use_skill(skill_id: String, caster: Node3D, target: Node3D = null) -> bool:
	if not can_use_skill(skill_id):
		return false
	
	var skill = get_skill(skill_id)
	if skill.is_empty():
		return false
	
	# 记录冷却时间
	skill_cooldowns[skill_id] = skill.get("cooldown", 1)
	
	# 执行技能效果
	match skill_id:
		"fireball":
			if target:
				print("释放火球术攻击: ", target.name)
				# 这里可以添加伤害计算和视觉效果
		"frost":
			if target:
				print("释放冰冻术冻结: ", target.name)
				# 这里可以添加冻结效果和视觉效果
		"lightning":
			print("释放闪电术攻击多个目标")
			# 这里可以添加范围攻击逻辑
		"heal":
			print("释放治疗术恢复生命值")
			# 这里可以添加治疗逻辑
		"shield":
			print("释放护盾术保护自己")
			# 这里可以添加护盾逻辑
		"strength":
			print("释放力量术增强攻击力")
			# 这里可以添加力量增强逻辑
		"luck":
			print("释放幸运术，下次投掷必定出现最大点数")
			# 检查caster是否有set_controlled_result方法
			if caster and caster.has_method("set_controlled_result"):
				# 设置为最大点数
				var max_value = 6  # 假设是6面骰子
				caster.set_controlled_result(max_value)
		"control":
			print("释放控制术，可以指定下次投掷的点数")
			# 检查caster是否有set_controlled_result方法
			if caster and caster.has_method("set_controlled_result"):
				# 这里可以添加UI来让玩家选择点数
				# 暂时设置为6作为示例
				caster.set_controlled_result(6)
	
	return true

func update_cooldowns(delta: float):
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = max(0, skill_cooldowns[skill_id] - delta)

func get_skill_by_dice_value(value: int) -> String:
	var skill_map = {
		1: "fireball",
		2: "frost",
		3: "lightning",
		4: "heal",
		5: "shield",
		6: "strength"
	}
	return skill_map.get(value, "")

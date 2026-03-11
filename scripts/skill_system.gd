extends RefCounted

var skill_csv_reader: RefCounted
var skill_cooldowns = {}

func _init():
	var SkillCSVReaderClass = preload("res://scripts/skill_csv_reader.gd")
	skill_csv_reader = SkillCSVReaderClass.new()

func get_skill(skill_id: String) -> Dictionary:
	return skill_csv_reader.get_skill(skill_id)

func can_use_skill(skill_id: String) -> bool:
	var cooldown = skill_cooldowns.get(skill_id, 0)
	return cooldown <= 0

func use_skill(skill_id: String, caster: Node3D, target: Node3D = null) -> bool:
	if not can_use_skill(skill_id):
		return false
	
	var skill = get_skill(skill_id)
	if skill.is_empty():
		return false
	
	skill_cooldowns[skill_id] = 1.0
	
	match skill_id:
		"10001":
			_execute_fireball(skill, caster, target)
	
	return true

func _execute_fireball(skill: Dictionary, caster: Node3D, target: Node3D = null):
	print("Executing fireball skill: ", skill.get("name", "Unknown"))
	print("Attribute dice: ", skill.get("attribute_dice", {}))
	print("Description: ", skill.get("description", ""))

func update_cooldowns(delta: float):
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = max(0, skill_cooldowns[skill_id] - delta)

func get_skill_by_dice_value(value: int) -> String:
	return "10001"

func get_all_skills() -> Dictionary:
	return skill_csv_reader.get_all_skills()

func get_skill_count() -> int:
	return skill_csv_reader.get_skill_count()

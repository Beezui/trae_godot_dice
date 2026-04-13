extends Node

var registered_skills: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var skill_csv_reader: RefCounted

func _ready():
	skill_csv_reader = preload("res://scripts/skill_csv_reader.gd").new()
	_auto_register_skills()

func _auto_register_skills():
	var all_skills = skill_csv_reader.get_all_skills()
	
	for skill_id in all_skills.keys():
		var skill_config = all_skills[skill_id]
		var skill_instance = _create_skill_instance(skill_id)
		
		if skill_instance:
			skill_instance.init(skill_config)
			register_skill(skill_id, skill_instance)

func _create_skill_instance(skill_id: String) -> RefCounted:
	match skill_id:
		"10001":
			return preload("res://skills/fireball_skill.gd").new()
		"10002":
			return preload("res://skills/blizzard_skill.gd").new()
		_:
			return null

func register_skill(skill_id: String, skill_instance: RefCounted) -> void:
	if skill_instance:
		registered_skills[skill_id] = skill_instance

func use_skill(skill_id: String, caster: Node = null, targets: Array = [], params: Dictionary = {}) -> bool:
	if not registered_skills.has(skill_id):
		push_error("Skill not found: " + skill_id)
		return false
	
	if not can_use_skill(skill_id):
		return false
	
	var skill = registered_skills[skill_id]
	
	skill.execute(caster, targets, params)
	
	_set_cooldown(skill_id)
	
	return true

func can_use_skill(skill_id: String) -> bool:
	var cooldown = skill_cooldowns.get(skill_id, 0)
	return cooldown <= 0

func _set_cooldown(skill_id: String) -> void:
	skill_cooldowns[skill_id] = 1.0

func get_skill(skill_id: String) -> Dictionary:
	return skill_csv_reader.get_skill(skill_id)

func _process(delta: float) -> void:
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = max(0, skill_cooldowns[skill_id] - delta)

func clear_cooldowns() -> void:
	skill_cooldowns.clear()

func get_all_skill_ids() -> Array:
	return registered_skills.keys()

func get_skill_count() -> int:
	return registered_skills.size()

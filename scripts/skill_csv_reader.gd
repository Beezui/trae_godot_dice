extends RefCounted

var skills = {}

func _init():
	load_skills()

func load_skills():
	var file = FileAccess.open("res://table/skill.json", FileAccess.READ)
	if not file:
		push_error("Cannot open skill.json")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("Error parsing skill.json: " + json.get_error_message())
		return
	
	var data = json.get_data()
	
	if not data is Dictionary or not data.has("skills"):
		push_error("skill.json missing 'skills' array")
		return
	
	var skills_array = data["skills"]
	for skill_data in skills_array:
		if skill_data is Dictionary and skill_data.has("id"):
			var skill_id = str(skill_data["id"])
			skills[skill_id] = skill_data

func get_skill(skill_id: String) -> Dictionary:
	return skills.get(skill_id, {})

func get_all_skills() -> Dictionary:
	return skills

func get_skill_count() -> int:
	return skills.size()

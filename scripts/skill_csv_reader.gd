extends RefCounted

var skills = {}

func _init():
	load_skills()

func load_skills():
	var file = FileAccess.open("res://table/skill.json", FileAccess.READ)
	if not file:
		print("Error: Cannot open skill.json")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	print("JSON text loaded: ", json_text.substr(0, 100))
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("Error parsing skill.json: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	
	var data = json.get_data()
	print("Parsed data type: ", typeof(data))
	
	if not data is Dictionary or not data.has("skills"):
		print("Error: skill.json missing 'skills' array")
		return
	
	var skills_array = data["skills"]
	for skill_data in skills_array:
		if skill_data is Dictionary and skill_data.has("id"):
			var skill_id = str(skill_data["id"])
			skills[skill_id] = skill_data
			print("Loaded skill: ", skill_id, " - ", skill_data.get("name", "Unknown"))
			print("  Attribute dice: ", skill_data.get("attribute_dice", {}))
	
	print("Skill JSON loading complete. Total skills: ", skills.size())

func get_skill(skill_id: String) -> Dictionary:
	print("=== skill_csv_reader.get_skill() 被调用 ===")
	print("请求的 skill_id: ", skill_id)
	print("已加载的技能列表: ", skills.keys())
	var result = skills.get(skill_id, {})
	print("返回的技能数据: ", result)
	return result

func get_all_skills() -> Dictionary:
	return skills

func get_skill_count() -> int:
	return skills.size()

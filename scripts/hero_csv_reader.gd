extends RefCounted

var heroes = {}

func _init():
	load_heroes()

func load_heroes():
	var file = FileAccess.open("res://table/hero.json", FileAccess.READ)
	if not file:
		push_error("Cannot open hero.json")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("Error parsing hero.json: " + json.get_error_message())
		return
	
	var data = json.get_data()
	
	if not data is Dictionary or not data.has("heroes"):
		push_error("hero.json missing 'heroes' array")
		return
	
	var heroes_array = data["heroes"]
	for hero_data in heroes_array:
		if hero_data is Dictionary and hero_data.has("id"):
			var hero_id = str(hero_data["id"])
			heroes[hero_id] = hero_data

func get_hero(hero_id: String) -> Dictionary:
	return heroes.get(hero_id, {})

func get_all_heroes() -> Dictionary:
	return heroes

func get_hero_count() -> int:
	return heroes.size()

func get_hero_attribute(hero_id: String, attribute: String) -> Array:
	var hero = get_hero(hero_id)
	if hero:
		var attr_array = hero.get(attribute, [10, 20, 30, 40, 50, 60])
		# 确保返回的是整数数组
		var result = []
		for item in attr_array:
			if typeof(item) == TYPE_STRING:
				result.append(int(item))
			else:
				result.append(item)
		return result
	return [10, 20, 30, 40, 50, 60]

func get_hero_textures(hero_id: String) -> Array:
	var hero = get_hero(hero_id)
	if hero and hero.has("texture"):
		var texture_data = hero["texture"]
		if typeof(texture_data) == TYPE_ARRAY:
			# 如果是数组，直接返回
			return texture_data
		else:
			# 如果是字符串，按逗号分割
			var texture_str = str(texture_data)
			return texture_str.split(",")
	return []

func refresh():
	load_heroes()
	print("Hero data refreshed")
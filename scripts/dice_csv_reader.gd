class_name DiceCSVReader

var num_dices_data = {}
var item_dices_data = {}
var potion_dices_data = {}
var skill_dices_data = {}
var attr_dices_data = {}
var blank_dices_data = {}

func _init():
	load_num_dices()
	load_skill_dices()
	load_attr_dices()
	load_blank_dices()

func load_num_dices():
	# 优先加载 JSON 格式
	var json_path = "res://table/NumDices.json"
	var file = FileAccess.open(json_path, FileAccess.READ)
	
	if file:
		print("【JSON】开始加载 NumDices.json，路径：", json_path)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		
		if parse_result != OK:
			push_error("Error parsing NumDices.json: " + json.get_error_message())
			return
		
		var data = json.get_data()
		if not data is Dictionary or not data.has("num_dices"):
			push_error("NumDices.json missing 'num_dices' array")
			return
		
		var num_dices_array = data["num_dices"]
		for dice_data in num_dices_array:
			if dice_data is Dictionary and dice_data.has("id"):
				var dice_id = str(dice_data["id"])
				# 预处理配置数据，将数组格式的 values 和 textures 转换为字典格式
				_preprocess_num_dice_config(dice_data)
				num_dices_data[dice_id] = dice_data
				print("【JSON】加载数字骰子配置 ID=", dice_id)
		
		print("【JSON】NumDices.json 加载完成，配置数=", num_dices_data.size())
	else:
		# JSON 不存在时，回退到 CSV 加载
		load_num_dices_from_csv()

func load_num_dices_from_csv():
	# CSV 回退加载方法
	var csv_path = "res://table/NumDices.csv"
	print("【CSV】JSON 不存在，从 CSV 加载 NumDices.csv，路径：", csv_path)
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file:
		var header = file.get_line()
		print("【CSV】CSV 头部：", header)
		var line_count = 0
		
		while not file.eof_reached():
			var line = file.get_line()
			if line.is_empty():
				continue
			
			line_count += 1
			var data = parse_csv_line(line)
			if data.size() >= 4:
				var id = data[0]
				var face_count = int(data[1])
				var values_str = data[2]
				var textures_str = data[3]
				
				var values = {}
				var value_array = values_str.split(",")
				for i in range(value_array.size()):
					var value = int(value_array[i])
					values[i] = value
				
				var textures = {}
				var texture_array = textures_str.split(",")
				for i in range(texture_array.size()):
					var texture_id = int(texture_array[i])
					var texture_name = "dice_face_" + str(texture_id)
					var texture_path = "res://textures/dice/" + texture_name + ".png"
					textures[i] = texture_path
				
				num_dices_data[id] = {
					"face_count": face_count,
					"values": values,
					"textures": textures
				}
				print("【CSV】加载骰子配置 ID=", id, ", 贴图数=", textures.size())
		
		file.close()
		print("【CSV】NumDices.csv 加载完成，共 ", line_count, " 行，配置数=", num_dices_data.size())
	else:
		push_error("Failed to load NumDices.csv")


func get_num_dice_config(dice_id: String) -> Dictionary:
	return num_dices_data.get(dice_id, {})

func get_all_num_dice_ids() -> Array:
	return num_dices_data.keys()

func load_skill_dices():
	var json_path = "res://table/SkillDices.json"
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		
		if parse_result != OK:
			push_error("Error parsing SkillDices.json: " + json.get_error_message())
			return
		
		var data = json.get_data()
		if not data is Dictionary or not data.has("skill_dices"):
			push_error("SkillDices.json missing 'skill_dices' array")
			return
		
		var skill_dices_array = data["skill_dices"]
		for dice_data in skill_dices_array:
			if dice_data is Dictionary and dice_data.has("id"):
				var dice_id = str(dice_data["id"])
				skill_dices_data[dice_id] = dice_data
	else:
		push_error("Failed to load SkillDices.json")

func get_skill_dice_config(dice_id: String) -> Dictionary:
	return skill_dices_data.get(dice_id, {})

func get_all_skill_dice_ids() -> Array:
	return skill_dices_data.keys()

func load_attr_dices() -> Dictionary:
	# 使用 AttrDices.json（全局属性骰子文字颜色配置）
	# 格式：{"attr_dices": [{"id": "5001", "attr_name": "str", "points_color": "#C00000"}, ...]}
	# 返回：{"str": "#C00000", "agi": "#A9D08E", "int": "#8EA9DB"}
	var json_path = "res://table/AttrDices.json"
	var file = FileAccess.open(json_path, FileAccess.READ)

	if file:
		print("【JSON】开始加载 AttrDices.json，路径：", json_path)
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_text)

		if parse_result != OK:
			push_error("Error parsing AttrDices.json: " + json.get_error_message())
			return {}

		var data = json.get_data()
		if not data is Dictionary or not data.has("attr_dices"):
			push_error("AttrDices.json missing 'attr_dices' array")
			return {}

		# 新格式：attr_dices 是数组，遍历建立 attr_name → points_color 映射
		var attr_dices_array = data["attr_dices"]
		var result = {}

		for dice_config in attr_dices_array:
			if dice_config is Dictionary and dice_config.has("attr_name") and dice_config.has("points_color"):
				var attr_name = str(dice_config["attr_name"])
				var color_str = dice_config["points_color"]
				result[attr_name] = color_str
				print("【JSON】加载属性骰子颜色配置 attr_name=", attr_name, ", color=", color_str)

		# 更新缓存数据
		attr_dices_data = result
		print("【JSON】AttrDices.json 加载完成，配置数=", attr_dices_data.size())
		return result

	print("【JSON】AttrDices.json 文件不存在或无法读取")
	return {}

func _preprocess_attr_dice_config(hero_data: Dictionary):
	# 遍历三种属性配置（power, agility, intelligence）
	var attrs = ["power", "agility", "intelligence"]
	for attr in attrs:
		if hero_data.has(attr):
			var attr_config = hero_data[attr]
			if attr_config.has("values") and attr_config.get("values") is Array:
				var values_array = attr_config["values"]
				var values_dict = {}
				for i in range(values_array.size()):
					values_dict[i] = values_array[i]
				attr_config["values"] = values_dict

func _preprocess_num_dice_config(dice_data: Dictionary):
	# 将数组格式的 values 和 textures 转换为字典格式
	if dice_data.has("values") and dice_data.get("values") is Array:
		var values_array = dice_data["values"]
		var values_dict = {}
		for i in range(values_array.size()):
			values_dict[i] = values_array[i]
		dice_data["values"] = values_dict
	
	if dice_data.has("textures") and dice_data.get("textures") is Array:
		var textures_array = dice_data["textures"]
		var textures_dict = {}
		for i in range(textures_array.size()):
			textures_dict[i] = textures_array[i]
		dice_data["textures"] = textures_dict

func get_attr_dice_config(hero_id: String) -> Dictionary:
	return attr_dices_data.get(hero_id, {})

func get_all_hero_ids() -> Array:
	return attr_dices_data.keys()


# ============================================================================
# 空白骰子模板
# ============================================================================

func load_blank_dices():
	var json_path = "res://table/BlankDices.json"
	var file = FileAccess.open(json_path, FileAccess.READ)

	if file:
		print("【空白骰子】加载 BlankDices.json，路径：", json_path)
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_text)

		if parse_result != OK:
			push_error("Error parsing BlankDices.json: " + json.get_error_message())
			return

		var data = json.get_data()
		if not data is Dictionary or not data.has("blank_dices"):
			push_error("BlankDices.json missing 'blank_dices' array")
			return

		var blank_dices_array = data["blank_dices"]
		for dice_data in blank_dices_array:
			if dice_data is Dictionary and dice_data.has("id"):
				var dice_id = str(dice_data["id"])
				blank_dices_data[dice_id] = dice_data
				print("【空白骰子】加载模板 ID=", dice_id, " 名称=", dice_data.get("name", ""))

		print("【空白骰子】BlankDices.json 加载完成，模板数=", blank_dices_data.size())
	else:
		push_error("【空白骰子】BlankDices.json 文件不存在或无法读取")


func get_blank_dice_config(dice_id: String) -> Dictionary:
	return blank_dices_data.get(dice_id, {})


func get_all_blank_dice_ids() -> Array:
	return blank_dices_data.keys()

func parse_csv_line(line: String) -> Array:
	var result = []
	var current_field = ""
	var in_quotes = false
	var i = 0
	
	while i < line.length():
		var c = line[i]
		
		if c == '"':
			in_quotes = !in_quotes
		elif c == ',' and not in_quotes:
			result.append(current_field)
			current_field = ""
		else:
			current_field += c
		
		i += 1
	
	result.append(current_field)
	
	return result

func reload():
	num_dices_data.clear()
	skill_dices_data.clear()
	blank_dices_data.clear()
	load_num_dices()
	load_skill_dices()

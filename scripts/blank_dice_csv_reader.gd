class_name BlankDiceCSVReader
extends RefCounted

## 空白骰子模板数据
var blank_dices_data = {}


func _init():
	load_blank_dices()


## 加载空白骰子配置（优先 JSON，回退 CSV）
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
		print("【空白骰子】BlankDices.json 不存在，从 CSV 加载")
		load_blank_dices_from_csv()


## 从 CSV 加载（回退方案）
func load_blank_dices_from_csv():
	var csv_path = "res://table/BlankDices.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		push_error("【空白骰子】无法加载 BlankDices.csv")
		return

	var header_line = file.get_line()
	var header = header_line.split(",")
	print("【空白骰子】CSV 表头：", header)

	while not file.eof_reached():
		var line = file.get_line().strip()
		if line.is_empty():
			continue

		var values = _parse_csv_line(line)
		if values.size() < 10:
			continue

		var dice_id = values[0].strip()
		var dice = {
			"id": dice_id,
			"name": values[1].strip(),
			"description": values[2].strip(),
			"effect_type": values[3].strip(),
			"p1": values[4].strip(),
			"p2": values[5].strip(),
			"p3": values[6].strip(),
			"p4": values[7].strip(),
			"texture": values[8].strip(),
			"icon": values[9].strip()
		}
		blank_dices_data[dice_id] = dice
		print("【空白骰子】从 CSV 加载模板 ID=", dice_id)

	file.close()
	print("【空白骰子】BlankDices.csv 加载完成，模板数=", blank_dices_data.size())


## 获取空白骰子模板配置
func get_blank_dice_config(dice_id: String) -> Dictionary:
	return blank_dices_data.get(dice_id, {})


## 获取所有空白骰子模板 ID
func get_all_blank_dice_ids() -> Array:
	return blank_dices_data.keys()


## 获取空白骰子模板数量
func get_blank_dice_count() -> int:
	return blank_dices_data.size()


## 解析 CSV 行（处理引号）
func _parse_csv_line(line: String) -> Array:
	var result = []
	var current_field = ""
	var in_quotes = false

	for i in range(line.length()):
		var c = line[i]
		if c == '"':
			in_quotes = !in_quotes
		elif c == ',' and not in_quotes:
			result.append(current_field)
			current_field = ""
		else:
			current_field += c

	result.append(current_field)
	return result


## 重新加载配置
func reload():
	blank_dices_data.clear()
	load_blank_dices()

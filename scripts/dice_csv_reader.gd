class_name DiceCSVReader

var num_dices_data = {}
var item_dices_data = {}
var potion_dices_data = {}
var skill_dices_data = {}

func _init():
	load_num_dices()

func load_num_dices():
	# 加载数字骰子配置
	var csv_path = "res://table/NumDices.csv"
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file:
		# 读取表头
		var header = file.get_line()
		
		# 读取数据行
		while not file.eof_reached():
			var line = file.get_line()
			if line.is_empty():
				continue
			
			# 解析CSV行，处理带引号的字段
			var data = parse_csv_line(line)
			if data.size() >= 4:
				var id = data[0]
				var face_count = int(data[1])
				var values_str = data[2]
				var textures_str = data[3]
				
				# 解析点数配置
				var values = {}
				var value_array = values_str.split(",")
				for i in range(value_array.size()):
					var value = int(value_array[i])
					values[i] = value
				
				# 解析贴图配置
				var textures = {}
				var texture_array = textures_str.split(",")
				for i in range(texture_array.size()):
					var texture_id = int(texture_array[i])
					# 构建完整的贴图路径，默认前缀为dice_face_
					var texture_name = "dice_face_" + str(texture_id)
					var texture_path = "res://textures/dice/" + texture_name + ".png"
					textures[i] = texture_path
				
				num_dices_data[id] = {
					"face_count": face_count,
					"values": values,
					"textures": textures
				}
				print("Loaded num dice: ", id, " with config: ", num_dices_data[id])
		
		file.close()
		print("Loaded num dices data: ", num_dices_data.keys())
	else:
		print("Failed to load NumDices.csv")

func get_num_dice_config(dice_id: String) -> Dictionary:
	# 获取数字骰子配置
	return num_dices_data.get(dice_id, {})

func get_all_num_dice_ids() -> Array:
	# 获取所有数字骰子ID
	return num_dices_data.keys()

func parse_csv_line(line: String) -> Array:
	# 解析CSV行，处理带引号的字段
	var result = []
	var current_field = ""
	var in_quotes = false
	var i = 0
	
	while i < line.length():
		var char = line[i]
		
		if char == '"':
			in_quotes = !in_quotes
		elif char == ',' and not in_quotes:
			result.append(current_field)
			current_field = ""
		else:
			current_field += char
		
		i += 1
	
	# 添加最后一个字段
	result.append(current_field)
	
	return result

func reload():
	# 重新加载所有配置
	num_dices_data.clear()
	load_num_dices()

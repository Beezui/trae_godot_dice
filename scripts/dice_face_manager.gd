class_name DiceFaceManager

var face_data = {}
var csv_path = "res://table/骰子面配置.csv"

func _init():
	load_csv()

func load_csv():
	# 加载CSV文件
	print("Loading CSV file from: " + csv_path)
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file:
		print("CSV file opened successfully")
		# 读取表头
		var header = file.get_line()
		print("CSV header: " + header)
		
		# 读取数据行
		while not file.eof_reached():
			var line = file.get_line()
			if line.is_empty():
				continue
			
			var data = line.split(",")
			print("CSV line: " + str(data))
			if data.size() >= 3:
				var id = int(data[0])
				var path = data[1]
				var description = data[2]
				
				# 构建完整的资源路径，确保使用正斜杠
				var full_path = "res://textures/" + path.replace("\\", "/")
				
				face_data[id] = {
					"path": full_path,
					"description": description
				}
				print("Added face data: ID=" + str(id) + ", Path=" + full_path + ", Desc=" + description)
				
		file.close()
		print("Loaded dice face data: " + str(face_data))
	else:
		print("Failed to load CSV file: " + csv_path)

func get_face_by_id(id: int) -> Dictionary:
	# 根据ID获取骰子面数据
	return face_data.get(id, {})

func get_texture_path_by_id(id: int) -> String:
	# 根据ID获取贴图路径
	var face = get_face_by_id(id)
	return face.get("path", "")

func get_description_by_id(id: int) -> String:
	# 根据ID获取描述
	var face = get_face_by_id(id)
	return face.get("description", "")

func get_all_face_ids() -> Array:
	# 获取所有骰子面ID
	return face_data.keys()

func reload():
	# 重新加载CSV文件
	face_data.clear()
	load_csv()

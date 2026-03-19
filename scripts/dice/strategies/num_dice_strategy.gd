extends RefCounted
class_name NumDiceStrategy

## 数字骰子贴图策略
## 负责为数字骰子应用标准数字贴图


## 应用贴图
func apply_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	var textures = config.get("textures", {})
	var values = config.get("values", {})
	
	# 为骰子的六个面应用不同的材质
	var materials = []
	
	# 定义不同 ID 对应的颜色（作为备用）
	var id_colors = {
		0: Color(1, 0, 0, 1),   # 红色 - 面 1
		1: Color(0, 1, 0, 1),   # 绿色 - 面 2
		2: Color(0, 0, 1, 1),   # 蓝色 - 面 3
		3: Color(1, 1, 0, 1),   # 黄色 - 面 4
		4: Color(1, 0, 1, 1),   # 紫色 - 面 5
		5: Color(0, 1, 1, 1),   # 青色 - 面 6
		6: Color(1, 0.5, 0, 1), # 橙色
		7: Color(0.5, 0, 0.5, 1), # 深紫色
		8: Color(0, 0.5, 0.5, 1)  # 深青色
	}
	
	# 创建六个面的材质
	for i in range(6):
		# 获取当前面的贴图路径
		var texture_path = textures.get(i, "")
		# 创建材质
		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		
		# 尝试加载贴图
		if texture_path and not texture_path.is_empty():
			print("NumDiceStrategy: 加载面 ", i, " 的贴图：", texture_path)
			var texture = load(texture_path)
			if texture:
				print("NumDiceStrategy: 成功加载贴图：", texture_path)
				material.albedo_texture = texture
			else:
				print("NumDiceStrategy: 加载贴图失败：", texture_path)
				# 加载失败，使用彩色材质
				var color = id_colors.get(i, Color(0.5, 0.5, 0.5, 1))  # 默认灰色
				material.albedo_color = color
				print("NumDiceStrategy: 使用备用颜色：", color)
		else:
			# 没有贴图路径，使用彩色材质
			var color = id_colors.get(i, Color(0.5, 0.5, 0.5, 1))  # 默认灰色
			material.albedo_color = color
			print("NumDiceStrategy: 无贴图路径，使用颜色：", color)
		
		materials.append(material)
	
	# 应用材质到网格
	if mesh_instance.mesh and materials.size() > 0:
		# 尝试为每个面设置不同的材质
		var surface_count = mesh_instance.mesh.get_surface_count()
		print("NumDiceStrategy: 网格表面数量：", surface_count)
		
		# 对于多面体网格，为每个面设置材质
		if surface_count >= 6:
			for i in range(6):
				if i < surface_count:
					mesh_instance.mesh.surface_set_material(i, materials[i])
					print("NumDiceStrategy: 应用材质 ", i, " 到表面 ", i)
			print("NumDiceStrategy: 材质应用到网格表面完成")
		else:
			# 对于单一表面的网格，使用材质覆盖
			mesh_instance.material_override = materials[0]
			print("NumDiceStrategy: 应用默认材质到骰子模型")
		
		# 存储材质数组，以便在运行时切换
		mesh_instance.set_meta("dice_materials", materials)
		print("NumDiceStrategy: 贴图应用完成")

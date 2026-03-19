extends RefCounted
class_name SkillDiceStrategy

## 技能骰子贴图策略
## 负责为技能骰子应用技能图标贴图


## 应用贴图
func apply_textures(mesh_instance: MeshInstance3D, config: Dictionary):
	var textures = config.get("textures", {})
	var values = config.get("values", {})
	var skill_ids = config.get("skill_ids", [])
	
	# 为骰子的六个面应用不同的材质
	var materials = []
	
	# 定义备用颜色
	var fallback_colors = [
		Color(1, 0, 0, 1),   # 红色 - 技能 1
		Color(0, 1, 0, 1),   # 绿色 - 技能 2
		Color(0, 0, 1, 1),   # 蓝色 - 技能 3
		Color(1, 1, 0, 1),   # 黄色 - 技能 4
		Color(1, 0, 1, 1),   # 紫色 - 技能 5
		Color(0, 1, 1, 1),   # 青色 - 技能 6
	]
	
	# 创建六个面的材质
	for i in range(6):
		# 获取当前面的贴图路径
		var texture_path = textures.get(i, "")
		
		# 如果没有贴图路径，尝试从 skill_ids 获取
		if texture_path.is_empty() and i < skill_ids.size():
			var skill_id = skill_ids[i]
			# 尝试加载技能图标 (假设技能图标路径为 res://textures/skills/skill_{id}.png)
			texture_path = "res://textures/skills/skill_%s.png" % skill_id
		
		# 创建材质
		var material = StandardMaterial3D.new()
		material.roughness = 0.8
		
		# 尝试加载贴图
		if texture_path and not texture_path.is_empty():
			print("SkillDiceStrategy: 加载面 ", i, " 的贴图：", texture_path)
			var texture = load(texture_path)
			if texture:
				print("SkillDiceStrategy: 成功加载贴图：", texture_path)
				material.albedo_texture = texture
			else:
				print("SkillDiceStrategy: 加载贴图失败：", texture_path)
				# 加载失败，使用彩色材质
				var color = fallback_colors[i % fallback_colors.size()]
				material.albedo_color = color
				print("SkillDiceStrategy: 使用备用颜色：", color)
		else:
			# 没有贴图路径，使用彩色材质
			var color = fallback_colors[i % fallback_colors.size()]
			material.albedo_color = color
			print("SkillDiceStrategy: 无贴图路径，使用颜色：", color)
		
		materials.append(material)
	
	# 应用材质到网格
	if mesh_instance.mesh and materials.size() > 0:
		# 尝试为每个面设置不同的材质
		var surface_count = mesh_instance.mesh.get_surface_count()
		print("SkillDiceStrategy: 网格表面数量：", surface_count)
		
		# 对于多面体网格，为每个面设置材质
		if surface_count >= 6:
			for i in range(6):
				if i < surface_count:
					mesh_instance.mesh.surface_set_material(i, materials[i])
					print("SkillDiceStrategy: 应用材质 ", i, " 到表面 ", i)
			print("SkillDiceStrategy: 材质应用到网格表面完成")
		else:
			# 对于单一表面的网格，使用材质覆盖
			mesh_instance.material_override = materials[0]
			print("SkillDiceStrategy: 应用默认材质到骰子模型")
		
		# 存储材质数组，以便在运行时切换
		mesh_instance.set_meta("dice_materials", materials)
		print("SkillDiceStrategy: 技能骰子贴图应用完成")

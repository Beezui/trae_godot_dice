extends Control
## 关卡地图显示 UI
## 负责可视化展示生成的关卡地图

# 配置
var config: Dictionary = {}
var node_radius: float = 35.0  # 增加半径以显示名称
var node_spacing_x: float = 200.0  # 增加水平间距
var node_spacing_y: float = 150.0  # 增加垂直间距
var layer_padding: float = 100.0

# UI 节点
var canvas: Control
var difficulty_label: Label
var total_label: Label
var seed_label: Label
var regenerate_button: Button
var print_log_button: Button

# 节点类型颜色
const TYPE_COLORS = {
	1: Color(1, 0.3, 0.3),  # 战斗 - 红色
	2: Color(0.3, 0.6, 1),  # 奇遇 - 蓝色
	3: Color(1, 0.8, 0.3),  # 交易 - 黄色
	4: Color(0.3, 1, 0.5)   # 奖励 - 绿色
}

# 拖动相关
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var canvas_offset: Vector2 = Vector2.ZERO


func _ready():
	# 延迟查找节点（确保场景树完全加载）
	call_deferred("_find_nodes_deferred")


## 延迟查找节点
func _find_nodes_deferred():
	_find_nodes()
	
	# 连接信号
	if regenerate_button:
		regenerate_button.pressed.connect(_on_regenerate_pressed)
	if print_log_button:
		print_log_button.pressed.connect(_on_print_log_pressed)
	
	# 初始化 canvas 拖动
	if canvas:
		canvas.gui_input.connect(_on_canvas_gui_input)
		# 确保 draw 信号连接
		if not canvas.is_connected("draw", _on_canvas_draw):
			canvas.connect("draw", _on_canvas_draw)
	
	# 加载配置
	_load_config()
	
	# 自动生成关卡
	generate_and_display()


## 查找节点（简化版：直接遍历所有子节点）
func _find_nodes():
	for child in get_children():
		# 查找 Canvas（名称中包含 Canvas）
		if "Canvas" in child.name and child is Control:
			canvas = child
		
		# 查找标签
		if "DifficultyLabel" in child.name:
			difficulty_label = child as Label
		elif "TotalLabel" in child.name:
			total_label = child as Label
		elif "SeedLabel" in child.name:
			seed_label = child as Label
		
		# 查找按钮
		if "RegenerateButton" in child.name:
			regenerate_button = child as Button
		elif "PrintLogButton" in child.name:
			print_log_button = child as Button


## 加载配置
func _load_config():
	var file = FileAccess.open("res://config/level_generation_config.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(json_text) == OK:
			config = json.get_data()
			node_radius = config.get("visual", {}).get("node_radius", 25.0)
			node_spacing_x = config.get("layout", {}).get("node_spacing_x", 150.0)
			node_spacing_y = config.get("layout", {}).get("node_spacing_y", 120.0)
			layer_padding = config.get("layout", {}).get("layer_padding", 80.0)


## 生成并显示关卡
func generate_and_display():
	var level_gen = LevelGenerator.get_instance()
	if level_gen == null:
		push_error("[LevelMapDisplay] LevelGenerator 单例未找到")
		return
	
	# 生成关卡（默认难度 1，随机种子）
	var seed_value = Time.get_ticks_msec()
	var level_data = level_gen.generate_level(1, seed_value)
	
	if level_data:
		display_level(level_data)


## 显示关卡数据
func display_level(level_data: LevelData):
	if not canvas:
		push_error("[LevelMapDisplay] Canvas 未找到！")
		return
	
	# 更新 UI 信息
	if difficulty_label:
		difficulty_label.text = "难度：" + str(level_data.difficulty)
	if total_label:
		total_label.text = "总关卡：" + str(level_data.total_nodes)
	if seed_label:
		seed_label.text = "种子：" + str(level_data.seed_value)
	
	# 计算节点位置
	print("[LevelMapDisplay] === 开始计算节点位置 ===")
	_calculate_node_positions(level_data)
	print("[LevelMapDisplay] === 节点位置计算完成 ===\n")
	
	# 更新 canvas 大小以适应所有节点
	_update_canvas_size(level_data)
	
	# 强制重绘
	canvas.queue_redraw()

	# 交叉检测（调试用）
	_check_cross_connections(level_data)


## 计算节点位置（优化版：减少连线交叉）
func _calculate_node_positions(level_data: LevelData):
	var layers_dict = {}
	
	# 按层级分组
	for node in level_data.nodes:
		var layer = node.layer
		if layer not in layers_dict:
			layers_dict[layer] = []
		layers_dict[layer].append(node)
	
	# 计算每层的位置
	var layers = layers_dict.keys()
	layers.sort()
	
	for layer_idx in range(layers.size()):
		var layer = layers[layer_idx]
		var layer_nodes = layers_dict[layer]
		
		# 优化：根据前驱节点排序，减少连线交叉
		_sort_layer_nodes_by_id(layer_nodes)
		
		# 计算该层节点的 X 位置（垂直排列）
		var x_pos = layer_idx * node_spacing_x + layer_padding
		# 计算该层所有节点的总高度，使它们居中
		var total_height = (layer_nodes.size() - 1) * node_spacing_y
		var start_y = -total_height / 2.0
		
		for node_idx in range(layer_nodes.size()):
			var node = layer_nodes[node_idx]
			var y_pos = start_y + node_idx * node_spacing_y
			node.position = Vector2(x_pos, y_pos)


## 按节点 ID 排序（确保与连接逻辑一致）
func _sort_layer_nodes_by_id(layer_nodes: Array):
	if layer_nodes.size() <= 1:
		return
	layer_nodes.sort_custom(func(a, b): return int(a.id) < int(b.id))

	# 调试输出：打印排序后的节点顺序
	var ids = []
	for n in layer_nodes: ids.append("#" + n.id + "(y=" + str(n.position.y) + ")")
	print("  [UI] 层排序后：[", ", ".join(ids), "]")


## 检查连接线是否有交叉（调试用）
func _check_cross_connections(level_data: LevelData) -> int:
	var cross_count = 0
	var lines = []

	# 收集所有连接线，按层级分组
	for node in level_data.nodes:
		for next_id in node.connections:
			var next_node = level_data.get_node(next_id)
			if next_node:
				lines.append({
					"from": node,
					"to": next_node,
					"from_layer": node.layer,
					"to_layer": next_node.layer,
					"layer_diff": abs(next_node.layer - node.layer)
				})

	# 只检查相邻层之间的连接（layer_diff = 1）
	var adjacent_lines = []
	for line in lines:
		if line.layer_diff == 1:
			adjacent_lines.append(line)

	print("  [交叉检测] 总连接线：", lines.size(), "，相邻层连接：", adjacent_lines.size())

	# 检查每对相邻层连接线是否交叉
	for i in range(adjacent_lines.size()):
		for j in range(i + 1, adjacent_lines.size()):
			var line1 = adjacent_lines[i]
			var line2 = adjacent_lines[j]

			# 跳过有共享端点的线
			if line1.from.id == line2.from.id or line1.from.id == line2.to.id or \
			   line1.to.id == line2.from.id or line1.to.id == line2.to.id:
				continue

			# 检查是否交叉（简单的一维交叉检测）
			var from1_y = line1.from.position.y
			var to1_y = line1.to.position.y
			var from2_y = line2.from.position.y
			var to2_y = line2.to.position.y

			# 如果两条线起点和终点的相对位置相反，则交叉
			var cross = (from1_y < from2_y and to1_y > to2_y) or (from1_y > from2_y and to1_y < to2_y)
			if cross:
				cross_count += 1
				if cross_count <= 10:  # 只打印前 10 个
					print("  [交叉] 线#", i, ": 节点#", line1.from.id, "(y=", from1_y, ")->节点#", line1.to.id, "(y=", to1_y, ")",
						  " 与 线#", j, ": 节点#", line2.from.id, "(y=", from2_y, ")->节点#", line2.to.id, "(y=", to2_y, ") 交叉")

	if cross_count > 10:
		print("  ... 还有 ", cross_count - 10, " 个交叉")

	print("\n[交叉检测] 共发现 ", cross_count, " 个交叉（仅限相邻层连接）\n")
	return cross_count


## 更新 canvas 大小
func _update_canvas_size(level_data: LevelData):
	if level_data.nodes.size() == 0:
		return
	
	var max_x = 0.0
	var max_y = 0.0
	
	for node in level_data.nodes:
		if node.position.x > max_x:
			max_x = node.position.x
		if node.position.y > max_y:
			max_y = node.position.y
	
	canvas.custom_minimum_size = Vector2(
		max_x + layer_padding * 2,
		max_y + layer_padding * 2
	)


## 绘制函数
func _on_canvas_draw():
	var level_gen = LevelGenerator.get_instance()
	if level_gen == null or level_gen.current_level_data == null:
		return
	
	var level_data = level_gen.current_level_data
	
	# 绘制连接线
	_draw_connections(level_data)
	
	# 绘制节点
	_draw_nodes(level_data)


## 绘制连接线
func _draw_connections(level_data: LevelData):
	for node in level_data.nodes:
		for next_id in node.connections:
			var next_node = level_data.get_node(next_id)
			if next_node:
				var start_pos = node.position + canvas_offset
				var end_pos = next_node.position + canvas_offset
				
				# 绘制线条
				canvas.draw_line(start_pos, end_pos, Color.WHITE, 2)
				
				# 绘制箭头
				_draw_arrow(start_pos, end_pos)


## 绘制箭头
func _draw_arrow(start: Vector2, end: Vector2):
	var dir = (end - start).normalized()
	var arrow_size = 8.0
	var arrow_angle = PI / 6
	
	var arrow_point = end
	var arrow_left = arrow_point - dir.rotated(arrow_angle) * arrow_size
	var arrow_right = arrow_point - dir.rotated(-arrow_angle) * arrow_size
	
	canvas.draw_colored_polygon(
		[arrow_point, arrow_left, arrow_right],
		Color.WHITE
	)


## 绘制节点
func _draw_nodes(level_data: LevelData):
	for node in level_data.nodes:
		var pos = node.position + canvas_offset
		var color = TYPE_COLORS.get(node.type, Color.WHITE)
		
		# 计算节点区域（圆角矩形）
		var rect_size = Vector2(node_radius * 2.5, node_radius * 1.8)
		var rect_pos = pos - rect_size / 2
		
		# 绘制圆角矩形背景
		var rect = Rect2(rect_pos, rect_size)
		
		# 绘制边框
		if node.is_core:
			# 核心节点：粗边框
			canvas.draw_rect(rect, Color.BLACK, false, 4)  # 外框
			canvas.draw_rect(rect, color, true)  # 填充
			canvas.draw_rect(rect, Color.WHITE, false, 2)  # 内框
		else:
			# 随机节点：细边框
			canvas.draw_rect(rect, Color.BLACK, false, 2)
			canvas.draw_rect(rect, color, true)

		# 绘制节点名称（使用唯一 ID）和类型名称
		var id_text = "节点#" + str(node.id)
		var type_name = node.get_type_name()
		var display_text = type_name + "\n" + id_text

		var font = ThemeDB.fallback_font
		if font:
			# 计算文本大小（两行）
			var type_text_size = font.get_string_size(type_name)
			var id_text_size = font.get_string_size(id_text)
			var total_height = font.get_height() * 2 + 2  # 两行文本 + 间距
			var max_width = maxf(type_text_size.x, id_text_size.x)

			# 计算居中位置
			var text_start_x = pos.x - max_width / 2
			var text_start_y = pos.y - total_height / 2 + font.get_ascent()

			# 绘制类型名称（第一行，加粗效果）
			var type_pos = Vector2(text_start_x, text_start_y)
			canvas.draw_string(font, type_pos, type_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.BLACK)

			# 绘制节点 ID（第二行）
			var id_pos = Vector2(text_start_x, text_start_y + font.get_height() + 2)
			canvas.draw_string(font, id_pos, id_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.BLACK)


## Canvas 拖动处理
func _on_canvas_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_position = event.position - canvas_offset
			else:
				is_dragging = false
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			canvas_offset = event.position - drag_start_position
			canvas.queue_redraw()


## 按钮回调
func _on_regenerate_pressed():
	generate_and_display()


func _on_print_log_pressed():
	var level_gen = LevelGenerator.get_instance()
	if level_gen and level_gen.current_level_data:
		level_gen.current_level_data.print_debug_info()

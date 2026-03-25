extends Control
## 关卡地图显示 UI
## 负责可视化展示生成的关卡地图

# 配置
var config: Dictionary = {}
var node_radius: float = 25.0
var node_spacing_x: float = 150.0
var node_spacing_y: float = 120.0
var layer_padding: float = 80.0

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
	print("[LevelMapDisplay] _ready 执行")
	
	# 延迟查找节点（确保场景树完全加载）
	call_deferred("_find_nodes_deferred")


## 延迟查找节点
func _find_nodes_deferred():
	print("  - 开始查找节点...")
	_find_nodes()
	
	print("  - canvas: ", canvas)
	print("  - difficulty_label: ", difficulty_label)
	
	# 连接信号
	if regenerate_button:
		regenerate_button.pressed.connect(_on_regenerate_pressed)
	if print_log_button:
		print_log_button.pressed.connect(_on_print_log_pressed)
	
	# 初始化 canvas 拖动
	if canvas:
		print("[LevelMapDisplay] 连接 canvas 信号")
		canvas.gui_input.connect(_on_canvas_gui_input)
		# 确保 draw 信号连接
		if not canvas.is_connected("draw", _on_canvas_draw):
			canvas.connect("draw", _on_canvas_draw)
			print("[LevelMapDisplay] 已连接 draw 信号")
	else:
		push_error("[LevelMapDisplay] canvas 为空！")
	
	# 加载配置
	_load_config()
	
	# 自动生成关卡
	generate_and_display()


## 查找节点（简化版：直接遍历所有子节点）
func _find_nodes():
	print("  - 开始遍历所有子节点...")
	print("  - 子节点数量：", get_children().size())
	
	for child in get_children():
		print("    - 子节点：", child.name, " 类型：", child.get_class())
		
		# 查找 Canvas（名称中包含 Canvas）
		if "Canvas" in child.name and child is Control:
			canvas = child
			print("      -> 找到 Canvas!")
		
		# 查找标签
		if "DifficultyLabel" in child.name:
			difficulty_label = child as Label
			print("      -> 找到 DifficultyLabel!")
		elif "TotalLabel" in child.name:
			total_label = child as Label
			print("      -> 找到 TotalLabel!")
		elif "SeedLabel" in child.name:
			seed_label = child as Label
			print("      -> 找到 SeedLabel!")
		
		# 查找按钮
		if "RegenerateButton" in child.name:
			regenerate_button = child as Button
			print("      -> 找到 RegenerateButton!")
		elif "PrintLogButton" in child.name:
			print_log_button = child as Button
			print("      -> 找到 PrintLogButton!")


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
	
	print("[LevelMapDisplay] 开始显示关卡...")
	print("  - 节点数量：", level_data.nodes.size())
	print("  - Canvas: ", canvas)
	
	# 更新 UI 信息
	if difficulty_label:
		difficulty_label.text = "难度：" + str(level_data.difficulty)
	if total_label:
		total_label.text = "总关卡：" + str(level_data.total_nodes)
	if seed_label:
		seed_label.text = "种子：" + str(level_data.seed_value)
	
	# 计算节点位置
	print("[LevelMapDisplay] 计算节点位置...")
	_calculate_node_positions(level_data)
	
	# 更新 canvas 大小以适应所有节点
	print("[LevelMapDisplay] 更新 Canvas 大小...")
	_update_canvas_size(level_data)
	
	# 强制重绘
	print("[LevelMapDisplay] 触发重绘...")
	canvas.queue_redraw()


## 计算节点位置
func _calculate_node_positions(level_data: LevelData):
	print("[LevelMapDisplay] _calculate_node_positions 开始")
	var layers_dict = {}
	
	# 按层级分组
	for node in level_data.nodes:
		var layer = node.layer
		print("  - 节点 ", node.id, " 层级：", layer, " 类型：", node.type, " 核心：", node.is_core)
		if layer not in layers_dict:
			layers_dict[layer] = []
		layers_dict[layer].append(node)
	
	# 计算每层的位置
	var layers = layers_dict.keys()
	layers.sort()
	print("[LevelMapDisplay] 层级数量：", layers.size())
	
	for layer_idx in range(layers.size()):
		var layer = layers[layer_idx]
		var layer_nodes = layers_dict[layer]
		print("  - 层级 ", layer, " (索引：", layer_idx, ") 节点数：", layer_nodes.size())
		
		# 计算该层节点的 Y 位置
		var y_pos = layer_idx * node_spacing_y + layer_padding
		var layer_height = layer_nodes.size() * node_spacing_y
		for node_idx in range(layer_nodes.size()):
			var node = layer_nodes[node_idx]
			var x_pos = node_idx * node_spacing_x + layer_padding
			node.position = Vector2(x_pos, y_pos)
			print("    - 节点 ", node.id, " 位置：", node.position)


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
	print("[LevelMapDisplay] _on_canvas_draw 被调用")
	
	var level_gen = LevelGenerator.get_instance()
	if level_gen == null or level_gen.current_level_data == null:
		print("[LevelMapDisplay] LevelGenerator 或当前关卡数据为空")
		return
	
	var level_data = level_gen.current_level_data
	print("[LevelMapDisplay] 开始绘制，节点数：", level_data.nodes.size())
	
	# 绘制连接线
	_draw_connections(level_data)
	
	# 绘制节点
	_draw_nodes(level_data)
	
	print("[LevelMapDisplay] 绘制完成")


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
		
		# 绘制节点圆形
		if node.is_core:
			# 核心节点：粗边框
			canvas.draw_circle(pos, node_radius + 2, Color.BLACK)
			canvas.draw_circle(pos, node_radius, color)
			canvas.draw_arc(pos, node_radius, 0, TAU, 32, Color.WHITE, 3, true)
		else:
			# 随机节点：细边框
			canvas.draw_circle(pos, node_radius + 1, Color.BLACK)
			canvas.draw_circle(pos, node_radius, color)
			canvas.draw_arc(pos, node_radius, 0, TAU, 32, Color.WHITE, 1, true)
		
		# 绘制节点 ID
		var text = str(node.id)
		var font = ThemeDB.fallback_font
		if font:
			var text_size = font.get_string_size(text)
			var text_pos = pos - text_size / 2 + Vector2(0, font.get_height() / 2)
			canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.BLACK)


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

extends Node3D

@onready var dice = $Dice
@onready var camera = $Camera3D
@onready var light = $DirectionalLight3D
@onready var sandbox = $Sandbox
var start_timer: Timer
var throw_timer: Timer

func _ready():
	# 确保相机正确指向原点
	if camera:
		camera.look_at_from_position(camera.position, Vector3(0, 0, 0), Vector3(0, 1, 0))
	
	# 确保光照正确指向原点
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))
	
	# 创建沙盘碰撞形状和网格
	if sandbox:
		# 创建地面碰撞形状
		var ground_collision = sandbox.get_node("Ground")
		if ground_collision:
			var ground_shape = BoxShape3D.new()
			ground_shape.size = Vector3(16, 0.1, 9)
			ground_collision.shape = ground_shape
		
		# 创建地面网格
		var ground_mesh = sandbox.get_node("GroundMesh")
		if ground_mesh:
			var ground_mesh_resource = BoxMesh.new()
			ground_mesh_resource.size = Vector3(16, 0.1, 9)
			ground_mesh.mesh = ground_mesh_resource
			
			# 创建地面材质
			var ground_material = StandardMaterial3D.new()
			ground_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
			ground_mesh.material_override = ground_material
		
		# 创建北墙碰撞形状
		var wall_north = sandbox.get_node("WallNorth")
		if wall_north:
			var wall_north_shape = BoxShape3D.new()
			wall_north_shape.size = Vector3(16, 10, 0.1)
			wall_north.shape = wall_north_shape
		
		# 创建北墙网格
		var wall_north_mesh = MeshInstance3D.new()
		wall_north_mesh.name = "WallNorthMesh"
		wall_north_mesh.position = Vector3(0, -3.95, 4.5)
		var wall_north_mesh_resource = BoxMesh.new()
		wall_north_mesh_resource.size = Vector3(16, 3, 0.1)
		wall_north_mesh.mesh = wall_north_mesh_resource
		var wall_material = StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.7, 0.3, 0.3, 1)
		wall_north_mesh.material_override = wall_material
		sandbox.add_child(wall_north_mesh)
		
		# 创建南墙碰撞形状
		var wall_south = sandbox.get_node("WallSouth")
		if wall_south:
			var wall_south_shape = BoxShape3D.new()
			wall_south_shape.size = Vector3(16, 10, 0.1)
			wall_south.shape = wall_south_shape
		
		# 创建南墙网格
		var wall_south_mesh = MeshInstance3D.new()
		wall_south_mesh.name = "WallSouthMesh"
		wall_south_mesh.position = Vector3(0, -3.95, -4.5)
		var wall_south_mesh_resource = BoxMesh.new()
		wall_south_mesh_resource.size = Vector3(16, 3, 0.1)
		wall_south_mesh.mesh = wall_south_mesh_resource
		wall_south_mesh.material_override = wall_material
		sandbox.add_child(wall_south_mesh)
		
		# 创建东墙碰撞形状
		var wall_east = sandbox.get_node("WallEast")
		if wall_east:
			var wall_east_shape = BoxShape3D.new()
			wall_east_shape.size = Vector3(0.1, 10, 9)
			wall_east.shape = wall_east_shape
		
		# 创建东墙网格
		var wall_east_mesh = MeshInstance3D.new()
		wall_east_mesh.name = "WallEastMesh"
		wall_east_mesh.position = Vector3(8, -3.95, 0)
		var wall_east_mesh_resource = BoxMesh.new()
		wall_east_mesh_resource.size = Vector3(0.1, 3, 9)
		wall_east_mesh.mesh = wall_east_mesh_resource
		wall_east_mesh.material_override = wall_material
		sandbox.add_child(wall_east_mesh)
		
		# 创建西墙碰撞形状
		var wall_west = sandbox.get_node("WallWest")
		if wall_west:
			var wall_west_shape = BoxShape3D.new()
			wall_west_shape.size = Vector3(0.1, 10, 9)
			wall_west.shape = wall_west_shape
		
		# 创建西墙网格
		var wall_west_mesh = MeshInstance3D.new()
		wall_west_mesh.name = "WallWestMesh"
		wall_west_mesh.position = Vector3(-8, -3.95, 0)
		var wall_west_mesh_resource = BoxMesh.new()
		wall_west_mesh_resource.size = Vector3(0.1, 3, 9)
		wall_west_mesh.mesh = wall_west_mesh_resource
		wall_west_mesh.material_override = wall_material
		sandbox.add_child(wall_west_mesh)
		
		# 创建顶部碰撞形状（防止骰子跳出摄像机视野）
		var wall_top = CollisionShape3D.new()
		wall_top.name = "WallTop"
		wall_top.position = Vector3(0, 8, 0)
		var wall_top_shape = BoxShape3D.new()
		wall_top_shape.size = Vector3(16, 0.5, 9)
		wall_top.shape = wall_top_shape
		sandbox.add_child(wall_top)
	
	# 设置物理世界
	# 暂时注释掉，使用默认重力
	# var world = get_world_3d()
	# if world:
	# 	# 物理世界的访问方式在Godot 4中可能有所不同
	# 	# var physics_world = world.physics_world_3d
	# 	# if physics_world:
	# 	# 	physics_world.gravity = Vector3(0, -9.8, 0)
	
	# 创建启动计时器
	start_timer = Timer.new()
	start_timer.wait_time = 1.0
	start_timer.one_shot = true
	start_timer.timeout.connect(start_demo)
	add_child(start_timer)
	start_timer.start()

func start_demo():
	# 设置骰子初始状态：在屏幕靠下位置半空悬浮
	if dice:
		# 设置初始位置（屏幕靠下位置）
		dice.position = Vector3(0, 2, 0)
		dice.rotation = Vector3()
	
	# 取消自动投掷计时器
	# throw_timer = Timer.new()
	# throw_timer.wait_time = 3.0
	# throw_timer.autostart = true
	# throw_timer.timeout.connect(throw_dice)
	# add_child(throw_timer)

func throw_dice():
	# 检查骰子节点是否存在
	if not dice:
		print("Error: Dice node not found")
		return
	
	# 检查骰子节点是否有roll方法
	if not dice.has_method("roll"):
		print("Error: Dice node does not have roll method")
		print("Dice node type:", dice.get_class())
		return
	
	# 重置骰子位置（离地面5个骰子高度）
	dice.position = Vector3(0, 5, 0)
	dice.rotation = Vector3()
	
	# 生成随机投掷力
	var force = Vector3(
		randf_range(-5, 5),
		randf_range(5, 7.5),
		randf_range(-5, 5)
	)
	
	# 投掷骰子
	dice.roll(force)

func _input(event):
	# 按空格键手动投掷骰子
	if event.is_action_pressed("ui_accept"):
		throw_dice()
	# 按R键恢复骰子初始状态
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_dice()

func reset_dice():
	# 重置骰子到初始状态
	if dice:
		# 设置初始位置（屏幕靠下位置）
		dice.position = Vector3(0, 2, 0)
		dice.rotation = Vector3()
		# 确保骰子静止
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO
		# 禁用重力，使骰子悬浮
		dice.gravity_scale = 0.0
		print("Dice reset to initial state")

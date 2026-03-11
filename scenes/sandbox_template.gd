extends Node3D

@onready var camera = $Camera3D
@onready var sandbox = $Sandbox
@onready var light = $DirectionalLight3D

var base_width = 24.0  # 基础宽度（屏幕水平方向），放大 1.5 倍
var base_height = 13.5   # 基础高度（屏幕竖直方向），放大 1.5 倍

func _ready():
	# 配置摄像机
	_setup_camera()
	
	# 配置光源
	_setup_light()
	
	# 配置沙盘
	_setup_sandbox()
	
	print("沙盘模板场景加载完成")

func _setup_camera():
	# 调整摄像机位置和 FOV，使其拉远并更接近 2D 效果
	if camera:
		# 设置摄像机位置，进一步拉高镜头以看到整个沙盘
		camera.position = Vector3(0, 60, 0)  # 进一步拉高摄像机
		# 进一步减小 FOV，更贴近俯视 2D 效果
		camera.fov = 15.0  # 进一步减小 FOV 值
		# 直接设置相机旋转，避免 look_at 的共线问题
		camera.rotation = Vector3(-PI/2, 0, 0)

func _setup_light():
	# 确保光照正确指向原点
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))

func _setup_sandbox():
	# 计算基础尺寸，保持 16:9 比例
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width  # 屏幕水平方向（x 轴）
	var sandbox_height = sandbox_width / base_ratio  # 屏幕竖直方向（z 轴），保持 16:9 比例
	
	# 创建沙盘碰撞形状和网格
	if sandbox:
		# 创建地面碰撞形状
		var ground_collision = sandbox.get_node("Ground")
		if ground_collision:
			var ground_shape = BoxShape3D.new()
			ground_shape.size = Vector3(sandbox_width, 0.1, sandbox_height)
			ground_collision.shape = ground_shape
			
		# 为地面添加物理材质，提升反弹系数 50%
		var ground_physics_material = PhysicsMaterial.new()
		ground_physics_material.bounce = 0.3  # 提升反弹效果 50%
		ground_physics_material.friction = 0.8  # 增加摩擦力
		# 为沙盒静态体设置物理材质
		sandbox.physics_material_override = ground_physics_material
		
		# 创建地面网格
		var ground_mesh = sandbox.get_node("GroundMesh")
		if ground_mesh:
			var ground_mesh_resource = BoxMesh.new()
			ground_mesh_resource.size = Vector3(sandbox_width, 0.1, sandbox_height)
			ground_mesh.mesh = ground_mesh_resource
			
			# 创建地面材质
			var ground_material = StandardMaterial3D.new()
			ground_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
			ground_mesh.material_override = ground_material
		
		# 创建北墙（屏幕上方，z 轴负方向）
		var wall_north = CollisionShape3D.new()
		wall_north.name = "WallNorth"
		var wall_north_shape = BoxShape3D.new()
		wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_north.shape = wall_north_shape
		wall_north.position = Vector3(0, 21, -sandbox_height/2)
		sandbox.add_child(wall_north)
		
		# 创建北墙网格
		var wall_north_mesh = MeshInstance3D.new()
		wall_north_mesh.name = "WallNorthMesh"
		wall_north_mesh.position = Vector3(0, 0, -sandbox_height/2)
		var wall_north_mesh_resource = BoxMesh.new()
		wall_north_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
		wall_north_mesh.mesh = wall_north_mesh_resource
		var north_wall_material = StandardMaterial3D.new()
		north_wall_material.albedo_color = Color(0.3, 0.3, 0.7, 1)  # 北墙（屏幕上方）：蓝色
		wall_north_mesh.material_override = north_wall_material
		sandbox.add_child(wall_north_mesh)
		
		# 创建南墙（屏幕下方，z 轴正方向）
		var wall_south = CollisionShape3D.new()
		wall_south.name = "WallSouth"
		var wall_south_shape = BoxShape3D.new()
		wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_south.shape = wall_south_shape
		wall_south.position = Vector3(0, 21, sandbox_height/2)
		sandbox.add_child(wall_south)
		
		# 创建南墙网格
		var wall_south_mesh = MeshInstance3D.new()
		wall_south_mesh.name = "WallSouthMesh"
		wall_south_mesh.position = Vector3(0, 0, sandbox_height/2)
		var wall_south_mesh_resource = BoxMesh.new()
		wall_south_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
		wall_south_mesh.mesh = wall_south_mesh_resource
		var south_wall_material = StandardMaterial3D.new()
		south_wall_material.albedo_color = Color(0.7, 0.3, 0.3, 1)  # 南墙（屏幕下方）：红色
		wall_south_mesh.material_override = south_wall_material
		sandbox.add_child(wall_south_mesh)
		
		# 创建东墙（屏幕右侧，x 轴正方向）
		var wall_east = CollisionShape3D.new()
		wall_east.name = "WallEast"
		var wall_east_shape = BoxShape3D.new()
		wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_east.shape = wall_east_shape
		wall_east.position = Vector3(sandbox_width/2, 21, 0)
		sandbox.add_child(wall_east)
		
		# 创建东墙网格
		var wall_east_mesh = MeshInstance3D.new()
		wall_east_mesh.name = "WallEastMesh"
		wall_east_mesh.position = Vector3(sandbox_width/2, 0, 0)
		var wall_east_mesh_resource = BoxMesh.new()
		wall_east_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
		wall_east_mesh.mesh = wall_east_mesh_resource
		var east_wall_material = StandardMaterial3D.new()
		east_wall_material.albedo_color = Color(0.7, 0.7, 0.3, 1)  # 东墙（屏幕右侧）：黄色
		wall_east_mesh.material_override = east_wall_material
		sandbox.add_child(wall_east_mesh)
		
		# 创建西墙（屏幕左侧，x 轴负方向）
		var wall_west = CollisionShape3D.new()
		wall_west.name = "WallWest"
		var wall_west_shape = BoxShape3D.new()
		wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_west.shape = wall_west_shape
		wall_west.position = Vector3(-sandbox_width/2, 21, 0)
		sandbox.add_child(wall_west)
		
		# 创建西墙网格
		var wall_west_mesh = MeshInstance3D.new()
		wall_west_mesh.name = "WallWestMesh"
		wall_west_mesh.position = Vector3(-sandbox_width/2, 0, 0)
		var wall_west_mesh_resource = BoxMesh.new()
		wall_west_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
		wall_west_mesh.mesh = wall_west_mesh_resource
		var west_wall_material = StandardMaterial3D.new()
		west_wall_material.albedo_color = Color(0.3, 0.7, 0.3, 1)  # 西墙（屏幕左侧）：绿色
		wall_west_mesh.material_override = west_wall_material
		sandbox.add_child(wall_west_mesh)
		
		# 创建顶部碰撞
		var top_collision = sandbox.get_node("TopCollision")
		if top_collision:
			var top_shape = BoxShape3D.new()
			top_shape.size = Vector3(sandbox_width, 0.5, sandbox_height)
			top_collision.position = Vector3(0, 4, 0)
			top_collision.shape = top_shape

	# 增加重力加速度，加快骰子下落速度
	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)  # 4 倍重力加速度，加快下落速度

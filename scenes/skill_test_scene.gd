extends Node3D

@onready var camera = $Camera3D
@onready var sandbox = $Sandbox
@onready var light = $DirectionalLight3D
@onready var attacker_dice = $AttackerDice
@onready var target_dice1 = $TargetDice1
@onready var target_dice2 = $TargetDice2
@onready var target_dice3 = $TargetDice3
@onready var marker = $Marker3D

var base_width = 24.0
var base_height = 13.5

func _ready():
	_setup_camera()
	_setup_light()
	_setup_sandbox()
	_setup_dice()
	
	print("技能测试场景加载完成")
	print("攻击方骰子位置：", attacker_dice.position)
	print("目标方 1 位置：", target_dice1.position)
	print("目标方 2 位置：", target_dice2.position)
	print("目标方 3 位置：", target_dice3.position)

func _setup_camera():
	if camera:
		camera.position = Vector3(0, 60, 0)
		camera.fov = 15.0
		camera.rotation = Vector3(-PI/2, 0, 0)

func _setup_light():
	if light:
		light.look_at_from_position(light.position, Vector3(0, 0, 0), Vector3(0, 1, 0))

func _setup_sandbox():
	var base_ratio = 16.0 / 9.0
	var sandbox_width = base_width
	var sandbox_height = sandbox_width / base_ratio
	
	if sandbox:
		var ground_collision = sandbox.get_node("Ground")
		if ground_collision:
			var ground_shape = BoxShape3D.new()
			ground_shape.size = Vector3(sandbox_width, 0.1, sandbox_height)
			ground_collision.shape = ground_shape
			
		var ground_physics_material = PhysicsMaterial.new()
		ground_physics_material.bounce = 0.3
		ground_physics_material.friction = 0.8
		sandbox.physics_material_override = ground_physics_material
		
		var ground_mesh = sandbox.get_node("GroundMesh")
		if ground_mesh:
			var ground_mesh_resource = BoxMesh.new()
			ground_mesh_resource.size = Vector3(sandbox_width, 0.1, sandbox_height)
			ground_mesh.mesh = ground_mesh_resource
			
			var ground_material = StandardMaterial3D.new()
			ground_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
			ground_mesh.material_override = ground_material
		
		var wall_north = CollisionShape3D.new()
		wall_north.name = "WallNorth"
		var wall_north_shape = BoxShape3D.new()
		wall_north_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_north.shape = wall_north_shape
		wall_north.position = Vector3(0, 21, -sandbox_height/2)
		sandbox.add_child(wall_north)
		
		var wall_north_mesh = MeshInstance3D.new()
		wall_north_mesh.name = "WallNorthMesh"
		wall_north_mesh.position = Vector3(0, 0, -sandbox_height/2)
		var wall_north_mesh_resource = BoxMesh.new()
		wall_north_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
		wall_north_mesh.mesh = wall_north_mesh_resource
		var north_wall_material = StandardMaterial3D.new()
		north_wall_material.albedo_color = Color(0.3, 0.3, 0.7, 1)
		wall_north_mesh.material_override = north_wall_material
		sandbox.add_child(wall_north_mesh)
		
		var wall_south = CollisionShape3D.new()
		wall_south.name = "WallSouth"
		var wall_south_shape = BoxShape3D.new()
		wall_south_shape.size = Vector3(sandbox_width, 50, 0.1)
		wall_south.shape = wall_south_shape
		wall_south.position = Vector3(0, 21, sandbox_height/2)
		sandbox.add_child(wall_south)
		
		var wall_south_mesh = MeshInstance3D.new()
		wall_south_mesh.name = "WallSouthMesh"
		wall_south_mesh.position = Vector3(0, 0, sandbox_height/2)
		var wall_south_mesh_resource = BoxMesh.new()
		wall_south_mesh_resource.size = Vector3(sandbox_width, 3, 0.1)
		wall_south_mesh.mesh = wall_south_mesh_resource
		var south_wall_material = StandardMaterial3D.new()
		south_wall_material.albedo_color = Color(0.7, 0.3, 0.3, 1)
		wall_south_mesh.material_override = south_wall_material
		sandbox.add_child(wall_south_mesh)
		
		var wall_east = CollisionShape3D.new()
		wall_east.name = "WallEast"
		var wall_east_shape = BoxShape3D.new()
		wall_east_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_east.shape = wall_east_shape
		wall_east.position = Vector3(sandbox_width/2, 21, 0)
		sandbox.add_child(wall_east)
		
		var wall_east_mesh = MeshInstance3D.new()
		wall_east_mesh.name = "WallEastMesh"
		wall_east_mesh.position = Vector3(sandbox_width/2, 0, 0)
		var wall_east_mesh_resource = BoxMesh.new()
		wall_east_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
		wall_east_mesh.mesh = wall_east_mesh_resource
		var east_wall_material = StandardMaterial3D.new()
		east_wall_material.albedo_color = Color(0.7, 0.7, 0.3, 1)
		wall_east_mesh.material_override = east_wall_material
		sandbox.add_child(wall_east_mesh)
		
		var wall_west = CollisionShape3D.new()
		wall_west.name = "WallWest"
		var wall_west_shape = BoxShape3D.new()
		wall_west_shape.size = Vector3(0.1, 50, sandbox_height)
		wall_west.shape = wall_west_shape
		wall_west.position = Vector3(-sandbox_width/2, 21, 0)
		sandbox.add_child(wall_west)
		
		var wall_west_mesh = MeshInstance3D.new()
		wall_west_mesh.name = "WallWestMesh"
		wall_west_mesh.position = Vector3(-sandbox_width/2, 0, 0)
		var wall_west_mesh_resource = BoxMesh.new()
		wall_west_mesh_resource.size = Vector3(0.1, 3, sandbox_height)
		wall_west_mesh.mesh = wall_west_mesh_resource
		var west_wall_material = StandardMaterial3D.new()
		west_wall_material.albedo_color = Color(0.3, 0.7, 0.3, 1)
		wall_west_mesh.material_override = west_wall_material
		sandbox.add_child(wall_west_mesh)
		
		var top_collision = sandbox.get_node("TopCollision")
		if top_collision:
			var top_shape = BoxShape3D.new()
			top_shape.size = Vector3(sandbox_width, 0.5, sandbox_height)
			top_collision.position = Vector3(0, 4, 0)
			top_collision.shape = top_shape

	ProjectSettings.set_setting("physics/3d/default_gravity", 39.2)

func _setup_dice():
	# 不要修改骰子的属性，让骰子脚本自己初始化
	# 只需要确保骰子不会在测试时滚动即可
	var dice_list = [attacker_dice, target_dice1, target_dice2, target_dice3]
	
	for dice in dice_list:
		if dice:
			# 保持骰子静止，但不影响其贴图配置
			dice.linear_velocity = Vector3.ZERO
			dice.angular_velocity = Vector3.ZERO
			# 设置为冻结状态，但不影响重力
			dice.freeze = true

func get_attacker_dice() -> RigidBody3D:
	return attacker_dice

func get_target_dice() -> Array:
	return [target_dice1, target_dice2, target_dice3]

func get_marker_position() -> Vector3:
	return marker.position

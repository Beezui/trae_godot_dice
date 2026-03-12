extends Node3D

## 技能测试场景
## 用于统一测试所有技能

@onready var option_button = $UI/MarginContainer/VBoxContainer/OptionButton
@onready var cast_button = $UI/MarginContainer/VBoxContainer/CastButton
@onready var result_label = $UI/MarginContainer/VBoxContainer/ResultLabel
@onready var caster_marker = $CasterMarker
@onready var target1 = $Target1
@onready var target2 = $Target2

var selected_skill_id: String = ""
var available_skills: Array = []


func _ready():
	_setup_test_environment()
	_setup_ui()
	_load_available_skills()


## 设置测试环境
func _setup_test_environment():
	# 设置地面
	var ground = $Sandbox/Ground
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(24, 0.1, 13.5)
	ground.shape = ground_shape
	
	var ground_mesh = $Sandbox/GroundMesh
	var ground_mesh_resource = BoxMesh.new()
	ground_mesh_resource.size = Vector3(24, 0.1, 13.5)
	ground_mesh.mesh = ground_mesh_resource
	
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
	ground_mesh.material_override = ground_material
	
	# 设置目标
	_setup_target(target1)
	_setup_target(target2)
	
	print("技能测试场景已就绪")


## 设置目标
func _setup_target(target: RigidBody3D):
	target.mass = 1.0
	target.linear_damping = 0.5
	target.angular_damping = 0.5
	
	var collision_shape = target.get_node("CollisionShape3D")
	if collision_shape:
		var shape = SphereShape3D.new()
		shape.radius = 0.5
		collision_shape.shape = shape
	
	var mesh_instance = target.get_node("MeshInstance3D")
	if mesh_instance:
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.5
		sphere_mesh.height = 1.0
		mesh_instance.mesh = sphere_mesh
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 0.5, 0.5, 1)
		mesh_instance.material_override = material


## 设置 UI
func _setup_ui():
	cast_button.pressed.connect(_on_cast_button_pressed)


## 加载可用技能
func _load_available_skills():
	# 从 SkillManager 获取所有已注册的技能
	available_skills = SkillManager.get_all_skill_ids()
	
	for skill_id in available_skills:
		var skill_config = SkillManager.get_skill(skill_id)
		var skill_name = skill_config.get("name", skill_id)
		option_button.add_item(skill_name + " (" + skill_id + ")", available_skills.find(skill_id))
	
	option_button.item_selected.connect(_on_skill_selected)
	
	if available_skills.size() > 0:
		selected_skill_id = available_skills[0]


## 选择技能
func _on_skill_selected(index: int):
	if index >= 0 and index < available_skills.size():
		selected_skill_id = available_skills[index]
		print("选择技能：", selected_skill_id)


## 释放技能
func _on_cast_button_pressed():
	if selected_skill_id == "":
		result_label.text = "请先选择技能"
		return
	
	print("=== 释放技能 ===")
	print("技能 ID: ", selected_skill_id)
	
	# 设置固定的施法者位置（左侧标记点）
	var caster_position = caster_marker.global_position
	
	# 设置固定的目标（右侧第一个目标）
	var targets = [target1]
	
	# 模拟骰子结果（测试用）
	var dice_results = {
		"str": 5,
		"agi": 4,
		"int": 6
	}
	
	var params = {
		"dice_results": dice_results,
		"scene": self,  # 传递当前场景
		"caster_position": caster_position  # 传递施法者位置
	}
	
	# 调用 SkillManager 释放技能
	var success = SkillManager.use_skill(selected_skill_id, caster_marker, targets, params)
	
	if success:
		result_label.text = "技能 " + selected_skill_id + " 释放成功"
	else:
		result_label.text = "技能 " + selected_skill_id + " 释放失败"


## 重置场景
func reset_scene():
	# 重置目标位置
	target1.position = Vector3(6, 0.5, -2)
	target1.linear_velocity = Vector3.ZERO
	target1.angular_velocity = Vector3.ZERO
	
	target2.position = Vector3(6, 0.5, 2)
	target2.linear_velocity = Vector3.ZERO
	target2.angular_velocity = Vector3.ZERO
	
	result_label.text = ""

extends CanvasLayer

@onready var dice_value_label = $Panel/VBoxContainer/HBoxContainer/DiceValue
@onready var skill_name_label = $Panel/VBoxContainer/HBoxContainer/SkillName
@onready var roll_button = $Panel/VBoxContainer/Button

var dice_ref = null

func _ready():
	# 连接按钮信号
	roll_button.pressed.connect(_on_roll_button_pressed)

func set_dice_reference(dice: RigidBody3D):
	# 设置骰子引用
	dice_ref = dice

func update_display(value: int, skill_name: String):
	# 更新显示
	dice_value_label.text = "点数: " + str(value)
	skill_name_label.text = "技能: " + skill_name

func _on_roll_button_pressed():
	# 再次投掷按钮点击
	if dice_ref and dice_ref.has_method("roll"):
		# 生成随机力向量
		var force = Vector3(
			randf_range(-10, 10),
			randf_range(10, 20),
			randf_range(-10, 10)
		)
		# 重置骰子位置
		dice_ref.position = Vector3(0, 2, 0)
		dice_ref.linear_velocity = Vector3.ZERO
		dice_ref.angular_velocity = Vector3.ZERO
		# 投掷骰子
		dice_ref.roll(force)

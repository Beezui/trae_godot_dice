extends StaticBody3D

@export var object_type: String = "obstacle"
@export var interaction_effect: String = "bounce"

func _ready():
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# 检测是否与骰子碰撞
	if body is RigidBody3D and body.has_method("get_dice_type"):
		var dice_type = body.get_dice_type()
		print(object_type, " collided with dice: ", dice_type)
		
		# 根据物体类型和骰子类型执行不同的交互
		match object_type:
			"obstacle":
				handle_obstacle_interaction(body)
			"power_up":
				handle_power_up_interaction(body)
			"trap":
				handle_trap_interaction(body)

func handle_obstacle_interaction(dice):
	# 障碍物交互：反弹骰子
	print("Obstacle bouncing dice")
	# 这里可以添加反弹力和特效

func handle_power_up_interaction(dice):
	#  power-up交互：增强骰子
	print("Power-up enhancing dice")
	# 这里可以添加增强效果和特效

func handle_trap_interaction(dice):
	# 陷阱交互：削弱骰子
	print("Trap weakening dice")
	# 这里可以添加削弱效果和特效

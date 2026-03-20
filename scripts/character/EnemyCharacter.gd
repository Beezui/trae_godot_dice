class_name EnemyCharacter
extends BaseCharacter

## 是否是玩家控制角色
var is_player_controlled: bool = false

## AI 行为状态
enum AIState { IDLE, ATTACKING, DEFENDING, DEAD }
var current_ai_state: AIState = AIState.IDLE


func _init(data: Dictionary = {}):
	super._init(data)
	is_player = false
	is_player_controlled = false
	current_ai_state = AIState.IDLE
	print("【EnemyCharacter】创建敌人角色：", name if data.size() > 0 else "未命名")


func is_skill_dice_visible() -> bool:
	"""
	敌人的技能骰子是否可见
	(根据需求，敌人的技能骰子和属性骰子暂时不出现在棋盘上)
	:return: false
	"""
	return false


func is_attribute_dice_visible() -> bool:
	"""
	敌人的属性骰子是否可见
	:return: false
	"""
	return false


func select_target(targets: Array) -> BaseCharacter:
	"""
	AI 选择目标
	:param targets: 可选目标列表
	:return: 选中的目标
	"""
	if targets.size() == 0:
		return null
	
	# 简单 AI：随机选择一个存活的目标
	var valid_targets = []
	for target in targets:
		if target is BaseCharacter and target.is_alive():
			valid_targets.append(target)
	
	if valid_targets.size() == 0:
		return null
	
	return valid_targets[randi() % valid_targets.size()]


func should_attack() -> bool:
	"""
	AI 决定是否攻击
	:return: true 如果应该攻击
	"""
	return is_alive() and current_ai_state == AIState.ATTACKING


func take_damage(damage: int) -> int:
	"""
	敌人承受伤害（重写父类方法，添加 AI 状态变更）
	:param damage: 伤害值
	:return: 实际受到的伤害
	"""
	var actual_damage = super.take_damage(damage)
	
	if current_hp <= 0:
		set_state("die")
		current_ai_state = AIState.DEAD
	else:
		# 受击后可能进入攻击状态
		if randf() < 0.5:
			current_ai_state = AIState.ATTACKING
	
	return actual_damage


func reset_to_idle():
	"""
	重置 AI 状态到空闲
	"""
	set_state("idle")
	current_ai_state = AIState.IDLE
	print("【EnemyCharacter】", name, " 重置到空闲状态")

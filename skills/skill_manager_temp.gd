extends Node

## 鎶€鑳界鐞嗗櫒
## 缁熶竴绠＄悊鎵€鏈夋妧鑳斤紝鎻愪緵缁熶竴鐨勬妧鑳借皟鐢ㄦ帴鍙?
# 宸叉敞鍐岀殑鎶€鑳藉瓧鍏?{skill_id: SkillBase}
var registered_skills: Dictionary = {}
# 鎶€鑳藉喎鍗村瓧鍏?{skill_id: cooldown_time}
var skill_cooldowns: Dictionary = {}
# 鎶€鑳?CSV 璇诲彇鍣?var skill_csv_reader: RefCounted


func _ready():
	# 鍒濆鍖栨妧鑳?CSV 璇诲彇鍣?	skill_csv_reader = preload("res://scripts/skill_csv_reader.gd").new()
	
	# 鑷姩娉ㄥ唽鎵€鏈夋妧鑳?	_auto_register_skills()
	
	print("SkillManager 鍒濆鍖栧畬鎴愶紝宸叉敞鍐?", registered_skills.size(), " 涓妧鑳?)


## 鑷姩娉ㄥ唽鎵€鏈夋妧鑳?func _auto_register_skills():
	# 浠?skill.json 璇诲彇鎵€鏈夋妧鑳介厤缃?	var all_skills = skill_csv_reader.get_all_skills()
	
	for skill_id in all_skills.keys():
		var skill_config = all_skills[skill_id]
		var skill_instance = _create_skill_instance(skill_id)
		
		if skill_instance:
			skill_instance.init(skill_config)
			register_skill(skill_id, skill_instance)
			print("鑷姩娉ㄥ唽鎶€鑳斤細", skill_id, " - ", skill_instance.get_skill_name())
		else:
			print("璀﹀憡锛氭棤娉曞垱寤烘妧鑳藉疄渚嬶細", skill_id)


## 鏍规嵁鎶€鑳?ID 鍒涘缓鎶€鑳藉疄渚?func _create_skill_instance(skill_id: String) -> RefCounted:
	match skill_id:
		"10001":
			return preload("res://skills/fireball_skill.gd").new()
		"10002":
			return preload("res://skills/blizzard_skill.gd").new()
		_:
			print("璀﹀憡锛氭湭鐭ユ妧鑳?ID: ", skill_id)
			return null


## 娉ㄥ唽鎶€鑳?## 鍙傛暟锛?##   skill_id: 鎶€鑳?ID
##   skill_instance: 鎶€鑳藉疄渚?func register_skill(skill_id: String, skill_instance: RefCounted) -> void:
	if skill_instance:
		registered_skills[skill_id] = skill_instance
		print("鎶€鑳藉凡娉ㄥ唽锛?, skill_id)


## 璋冪敤鎶€鑳?## 鍙傛暟锛?##   skill_id: 鎶€鑳?ID
##   caster: 鏂芥硶鑰呰妭鐐癸紙鍙€夛級
##   targets: 鐩爣鏁扮粍锛堝彲閫夛級
##   params: 棰濆鍙傛暟锛堝彲閫夛紝鍖呭惈楠板瓙缁撴灉绛夛級
## 杩斿洖锛氭槸鍚︽垚鍔熼噴鏀?func use_skill(skill_id: String, caster: Node = null, targets: Array = [], params: Dictionary = {}) -> bool:
	# 妫€鏌ユ妧鑳芥槸鍚﹀瓨鍦?	if not registered_skills.has(skill_id):
		print("閿欒锛氭妧鑳戒笉瀛樺湪 - ", skill_id)
		return false
	
	# 妫€鏌ュ喎鍗?	if not can_use_skill(skill_id):
		print("鎶€鑳芥鍦ㄥ喎鍗翠腑锛?, skill_id)
		return false
	
	# 鑾峰彇鎶€鑳藉疄渚?	var skill = registered_skills[skill_id]
	
	# 鎵ц鎶€鑳?	skill.execute(caster, targets, params)
	
	# 璁剧疆鍐峰嵈
	_set_cooldown(skill_id)
	
	return true


## 妫€鏌ユ妧鑳芥槸鍚﹀彲鐢?func can_use_skill(skill_id: String) -> bool:
	var cooldown = skill_cooldowns.get(skill_id, 0)
	return cooldown <= 0


## 璁剧疆鎶€鑳藉喎鍗?func _set_cooldown(skill_id: String) -> void:
	skill_cooldowns[skill_id] = 1.0  # 榛樿鍐峰嵈 1 绉?

## 鑾峰彇鎶€鑳介厤缃?func get_skill(skill_id: String) -> Dictionary:
	return skill_csv_reader.get_skill(skill_id)


## 鏇存柊鍐峰嵈
func _process(delta: float) -> void:
	for skill_id in skill_cooldowns.keys():
		skill_cooldowns[skill_id] = max(0, skill_cooldowns[skill_id] - delta)


## 娓呴櫎鎵€鏈夊喎鍗?func clear_cooldowns() -> void:
	skill_cooldowns.clear()
	print("鎶€鑳藉喎鍗村凡娓呴櫎")


## 鑾峰彇鎵€鏈夊凡娉ㄥ唽鐨勬妧鑳?ID
func get_all_skill_ids() -> Array:
	return registered_skills.keys()


## 鑾峰彇鎶€鑳芥暟閲?func get_skill_count() -> int:
	return registered_skills.size()


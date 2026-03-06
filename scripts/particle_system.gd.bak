class_name ParticleSystem

var particle_scenes = {
	"fireball": "res://particles/fireball_particles.tscn",
	"frost": "res://particles/frost_particles.tscn",
	"lightning": "res://particles/lightning_particles.tscn"
}

var active_particles = []

func spawn_particles(particle_type: String, position: Vector3, rotation: Quaternion = Quaternion()) -> CPUParticles3D:
	var scene_path = particle_scenes.get(particle_type)
	if not scene_path:
		return null
	
	var particle_scene = load(scene_path)
	if not particle_scene:
		return null
	
	var particles = particle_scene.instantiate()
	if particles:
		particles.global_position = position
		particles.global_rotation = rotation
		active_particles.append(particles)
		return particles
	
	return null

func spawn_skill_particles(skill_id: String, position: Vector3) -> CPUParticles3D:
	var particle_type = get_particle_type_by_skill(skill_id)
	if particle_type:
		return spawn_particles(particle_type, position)
	return null

func get_particle_type_by_skill(skill_id: String) -> String:
	var skill_to_particle = {
		"fireball": "fireball",
		"frost": "frost",
		"lightning": "lightning",
		"heal": "",
		"shield": "",
		"strength": ""
	}
	return skill_to_particle.get(skill_id, "")

func update(delta: float):
	# 清理已完成的粒子效果
	var to_remove = []
	for particle in active_particles:
		if not particle or not particle.is_visible_in_tree():
			to_remove.append(particle)
			if particle:
				particle.queue_free()
	
	for particle in to_remove:
		if particle in active_particles:
			active_particles.erase(particle)

func clear_all_particles():
	for particle in active_particles:
		if particle:
			particle.queue_free()
	active_particles.clear()

extends Node3D

@export var spawn_scenes: Array[PackedScene] = []
@export var target_object: CSGBox3D

@export var spawn_count: int = 5
@export var spawn_radius: float = 5.0
@export var spawn_interval: float = 2.0

var rng := RandomNumberGenerator.new()
var spawned_count: int = 0
var spawn_timer: Timer


func _ready() -> void:
	rng.randomize()

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(spawn_object)

	add_child.call_deferred(spawn_timer)
	start_spawning.call_deferred()


func start_spawning() -> void:
	if spawn_scenes.is_empty():
		push_warning("No spawn scenes assigned!")
		return

	if target_object == null:
		push_warning("No target CSGBox3D assigned!")
		return

	if spawn_count <= 0:
		return

	spawn_object()

	if spawned_count < spawn_count:
		spawn_timer.start()


func spawn_object() -> void:
	if spawned_count >= spawn_count:
		spawn_timer.stop()
		return

	var scene: PackedScene = spawn_scenes[
		rng.randi_range(0, spawn_scenes.size() - 1)
	]

	var creature = scene.instantiate()

	# Add the creature to the world
	get_tree().current_scene.add_child(creature)

	# Choose a random spawn position around the spawner
	var offset := Vector3(
		rng.randf_range(-spawn_radius, spawn_radius),
		0.0,
		rng.randf_range(-spawn_radius, spawn_radius)
	)

	creature.global_position = global_position + offset

	# Pass the CSG box to the creature
	if creature.has_method("set_wander_target"):
		creature.set_wander_target(target_object)
	else:
		push_warning("Spawned creature has no set_wander_target() function!")

	spawned_count += 1

	if spawned_count >= spawn_count:
		spawn_timer.stop()

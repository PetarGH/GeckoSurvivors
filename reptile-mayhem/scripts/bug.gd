extends CharacterBody3D
## A bug that wanders the terrarium until it reaches the bounds, then waits for
## the gecko to eat it. Clicking a bug plays its death animation instead.
##
## The [AnimationPlayer] holds the keyframed clips named in [member walk_animation],
## [member death_animation] and [member vanish_animation]. They all animate the
## [code]Visual[/code] node that carries the bug's mesh, so the same clips work for
## every bug scene.

@export var SPEED: float = 5.0
@export var wander_bounds: CSGBox3D
## How fast the bug swings around to face the way it walks.
@export var turn_speed_degrees: float = 540.0
## Extra yaw applied to the mesh, for bugs whose model does not face +Z.
@export var facing_offset_degrees: float = 0.0

@export_group("Animations")
@export var walk_animation: StringName = &"Walk"
@export var death_animation: StringName = &"Die"
@export var vanish_animation: StringName = &"Vanish"
## How long a dead bug lies still before it starts shrinking away.
@export var death_hold_time: float = 1.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var food_item: FoodItem = $FoodItem
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var rng := RandomNumberGenerator.new()
var has_target := false
var choosing_target := false
var has_reached_bounds := false
var is_dying := false


func _ready() -> void:
	rng.randomize()

	if animation_player != null:
		animation_player.animation_finished.connect(_on_animation_finished)


func set_wander_target(target: CSGBox3D) -> void:
	wander_bounds = target
	has_target = false
	choose_random_destination()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	_walk(delta)
	_update_walk_animation()


## Moves the bug towards its wander target, or stops it once it reached the
## terrarium bounds and is waiting for the gecko.
func _walk(delta: float) -> void:
	if is_dying or has_reached_bounds:
		# The bug bumped into the terrarium and waits for the gecko.
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if _is_inside_wander_bounds():
		_reach_terrarium_bounds()
		move_and_slide()
		return

	if wander_bounds == null or not has_target:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if nav_agent.is_navigation_finished():
		choose_random_destination()

		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var next_position := nav_agent.get_next_path_position()

	# Navigation can occasionally return a bad point; never apply a non-finite transform.
	if not next_position.is_finite() or not global_position.is_finite():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var direction := global_position.direction_to(next_position)
	direction.y = 0.0

	if direction.length_squared() < 0.0001 or not direction.is_finite():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	direction = direction.normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	_face_direction(direction, delta)
	move_and_slide()


## Turns the bug around so the mesh faces the way it is walking.
func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw: float = atan2(direction.x, direction.z) + deg_to_rad(facing_offset_degrees)
	rotation.y = rotate_toward(
		rotation.y,
		target_yaw,
		deg_to_rad(turn_speed_degrees) * delta
	)


## Runs the walk loop only while the bug is actually moving towards the
## terrarium bounds, and stops it once the bug stands still.
func _update_walk_animation() -> void:
	if is_dying or animation_player == null:
		return

	if not animation_player.has_animation(walk_animation):
		return

	var is_walking: bool = Vector2(velocity.x, velocity.z).length() > 0.1

	if is_walking:
		if animation_player.current_animation != walk_animation or not animation_player.is_playing():
			animation_player.play(walk_animation)
	elif animation_player.current_animation == walk_animation and animation_player.is_playing():
		animation_player.stop()


func choose_random_destination() -> void:
	if wander_bounds == null or choosing_target:
		return

	choosing_target = true
	has_target = false

	var map := nav_agent.get_navigation_map()

	# Wait for Godot to synchronize the navigation map.
	for i in range(10):
		await get_tree().physics_frame

		if NavigationServer3D.map_get_iteration_id(map) > 0:
			break

	if NavigationServer3D.map_get_iteration_id(map) == 0:
		choosing_target = false
		push_warning("Navigation map is still not ready.")
		return

	if not is_instance_valid(wander_bounds):
		choosing_target = false
		return

	# Choose a random point inside the CSGBox3D bounds.
	var size: Vector3 = wander_bounds.size

	var random_point := Vector3(
		rng.randf_range(-size.x / 2.0, size.x / 2.0),
		0.0,
		rng.randf_range(-size.z / 2.0, size.z / 2.0)
	)

	var world_point := wander_bounds.to_global(random_point)

	# Snap the point onto the walkable navigation mesh.
	var destination := NavigationServer3D.map_get_closest_point(
		map,
		world_point
	)

	nav_agent.target_position = destination

	# Give the navigation agent a physics frame to calculate its path.
	await get_tree().physics_frame

	has_target = true
	choosing_target = false

## Returns true while the bug is inside the bounds of the terrarium.
func _is_inside_wander_bounds() -> bool:
	if wander_bounds == null:
		return false

	var local_position: Vector3 = wander_bounds.to_local(global_position)
	var half_size: Vector3 = wander_bounds.size * 0.5

	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.z) <= half_size.z
	)


## Stops the bug at the terrarium bounds and lets the gecko know food is waiting.
func _reach_terrarium_bounds() -> void:
	has_reached_bounds = true
	velocity = Vector3.ZERO

	if food_item != null:
		food_item.notify_hit_terrarium_bounds()


## Kills the bug: it plays its death animation, lies still for a moment and then
## shrinks down to nothing before it despawns.
func die() -> void:
	if is_dying:
		return

	is_dying = true
	has_reached_bounds = true
	velocity = Vector3.ZERO

	if animation_player != null:
		animation_player.stop()

	# Keep the gecko from hunting a bug that is already dying.
	if food_item != null:
		food_item.mark_consumed()

	_play_death()


func _play_death() -> void:
	if animation_player == null or not animation_player.has_animation(death_animation):
		queue_free()
		return

	animation_player.play(death_animation)
	await animation_player.animation_finished

	await get_tree().create_timer(death_hold_time).timeout

	if not is_inside_tree():
		return

	if not animation_player.has_animation(vanish_animation):
		queue_free()
		return

	animation_player.play(vanish_animation)


func _on_animation_finished(finished_animation: StringName) -> void:
	if finished_animation == vanish_animation:
		queue_free()


func _on_food_item_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			die()

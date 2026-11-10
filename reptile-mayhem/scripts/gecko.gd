
class_name Gecko
extends CharacterBody3D
## Represents a gecko inhabitant within a Terrarium.

## Animation clips stored in the gecko's [AnimationPlayer].
const ANIMATION_IDLE: StringName = &"gekko_idle"
const ANIMATION_WALK: StringName = &"gekko_walk"
const ANIMATION_BITE: StringName = &"gekko_bite"
const ANIMATION_DIE: StringName = &"gekko_die"

signal health_depleted()
signal health_changed(new_health: float)
signal points_changed(new_points: int)
signal good_food_eaten
signal bad_food_eaten
## Emitted once the death clip has had time to play, so the lose screen can wait
## for it instead of cutting the animation off.
signal death_animation_finished
var has_died: bool = false

@export var SPEED: float = 5.0
@export var wander_bounds: CSGBox3D
@export var roam_delay: float = 2.0
@export var points_per_correct_food: int = 10
@export var turn_speed_degrees: float =	 180.0
@export var eat_area: Area3D
@export var eat_distance: float = 1.5
@export_range(1.0, 10.0, 0.1) var hunt_speed_multiplier: float = 3.0

@export_group("Animation")
## How long the death clip is given before the run ends. Longer clips play in
## full; short or missing clips still take at least this long.
@export_range(0.0, 5.0, 0.1) var death_animation_time: float = 1.0

@export var species_data: GeckoSpeciesData:
	set(value):
		species_data = value
		if is_node_ready() and species_data != null:
			current_health = clampf(
				current_health, 0.0, species_data.max_health
			)

@export_group("Points Feedback")
@export var floating_feedback_scene: PackedScene
@export var feedback_height: float = 0.3

@onready var nav_agent: NavigationAgent3D = _find_navigation_agent(self)
@onready var animation_player: AnimationPlayer = $M_gekko_player/AnimationPlayer


func _find_navigation_agent(node: Node) -> NavigationAgent3D:
	for child in node.get_children():
		if child is NavigationAgent3D:
			return child as NavigationAgent3D

		var found: NavigationAgent3D = _find_navigation_agent(child)

		if found != null:
			return found

	return null

var current_health: float = 0.0
var current_points: int = 0

var rng := RandomNumberGenerator.new()
var has_target: bool = false
var choosing_target: bool = false
var is_waiting_to_roam: bool = false

var hunt_target: FoodItem = null
var waiting_food: Array[FoodItem] = []

# True while the one-shot bite clip is still playing.
var _is_biting: bool = false
var _death_animation_finished: bool = false

var environmental_damage_timer: float = 0.0
var environmental_damage_accumulated: float = 0.0


func _ready() -> void:
	add_to_group(&"gecko")
	rng.randomize()

	_setup_animations()

	if species_data != null:
		current_health = species_data.max_health

	health_changed.emit(current_health)
	points_changed.emit(current_points)
	health_depleted.connect(_on_health_depleted)
	eat_area.area_entered.connect(_on_eat_area_entered)
	if wander_bounds != null:
		await get_tree().create_timer(maxf(roam_delay, 0.0)).timeout

		if not is_inside_tree():
			return
		
	choose_random_destination()

func _on_health_depleted() -> void:
	if has_died:
		return

	has_died = true

	# Stop the gecko from moving.
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process(false)

	_play_death_animation()


## Keeps idle and walk looping and bite and die one-shot, so the clips behave
## the same however they were imported, and starts out idle.
func _setup_animations() -> void:
	if animation_player == null:
		return

	_set_clip_loop(ANIMATION_IDLE, Animation.LOOP_LINEAR)
	_set_clip_loop(ANIMATION_WALK, Animation.LOOP_LINEAR)
	_set_clip_loop(ANIMATION_BITE, Animation.LOOP_NONE)
	_set_clip_loop(ANIMATION_DIE, Animation.LOOP_NONE)

	animation_player.animation_finished.connect(_on_animation_finished)
	_play_animation(ANIMATION_IDLE)


func _set_clip_loop(animation_name: StringName, loop_mode: Animation.LoopMode) -> void:
	if not animation_player.has_animation(animation_name):
		return

	animation_player.get_animation(animation_name).loop_mode = loop_mode


## Plays [param animation_name] unless it is already the clip that is running.
func _play_animation(animation_name: StringName) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return

	if animation_player.current_animation == animation_name:
		return

	animation_player.play(animation_name)


## Shows the idle clip when the gecko stands still and the walk clip while it
## moves. Biting and dying keep their own clip.
func _update_movement_animation() -> void:
	if not is_alive() or _is_biting:
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()

	_play_animation(ANIMATION_WALK if horizontal_speed > 0.1 else ANIMATION_IDLE)


## Bites down on a bug. The gecko keeps the bite clip until it has finished.
func _play_bite_animation() -> void:
	if animation_player == null or not animation_player.has_animation(ANIMATION_BITE):
		return

	_is_biting = true
	animation_player.play(ANIMATION_BITE)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == ANIMATION_BITE:
		_is_biting = false


## Plays the death clip and waits for it (or for [member death_animation_time]
## when the clip is shorter) before letting the run end.
func _play_death_animation() -> void:
	var wait_time: float = death_animation_time

	if animation_player != null and animation_player.has_animation(ANIMATION_DIE):
		animation_player.play(ANIMATION_DIE)
		wait_time = maxf(
			death_animation_time,
			animation_player.get_animation(ANIMATION_DIE).length
		)

	await get_tree().create_timer(wait_time).timeout

	_death_animation_finished = true
	death_animation_finished.emit()


## Waits for the death clip to finish, so the lose screen can let it play out.
func wait_for_death_animation() -> void:
	if _death_animation_finished or not has_died:
		return

	await death_animation_finished


## Assign or change the gecko's roaming bounds.
func set_wander_target(target: CSGBox3D) -> void:
	wander_bounds = target
	has_target = false

	if wander_bounds != null:
		choose_random_destination()

func _on_eat_area_entered(area: Area3D) -> void:
	if area is not FoodItem:
		return

	var food := area as FoodItem

	if not is_alive() or not _is_valid_food(food):
		return

	# The bug the gecko was sent to may have been clicked away meanwhile.
	_prune_hunt_state()

	# Only the bug the gecko was sent to is eaten, not every bug it walks past.
	if food != hunt_target:
		return

	_eat_hunted_food()


## Sends the gecko to the closest bug that reached the bounds of the terrarium.
func hunt(food: FoodItem) -> void:
	_prune_hunt_state()

	if not is_alive() or not _is_valid_food(food):
		return

	if food == hunt_target or food in waiting_food:
		return

	waiting_food.append(food)

	# Keep walking to the bug the gecko is already hunting.
	if hunt_target == null:
		_start_nearest_hunt()


## Picks the closest bug waiting at the terrarium bounds and walks to it.
func _start_nearest_hunt() -> void:
	_prune_hunt_state()
	hunt_target = null

	var closest_distance: float = INF

	for food: FoodItem in waiting_food:
		var distance: float = _horizontal_distance_to(food.global_position)

		if distance < closest_distance:
			closest_distance = distance
			hunt_target = food

	if hunt_target == null:
		return

	waiting_food.erase(hunt_target)

	if nav_agent != null:
		nav_agent.target_position = hunt_target.global_position


## Walks the gecko to the bug it was sent to and eats it.
## Returns true while the gecko is busy hunting.
func _process_hunt(delta: float) -> bool:
	_prune_hunt_state()

	if hunt_target == null:
		_start_nearest_hunt()

	if hunt_target == null:
		return false

	# Eat the bug once the gecko has reached it.
	if _horizontal_distance_to(hunt_target.global_position) <= eat_distance:
		_eat_hunted_food()
		return true

	# Roaming may have pointed the agent somewhere else meanwhile, so put the
	# bug back as the destination without resetting the path every frame.
	var target_offset: Vector3 = nav_agent.target_position - hunt_target.global_position
	target_offset.y = 0.0

	if target_offset.length() > 0.1:
		nav_agent.target_position = hunt_target.global_position

	_move_towards(
		nav_agent.get_next_path_position(),
		delta,
		SPEED * hunt_speed_multiplier
	)

	return true


## Forgets bugs that were eaten or clicked away before the gecko reached them.
func _prune_hunt_state() -> void:
	if hunt_target != null and not _is_valid_food(hunt_target):
		hunt_target = null

	for index in range(waiting_food.size() - 1, -1, -1):
		if not _is_valid_food(waiting_food[index]):
			waiting_food.remove_at(index)


## Bugs can be removed from the scene at any time, so the argument stays untyped:
## a typed [FoodItem] parameter rejects an already freed instance before the check.
func _is_valid_food(food) -> bool:
	return (
		food != null
		and is_instance_valid(food)
		and not (food as FoodItem).is_consumed()
	)


func _horizontal_distance_to(target_position: Vector3) -> float:
	var offset: Vector3 = target_position - global_position
	offset.y = 0.0

	return offset.length()


func _eat_hunted_food() -> void:
	if not _is_valid_food(hunt_target):
		hunt_target = null
		return

	var food: FoodItem = hunt_target
	hunt_target = null

	food.notify_reached_gecko()
	feed(food)

func _physics_process(delta: float) -> void:
	_update_movement_animation()

	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if nav_agent == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	

	# A bug that reached the terrarium bounds is eaten before anything else.
	if _process_hunt(delta):
		return

	if wander_bounds == null or not has_target:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Stop when the current destination has been reached.
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()

		if not is_waiting_to_roam:
			_wait_and_roam()

		return

	# Move toward the next point on the navigation path.
	_move_towards(nav_agent.get_next_path_position(), delta, SPEED)


## Turns the gecko towards [param target_position] and walks there at [param speed].
func _move_towards(target_position: Vector3, delta: float, speed: float) -> void:
	# Navigation can occasionally return a bad point; never apply a non-finite transform.
	if not target_position.is_finite() or not global_position.is_finite():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var direction: Vector3 = global_position.direction_to(target_position)
	direction.y = 0.0

	if not direction.is_finite() or direction.length_squared() < 0.0001:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	direction = direction.normalized()
	var target_yaw: float = atan2(direction.x, direction.z)
	global_rotation.y = rotate_toward(
		global_rotation.y,
		target_yaw,
		deg_to_rad(turn_speed_degrees) * delta
	)

	# Check whether the gecko is facing the destination closely enough.
	var angle_remaining: float = absf(
		wrapf(target_yaw - global_rotation.y, -PI, PI)
	)

	if angle_remaining > deg_to_rad(3.0):
		# Keep turning in place until the gecko is facing its destination.
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()


## Wait before choosing the next roaming destination.
func _wait_and_roam() -> void:
	is_waiting_to_roam = true

	await get_tree().create_timer(maxf(roam_delay, 0.0)).timeout

	if not is_inside_tree():
		return

	is_waiting_to_roam = false

	if wander_bounds != null:
		has_target = false
		choose_random_destination()


## Select a random destination inside the roaming bounds.
func choose_random_destination() -> void:
	if nav_agent == null:
		push_warning("Gecko: NavigationAgent3D was not found!")
		return

	if wander_bounds == null or choosing_target:
		return

	choosing_target = true
	has_target = false

	var map: RID = nav_agent.get_navigation_map()

	# Wait for Godot to synchronize the navigation map.
	for i in range(10):
		await get_tree().physics_frame

		if NavigationServer3D.map_get_iteration_id(map) > 0:
			break

	if not is_inside_tree():
		return

	if NavigationServer3D.map_get_iteration_id(map) == 0:
		choosing_target = false
		push_warning("Gecko navigation map is not ready.")
		return

	if not is_instance_valid(wander_bounds):
		choosing_target = false
		return

	# Pick a random position within the bounds.
	var size: Vector3 = wander_bounds.size

	var random_point := Vector3(
		rng.randf_range(-size.x / 2.0, size.x / 2.0),
		0.0,
		rng.randf_range(-size.z / 2.0, size.z / 2.0)
	)

	var world_point: Vector3 = wander_bounds.to_global(random_point)

	# Snap the position to a walkable point on the navigation mesh.
	var destination: Vector3 = NavigationServer3D.map_get_closest_point(
		map,
		world_point
	)

	nav_agent.target_position = destination

	# Allow the navigation agent to calculate the path.
	await get_tree().physics_frame

	if not is_inside_tree():
		return

	has_target = true
	choosing_target = false


## Feed the gecko a food item.

func feed(food: FoodItem) -> void:
	if food == null or food.is_consumed() or not is_alive():
		return

	if species_data == null:
		push_warning("Gecko has no species data assigned.")
		food.consume()
		return

	# Remember where the bug was before it gets removed.
	var bug_position: Vector3 = food.global_position

	_play_bite_animation()

	if species_data.is_food_accepted(food.food_type):
		# CORRECT FOOD
		good_food_eaten.emit()
		var reward: int = points_per_correct_food

		current_points += reward
		points_changed.emit(current_points)

		# Display green +points.
		spawn_floating_feedback(
			bug_position,
			"+%d" % reward,
			Color("#42E879"),
			false
		)

		print("Correct food! +", reward, " points.")

	else:
		# INCORRECT FOOD
		bad_food_eaten.emit()
		var damage: float = species_data.incorrect_food_damage

		take_damage(damage)

		# Display red -health with HP icon.
		spawn_floating_feedback(
			bug_position,
			"-%.0f" % damage,
			Color("#F05B62"),
			true
		)

		print("Incorrect food! Gecko lost ", damage, " health.")

	# Consume the bug after spawning the feedback.
	food.consume()



func process_environment(damage_rate: float, delta: float) -> void:
	if species_data == null or not is_alive():
		return

	if damage_rate <= 0.0:
		return

	# Calculate actual damage per second.
	var actual_damage_rate: float = (
		damage_rate * species_data.env_damage_rate
	)

	var damage: float = actual_damage_rate * delta

	# Remember how much damage is actually applied.
	var health_before: float = current_health

	take_damage(damage)

	var actual_damage: float = minf(damage, health_before)

	environmental_damage_accumulated += actual_damage
	environmental_damage_timer += delta

	# Print once per second, or immediately when the gecko dies.
	if environmental_damage_timer >= 1.0 or not is_alive():

		var average_damage_rate: float = (
			environmental_damage_accumulated
			/ environmental_damage_timer
		)

		print(
			"ENVIRONMENTAL DAMAGE: ",
			"Lost %.2f HP | " % environmental_damage_accumulated,
			"Rate: %.2f HP/s | " % average_damage_rate,
			"Remaining HP: %.2f" % current_health
		)

		# Reset the log counters.
		environmental_damage_timer = 0.0
		environmental_damage_accumulated = 0.0

func is_alive() -> bool:
	return current_health > 0.0


func can_accept_food(food: FoodItem) -> bool:
	if food == null or not is_alive() or species_data == null:
		return false

	return species_data.is_food_accepted(food.food_type)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return

	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health)

	if current_health <= 0.0:
		health_depleted.emit()


func _take_damage(amount: float) -> void:
	take_damage(amount)

func spawn_floating_feedback(
	world_position: Vector3,
	message: String,
	text_color: Color,
	show_hp_icon: bool = false
) -> void:
	if floating_feedback_scene == null:
		push_warning("Floating feedback scene is not assigned.")
		return

	var feedback := floating_feedback_scene.instantiate() as FloatingFeedback

	if feedback == null:
		push_warning("Could not instantiate FloatingFeedback.")
		return

	# Add it to the level, NOT to the gecko.
	var scene_root := get_tree().current_scene

	if scene_root == null:
		feedback.queue_free()
		return

	scene_root.add_child(feedback)

	# Place it at the bug's original world position.
	feedback.global_position = world_position + Vector3.UP * feedback_height

	# Start its animation.
	feedback.play(message, text_color, show_hp_icon)

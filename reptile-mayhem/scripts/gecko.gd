
class_name Gecko
extends CharacterBody3D
## Represents a gecko inhabitant within a Terrarium.

signal health_depleted()
signal health_changed(new_health: float)
signal points_changed(new_points: int)
var has_died: bool = false

@export var SPEED: float = 5.0
@export var wander_bounds: CSGBox3D
@export var roam_delay: float = 2.0
@export var points_per_correct_food: int = 10
@export var turn_speed_degrees: float =	 180.0
@export var eat_area: Area3D

@export var species_data: GeckoSpeciesData:
	set(value):
		species_data = value
		if is_node_ready() and species_data != null:
			current_health = clampf(
				current_health, 0.0, species_data.max_health
			)

@onready var nav_agent: NavigationAgent3D = _find_navigation_agent(self)

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


func _ready() -> void:
	rng.randomize()

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
	
## Assign or change the gecko's roaming bounds.
func set_wander_target(target: CSGBox3D) -> void:
	wander_bounds = target
	has_target = false

	if wander_bounds != null:
		choose_random_destination()

func _on_eat_area_entered(area: Area3D) -> void:
	if area is FoodItem:
		var food := area as FoodItem

		if food.is_consumed() or not is_alive():
			return

		food.notify_reached_gecko()
		feed(food)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if nav_agent == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
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
	var next_position: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = global_position.direction_to(next_position)

	direction.y = 0.0
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

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

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

	if species_data.is_food_accepted(food.food_type):
		current_points += points_per_correct_food
		points_changed.emit(current_points)

		print(
			"Correct food! +",
			points_per_correct_food,
			" points. Total: ",
			current_points
		)
	else:
		take_damage(species_data.incorrect_food_damage)

		print(
			"Incorrect food! Gecko lost ",
			species_data.incorrect_food_damage,
			" health."
		)

	food.consume()


func process_environment(
	current_temp: float,
	current_humidity: float,
	delta: float
) -> void:
	if species_data == null or not is_alive():
		return

	var temp_out_of_range: bool = not species_data.is_temperature_ideal(
		current_temp
	)
	var humidity_out_of_range: bool = not species_data.is_humidity_ideal(
		current_humidity
	)

	if temp_out_of_range or humidity_out_of_range:
		take_damage(species_data.env_damage_rate * delta)


func evaluate_prop_multiplier(prop: Prop) -> float:
	if prop == null or species_data == null:
		return 0.0

	if prop.biome == species_data.preferred_biome:
		return prop.score_multiplier_delta

	return 0.0


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

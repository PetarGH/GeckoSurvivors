
class_name Terrarium
extends Node3D
## Root controller for a gecko habitat simulation.

const BASE_SCORE_MULTIPLIER: float = 1.0

signal time_elapsed(delta: float)
signal bad_temperature_time(delta: float)
signal bad_moisture_time(delta: float)

@export_group("Environment")
@export var gecko: Gecko
@export var environment: EnvironmentManager

@export_group("Habitat")
@export var active_props: Array[Prop] = []
@export var score: int = 0
@export var currency: int = 0


func _ready() -> void:
	if gecko == null:
		gecko = get_node_or_null("Gecko") as Gecko

	if environment == null:
		environment = get_node_or_null("EnvironmentManager") as EnvironmentManager

	# Initialize temperature and humidity from the gecko's species.
	if environment != null:
		environment.initialize_for_gecko(gecko)
	else:
		push_warning("Terrarium: EnvironmentManager not found!")

	# Preserve existing food and prop registration.
	child_entered_tree.connect(_on_child_entered_tree)
	_hook_run_stats()

	for child: Node in get_children():
		_register_child(child)


## Adds a prop and deducts its cost if affordable.
func add_prop(prop: Prop) -> void:
	if prop == null or prop in active_props:
		return

	if prop.cost > 0:
		if currency < prop.cost:
			return

		currency -= prop.cost

	_track_prop(prop)

	if prop.get_parent() == null:
		add_child(prop)


## Calculates the combined score multiplier.
func get_total_score_multiplier() -> float:
	if gecko == null:
		return BASE_SCORE_MULTIPLIER

	var total_multiplier: float = BASE_SCORE_MULTIPLIER

	for prop: Prop in active_props:
		if prop == null:
			continue

		total_multiplier += gecko.evaluate_prop_multiplier(prop)

	return maxf(total_multiplier, 0.0)


## Handles food reaching the gecko.
func _on_food_reached_gecko(food: FoodItem) -> void:
	if food == null or food.is_consumed() or gecko == null or not gecko.is_alive():
		return

	if gecko.can_accept_food(food):
		currency += FoodItem.CURRENCY_VALUE
		score += roundi(
			float(FoodItem.CURRENCY_VALUE) * get_total_score_multiplier()
		)

	gecko.feed(food)


func _on_child_entered_tree(node: Node) -> void:
	_register_child(node)


func _register_child(node: Node) -> void:
	if node is FoodItem:
		var food_item := node as FoodItem

		if not food_item.reached_gecko.is_connected(_on_food_reached_gecko):
			food_item.reached_gecko.connect(_on_food_reached_gecko)

	elif node is Prop:
		_track_prop(node as Prop)


func _track_prop(prop: Prop) -> void:
	if prop == null:
		return

	if not (prop in active_props):
		active_props.append(prop)

	var cleanup_callable: Callable = _on_prop_tree_exited.bind(prop)

	if not prop.tree_exited.is_connected(cleanup_callable):
		prop.tree_exited.connect(cleanup_callable)

func _process(delta: float) -> void:
	if gecko == null or environment == null:
		return

	if not gecko.is_alive():
		return

	time_elapsed.emit(delta)

	if environment.get_temperature_severity() > 0:
		bad_temperature_time.emit(delta)

	if environment.get_humidity_severity() > 0:
		bad_moisture_time.emit(delta)

	# Calculate damage based on temperature and humidity severity.
	var damage_rate: float = environment.get_environment_damage_rate()

	# Apply the calculated damage to the gecko.
	gecko.process_environment(damage_rate, delta)

func _on_prop_tree_exited(prop: Prop) -> void:
	active_props.erase(prop)


## Clears the previous run and connects this habitat's signals to the stat registry.
func _hook_run_stats() -> void:
	RunStats.reset()

	if gecko != null:
		RunStats.hook_count(gecko.good_food_eaten, &"good_food")
		RunStats.hook_count(gecko.bad_food_eaten, &"bad_food")

	RunStats.hook_amount(time_elapsed, &"total_time")
	RunStats.hook_amount(bad_temperature_time, &"bad_temp_time")
	RunStats.hook_amount(bad_moisture_time, &"bad_moisture_time")

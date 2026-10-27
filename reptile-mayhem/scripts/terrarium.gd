class_name Terrarium
extends Node3D
## Root controller for a gecko habitat simulation, managing the [Gecko],
## [EnvironmentManager], active [Prop] instances, and [FoodItem] routing.

const BASE_SCORE_MULTIPLIER: float = 1.0

@export var gecko: Gecko
@export var environment: EnvironmentManager
@export var active_props: Array[Prop] = []
@export var score: int = 0
@export var currency: int = 0


func _ready() -> void:
	if gecko == null:
		gecko = get_node_or_null("Gecko") as Gecko
	if environment == null:
		environment = get_node_or_null("EnvironmentManager") as EnvironmentManager

	child_entered_tree.connect(_on_child_entered_tree)
	for child: Node in get_children():
		_register_child(child)


func _process(delta: float) -> void:
	if gecko != null and environment != null:
		gecko.process_environment(environment.current_temp, environment.current_humidity, delta)


## Adds [param prop] to [member active_props], deducts its cost from [member currency]
## if available, and parents it to this [Terrarium] if not already in the scene tree.
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


## Calculates the combined score multiplier across all [member active_props]
## evaluated against the [member gecko]'s biome preference.
func get_total_score_multiplier() -> float:
	if gecko == null:
		return BASE_SCORE_MULTIPLIER

	var total_multiplier: float = BASE_SCORE_MULTIPLIER
	for prop: Prop in active_props:
		if prop == null:
			continue
		total_multiplier += gecko.evaluate_prop_multiplier(prop)

	return maxf(total_multiplier, 0.0)


## Callback invoked when a [FoodItem] reaches the [member gecko].
func _on_food_reached_gecko(food: FoodItem) -> void:
	if food == null or food.is_consumed() or gecko == null or not gecko.is_alive():
		return

	if gecko.can_accept_food(food):
		currency += FoodItem.CURRENCY_VALUE
		score += roundi(float(FoodItem.CURRENCY_VALUE) * get_total_score_multiplier())

	gecko.feed(food)


func _on_child_entered_tree(node: Node) -> void:
	_register_child(node)


func _register_child(node: Node) -> void:
	if node is FoodItem:
		var food_item: FoodItem = node as FoodItem
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


func _on_prop_tree_exited(prop: Prop) -> void:
	active_props.erase(prop)

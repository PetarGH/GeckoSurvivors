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
		currency = maxi(currency - prop.cost, 0)

	active_props.append(prop)
	if prop.get_parent() == null:
		add_child(prop)


## Calculates the combined score multiplier across all [member active_props]
## evaluated against the [member gecko]'s biome preference.
func get_total_score_multiplier() -> float:
	var total_multiplier: float = BASE_SCORE_MULTIPLIER
	for prop: Prop in active_props:
		if prop == null:
			continue
		if gecko != null:
			total_multiplier += gecko.evaluate_prop_multiplier(prop)
		else:
			total_multiplier += prop.score_multiplier_delta

	return maxf(total_multiplier, 0.0)


## Callback invoked when a [FoodItem] reaches the [member gecko].
func _on_food_reached_gecko(food: FoodItem) -> void:
	if food == null or gecko == null:
		return

	var is_valid_food: bool = (
		gecko.species_data == null
		or gecko.species_data.is_food_accepted(food.food_type)
	)
	if is_valid_food:
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

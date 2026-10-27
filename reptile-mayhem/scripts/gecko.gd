class_name Gecko
extends Node3D
## Represents a gecko inhabitant within a [Terrarium] driven by [GeckoSpeciesData].

signal health_depleted()
signal health_changed(new_health: float)

@export var species_data: GeckoSpeciesData

var current_health: float = 100.0


func _ready() -> void:
	if species_data != null:
		current_health = species_data.max_health
	health_changed.emit(current_health)


func _process(_delta: float) -> void:
	pass


## Evaluates environmental conditions and applies damage if temperature or humidity
## falls outside the species' ideal ranges.
func process_environment(current_temp: float, current_humidity: float, delta: float) -> void:
	if species_data == null or current_health <= 0.0:
		return

	var temp_out_of_range: bool = not species_data.is_temperature_ideal(current_temp)
	var humidity_out_of_range: bool = not species_data.is_humidity_ideal(current_humidity)

	if temp_out_of_range or humidity_out_of_range:
		take_damage(species_data.env_damage_rate * delta)


## Feeds the gecko a [FoodItem], applying damage if the food type is not accepted by its species,
## and consumes the food item.
func feed(food: FoodItem) -> void:
	if food == null:
		return

	if species_data != null and not species_data.is_food_accepted(food.food_type):
		take_damage(species_data.incorrect_food_damage)

	food.consume()


## Evaluates the score multiplier contribution of [param prop] based on the gecko's preferred biome.
func evaluate_prop_multiplier(prop: Prop) -> float:
	if prop == null or species_data == null:
		return 0.0

	if prop.biome == species_data.preferred_biome:
		return prop.score_multiplier_delta

	return 0.0


## Reduces [member current_health] by [param amount] and emits [signal health_changed]
## and [signal health_depleted] when health reaches zero.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return

	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health)

	if is_zero_approx(current_health):
		health_depleted.emit()


func _take_damage(amount: float) -> void:
	take_damage(amount)

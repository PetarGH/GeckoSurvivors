class_name GeckoSpeciesData
extends Resource
## Resource defining the biological parameters and habitat preferences for a gecko species.

@export var species_name: String = ""
@export var ideal_temp_range: Vector2 = Vector2(24.0, 30.0)
@export var ideal_humidity_range: Vector2 = Vector2(40.0, 60.0)
@export var env_damage_rate: float = 1.0
@export var accepted_food_types: Array[HabitatEnums.FoodType] = [HabitatEnums.FoodType.SUPERWORM, HabitatEnums.FoodType.ROACH, HabitatEnums.FoodType.CRICKET]
@export var preferred_biome: HabitatEnums.BiomeType = HabitatEnums.BiomeType.MEDITERRANEAN
@export var max_health: float = 100.0
@export var incorrect_food_damage: float = 10.0


## Returns true if the given temperature falls within [member ideal_temp_range].
func is_temperature_ideal(temp: float) -> bool:
	var min_temp: float = minf(ideal_temp_range.x, ideal_temp_range.y)
	var max_temp: float = maxf(ideal_temp_range.x, ideal_temp_range.y)
	return temp >= min_temp and temp <= max_temp


## Returns true if the given humidity falls within [member ideal_humidity_range].
func is_humidity_ideal(humidity: float) -> bool:
	var min_humidity: float = minf(ideal_humidity_range.x, ideal_humidity_range.y)
	var max_humidity: float = maxf(ideal_humidity_range.x, ideal_humidity_range.y)
	return humidity >= min_humidity and humidity <= max_humidity


## Returns true if the species can safely consume the given [param food_type].
func is_food_accepted(food_type: HabitatEnums.FoodType) -> bool:
	return food_type in accepted_food_types

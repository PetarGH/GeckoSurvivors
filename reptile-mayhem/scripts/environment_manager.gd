class_name EnvironmentManager
extends Node
## Manages temperature and humidity simulation within a [Terrarium].

signal environment_updated(temp: float, humidity: float)

const MIN_HUMIDITY: float = 0.0
const MAX_HUMIDITY: float = 100.0
const MIN_TEMP: float = 0.0
const MAX_TEMP: float = 100.0

@export var current_temp: float = 26.0
@export_range(0.0, 100.0, 0.1) var current_humidity: float = 50.0

@export_group("Simulation Rates")
@export var ambient_temp: float = 20.0
@export var temp_cooling_rate: float = 0.5
@export var heat_increase_rate: float = 5.0
@export var humidity_decay_rate: float = 1.0
@export var water_spray_humidity_boost: float = 15.0


func _process(delta: float) -> void:
	current_temp = clampf(
		move_toward(current_temp, ambient_temp, temp_cooling_rate * delta),
		MIN_TEMP,
		MAX_TEMP
	)
	current_humidity = clampf(
		current_humidity - humidity_decay_rate * delta,
		MIN_HUMIDITY,
		MAX_HUMIDITY
	)
	environment_updated.emit(current_temp, current_humidity)


## Applies heat over [param delta] seconds, raising [member current_temp].
func apply_heat(delta: float) -> void:
	if delta <= 0.0:
		return
	current_temp = clampf(current_temp + heat_increase_rate * delta, MIN_TEMP, MAX_TEMP)
	environment_updated.emit(current_temp, current_humidity)


## Sprays water into the habitat, boosting [member current_humidity].
func spray_water() -> void:
	current_humidity = clampf(
		current_humidity + water_spray_humidity_boost,
		MIN_HUMIDITY,
		MAX_HUMIDITY
	)
	environment_updated.emit(current_temp, current_humidity)

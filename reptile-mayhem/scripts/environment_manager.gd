
class_name EnvironmentManager
extends Node
## Manages temperature and humidity inside the terrarium.

signal environment_updated(temp: float, humidity: float)

const MIN_HUMIDITY: float = 0.0
const MAX_HUMIDITY: float = 100.0
const MIN_TEMP: float = 0.0
const MAX_TEMP: float = 50.0

# Environmental status colors.
const COLOR_TOO_COLD: Color = Color("#2455A6")
const COLOR_SLIGHTLY_COLD: Color = Color("#75C8F0")
const COLOR_IDEAL: Color = Color("#FFFFFF")
const COLOR_SLIGHTLY_WARM: Color = Color("#F2CE4B")
const COLOR_TOO_WARM: Color = Color("#F28C38")


@export_group("Fallback Ranges")
@export var fallback_temp_range: Vector2 = Vector2(24.0, 30.0)
@export var fallback_humidity_range: Vector2 = Vector2(40.0, 60.0)


@export_group("Simulation Rates")
@export_range(0.1, 10.0, 0.1) var decay_interval: float = 1.0
@export_range(0.0, 1.0, 0.01) var temp_decay_min: float = 0.05
@export_range(0.0, 1.0, 0.01) var temp_decay_max: float = 0.15
## Degrees per second the terrarium heats up by. When above 0 the temperature
## climbs instead of decaying, which is what level 3 uses for its heat wave.
@export_range(0.0, 5.0, 0.05) var temp_rise_rate: float = 0.0
@export_range(0.0, 1.0, 0.01) var humidity_decay_min: float = 0.05
@export_range(0.0, 1.0, 0.01) var humidity_decay_max: float = 0.15


@export_group("Color Thresholds")
@export_range(0.1, 10.0, 0.1) var temp_warning_margin: float = 2.0
@export_range(0.1, 20.0, 0.1) var humidity_warning_margin: float = 5.0


@export_group("Equipment Settings")
@export var heat_increase_rate: float = 5.0
@export var water_spray_humidity_boost: float = 15.0


var current_temp: float = 26.0
var current_humidity: float = 50.0

# The ideal ranges are initialized using the gecko's species data.
var ideal_temp_range: Vector2 = Vector2(24.0, 30.0)
var ideal_humidity_range: Vector2 = Vector2(40.0, 60.0)

var rng := RandomNumberGenerator.new()
var decay_timer: float = 0.0


func _ready() -> void:
	rng.randomize()

	# Initialize fallback values until the Terrarium supplies its gecko.
	current_temp = _get_range_middle(fallback_temp_range)
	current_humidity = _get_range_middle(fallback_humidity_range)


## Initializes the environment using the gecko's species preferences.
func initialize_for_gecko(target_gecko: Gecko) -> void:
	if target_gecko != null and target_gecko.species_data != null:
		ideal_temp_range = _normalise_range(
			target_gecko.species_data.ideal_temp_range
		)

		ideal_humidity_range = _normalise_range(
			target_gecko.species_data.ideal_humidity_range
		)
	else:
		ideal_temp_range = _normalise_range(fallback_temp_range)
		ideal_humidity_range = _normalise_range(fallback_humidity_range)

	# Start exactly in the middle of both ideal ranges.
	current_temp = _get_range_middle(ideal_temp_range)
	current_humidity = _get_range_middle(ideal_humidity_range)

	environment_updated.emit(current_temp, current_humidity)


func _process(delta: float) -> void:
	if decay_interval <= 0.0:
		return

	decay_timer += delta

	# Apply decay once for every elapsed second.
	while decay_timer >= decay_interval:
		decay_timer -= decay_interval
		_apply_random_decay()


## Randomly decreases humidity and either decreases the temperature or, when
## [member temp_rise_rate] is above 0, raises it like a heat wave would.
func _apply_random_decay() -> void:
	var humidity_loss: float = rng.randf_range(
		minf(humidity_decay_min, humidity_decay_max),
		maxf(humidity_decay_min, humidity_decay_max)
	)

	if temp_rise_rate > 0.0:
		current_temp = clampf(
			current_temp + temp_rise_rate * decay_interval,
			MIN_TEMP,
			MAX_TEMP
		)
	else:
		var temp_loss: float = rng.randf_range(
			minf(temp_decay_min, temp_decay_max),
			maxf(temp_decay_min, temp_decay_max)
		)

		current_temp = clampf(
			current_temp - temp_loss,
			MIN_TEMP,
			MAX_TEMP
		)

	current_humidity = clampf(
		current_humidity - humidity_loss,
		MIN_HUMIDITY,
		MAX_HUMIDITY
	)

	environment_updated.emit(current_temp, current_humidity)


## Sets the current temperature.
func set_temperature(value: float) -> void:
	current_temp = clampf(value, MIN_TEMP, MAX_TEMP)
	environment_updated.emit(current_temp, current_humidity)


## Sets the current humidity.
func set_humidity(value: float) -> void:
	current_humidity = clampf(
		value,
		MIN_HUMIDITY,
		MAX_HUMIDITY
	)
	environment_updated.emit(current_temp, current_humidity)


## Adds or removes temperature.
func change_temperature(amount: float) -> void:
	set_temperature(current_temp + amount)


## Adds or removes humidity.
func change_humidity(amount: float) -> void:
	set_humidity(current_humidity + amount)


## Applies heat over time. Kept for your future heater.
func apply_heat(delta: float) -> void:
	if delta <= 0.0:
		return

	change_temperature(heat_increase_rate * delta)


## Increases humidity. Kept for your future humidifier.
func spray_water() -> void:
	change_humidity(water_spray_humidity_boost)



## Returns the severity of the current temperature.
## 0 = Ideal, 1 = Slightly bad, 2 = Severely bad.
func get_temperature_severity() -> int:
	return _get_condition_severity(
		current_temp,
		ideal_temp_range,
		temp_warning_margin
	)


## Returns the severity of the current humidity.
func get_humidity_severity() -> int:
	return _get_condition_severity(
		current_humidity,
		ideal_humidity_range,
		humidity_warning_margin
	)


## Calculates total environmental damage per second.
func get_environment_damage_rate() -> float:
	var temperature_severity := get_temperature_severity()
	var humidity_severity := get_humidity_severity()

	# Every severity level adds 0.5 damage per second.
	var total_severity: int = temperature_severity + humidity_severity

	return total_severity * 0.5


## Determines whether a condition is ideal, slightly bad or severely bad.
func _get_condition_severity(
	value: float,
	ideal_range: Vector2,
	warning_margin: float
) -> int:

	if value < ideal_range.x - warning_margin:
		return 2

	if value > ideal_range.y + warning_margin:
		return 2

	if value < ideal_range.x or value > ideal_range.y:
		return 1

	return 0


## Returns the appropriate color for an environmental condition.
func _get_condition_color(
	value: float,
	ideal_range: Vector2,
	warning_margin: float
) -> Color:

	var severity := _get_condition_severity(
		value,
		ideal_range,
		warning_margin
	)

	if severity == 0:
		return COLOR_IDEAL

	var is_too_low: bool = value < ideal_range.x

	if severity == 1:
		return COLOR_SLIGHTLY_COLD if is_too_low else COLOR_SLIGHTLY_WARM

	return COLOR_TOO_COLD if is_too_low else COLOR_TOO_WARM


func get_temperature_color() -> Color:
	return _get_condition_color(
		current_temp,
		ideal_temp_range,
		temp_warning_margin
	)


func get_humidity_color() -> Color:
	return _get_condition_color(
		current_humidity,
		ideal_humidity_range,
		humidity_warning_margin
	)


func _get_range_middle(value: Vector2) -> float:
	var normalised := _normalise_range(value)
	return (normalised.x + normalised.y) / 2.0


func _normalise_range(value: Vector2) -> Vector2:
	return Vector2(
		minf(value.x, value.y),
		maxf(value.x, value.y)
	)

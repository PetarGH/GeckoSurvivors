
extends Control
class_name EnvironmentUI

@export var environment: EnvironmentManager

@export_group("UI Labels")
@export var temperature_label: Label
@export var humidity_label: Label


func _ready() -> void:
	if environment == null:
		push_warning("EnvironmentUI: EnvironmentManager not assigned!")
		return

	if temperature_label == null or humidity_label == null:
		push_warning("EnvironmentUI: Assign both temperature and humidity labels!")
		return

	# Connect to environmental changes.
	environment.environment_updated.connect(_on_environment_updated)

	# Display initial values.
	_on_environment_updated(
		environment.current_temp,
		environment.current_humidity
	)


func _on_environment_updated(
	new_temperature: float,
	new_humidity: float
) -> void:

	# Temperature: one decimal followed by degrees Celsius.
	temperature_label.text = "%.1f°C" % new_temperature

	# Humidity: one decimal followed by percentage.
	humidity_label.text = "%.1f%%" % new_humidity

	# Change label colors based on the gecko's ideal ranges.
	temperature_label.add_theme_color_override(
		"font_color",
		environment.get_temperature_color()
	)

	humidity_label.add_theme_color_override(
		"font_color",
		environment.get_humidity_color()
	)

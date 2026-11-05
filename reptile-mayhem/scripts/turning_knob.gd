
extends Area3D

@export_group("Knob Settings")
@export var environment_manager: EnvironmentManager
@export var adjusts_temperature: bool = false

@export_group("Rotation")
@export var min_angle: float = -135.0
@export var max_angle: float = 135.0
@export var rotation_sensitivity: float = 0.5

var current_value: float = 0.0
var dragging: bool = false


func _ready() -> void:
	input_ray_pickable = true

	input_event.connect(_on_input_event)

	if environment_manager == null:
		push_warning("TurningKnob has no EnvironmentManager assigned!")
		return

	# Start with the current environment value.
	if adjusts_temperature:
		current_value = environment_manager.current_temp
	else:
		current_value = environment_manager.current_humidity

	_update_rotation()

	# Keep the knob synchronized with external environment changes.
	environment_manager.environment_updated.connect(_on_environment_updated)


func _on_input_event(
	_camera: Camera3D,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed


func _input(event: InputEvent) -> void:
	if not dragging:
		return

	# Rotate while holding the left mouse button.
	if event is InputEventMouseMotion:
		rotation_degrees.y += event.relative.x * rotation_sensitivity

		# Restrict rotation.
		rotation_degrees.y = clampf(
			rotation_degrees.y,
			min_angle,
			max_angle
		)

		_update_environment()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			dragging = false


func _update_environment() -> void:
	# Convert rotation into a percentage.
	var percentage := inverse_lerp(
		min_angle,
		max_angle,
		rotation_degrees.y
	)

	if adjusts_temperature:
		var value := lerpf(
			EnvironmentManager.MIN_TEMP,
			EnvironmentManager.MAX_TEMP,
			percentage
		)

		environment_manager.set_temperature(value)

	else:
		var value := lerpf(
			EnvironmentManager.MIN_HUMIDITY,
			EnvironmentManager.MAX_HUMIDITY,
			percentage
		)

		environment_manager.set_humidity(value)


func _on_environment_updated(temp: float, humidity: float) -> void:
	current_value = temp if adjusts_temperature else humidity
	_update_rotation()


func _update_rotation() -> void:
	var min_value := EnvironmentManager.MIN_TEMP if adjusts_temperature else EnvironmentManager.MIN_HUMIDITY
	var max_value := EnvironmentManager.MAX_TEMP if adjusts_temperature else EnvironmentManager.MAX_HUMIDITY

	var percentage := inverse_lerp(min_value, max_value, current_value)

	rotation_degrees.y = lerpf(
		min_angle,
		max_angle,
		percentage
	)

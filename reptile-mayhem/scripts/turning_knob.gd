
extends Area3D

## Clicks played for the notches the knob clicks past, picked at random.
const DIAL_TICK_SOUNDS: Array[AudioStream] = [
	preload("res://audio/sfx/knob-tick-1.wav"),
	preload("res://audio/sfx/knob-tick-2.wav"),
	preload("res://audio/sfx/knob-tick-3.wav"),
]
## A fast drag can cross many notches in one frame; play at most this many so
## the clicks stay separate instead of turning into noise.
const MAX_TICKS_PER_FRAME: int = 3

@export_group("Knob Settings")
@export var environment_manager: EnvironmentManager
@export var adjusts_temperature: bool = false

@export_group("Rotation")
@export var min_angle: float = -135.0
@export var max_angle: float = 135.0
@export var rotation_sensitivity: float = 0.5

@export_group("Dial Sound")
## Degrees the knob has to turn for one notch of the dial to click past.
@export_range(1.0, 30.0, 0.5) var notch_degrees: float = 5.0
## How much each click's pitch varies, so a turn sounds mechanical rather than
## like the same sample repeated.
@export_range(0.0, 0.3, 0.01) var notch_pitch_variation: float = 0.07

var current_value: float = 0.0
var dragging: bool = false

# Degrees turned since the last notch clicked past.
var _notch_progress: float = 0.0


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
		var angle_before := rotation_degrees.y

		# Restrict rotation.
		rotation_degrees.y = clampf(
			rotation_degrees.y + event.relative.x * rotation_sensitivity,
			min_angle,
			max_angle
		)

		_click_notches(absf(rotation_degrees.y - angle_before))
		_update_environment()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			dragging = false


## Clicks like a safe dial: one tick for every notch the knob turns past.
func _click_notches(angle_turned: float) -> void:
	_notch_progress += angle_turned

	var ticks: int = 0

	while _notch_progress >= notch_degrees and ticks < MAX_TICKS_PER_FRAME:
		_notch_progress -= notch_degrees
		ticks += 1

	# Drop the rest of a fast drag's travel so it cannot stockpile clicks.
	_notch_progress = minf(_notch_progress, notch_degrees)

	for i in range(ticks):
		var sound: AudioStream = DIAL_TICK_SOUNDS[
			randi() % DIAL_TICK_SOUNDS.size()
		]
		Audio.play_sfx(
			sound,
			randf_range(1.0 - notch_pitch_variation, 1.0 + notch_pitch_variation)
		)


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

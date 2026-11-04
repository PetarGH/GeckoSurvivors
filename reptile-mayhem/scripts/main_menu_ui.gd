extends Control
@export var next_scene: PackedScene
@export var debug_button: Button


func _ready() -> void:
	if debug_button == null:
		return

	debug_button.toggle_mode = true
	debug_button.button_pressed = DebugSettings.enabled
	_refresh_debug_label()
	debug_button.toggled.connect(_on_debug_toggled)


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_packed(next_scene)


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_debug_toggled(enabled: bool) -> void:
	DebugSettings.enabled = enabled
	_refresh_debug_label()


func _refresh_debug_label() -> void:
	debug_button.text = "Debug: On" if DebugSettings.enabled else "Debug: Off"

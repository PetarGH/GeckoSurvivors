extends Control
@export var next_scene: PackedScene


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_packed(next_scene)


func _on_exit_button_pressed() -> void:
	get_tree().quit()

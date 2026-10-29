extends Control
@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu_scene.tscn"
@export var gecko: Gecko

func _ready() -> void:
	# Hide the lose screen when the game starts.
	hide()

	process_mode = Node.PROCESS_MODE_ALWAYS

	if gecko == null:
		push_warning("Assign the Gecko in the LoseScreen Inspector.")
		return

	# Show the lose screen when the gecko dies.
	gecko.health_depleted.connect(_on_gecko_died)

func _on_gecko_died() -> void:
	show()
	Engine.time_scale = 0

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene_path)
	Engine.time_scale = 1

extends "res://scripts/end_screen.gd"
## Shows the lose screen when the gecko dies.

@export var gecko: Gecko


func _ready() -> void:
	super()

	if gecko == null:
		push_warning("Assign the Gecko in the LoseScreen Inspector.")
		return

	# Show the lose screen when the gecko dies.
	gecko.health_depleted.connect(_on_gecko_died)


func _on_gecko_died() -> void:
	# Let the gecko's death animation play out in the terrarium first.
	await gecko.wait_for_death_animation()

	if is_inside_tree():
		show_screen()

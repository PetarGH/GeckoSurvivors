
extends Control

@export var gecko: Gecko

@export var points_label: Label


func _ready() -> void:
	if gecko == null:
		push_warning("No Gecko assigned to PointsUI!")
		return

	# Listen for changes to the gecko's points.
	gecko.points_changed.connect(_on_points_changed)

	# Display the current points when the game starts.
	_on_points_changed(gecko.current_points)


func _on_points_changed(new_points: int) -> void:
	points_label.text = str(new_points)

extends PanelContainer

@export var gecko: Gecko
@export var points_label: Label

@onready var tooltip = $Tooltip


func _ready() -> void:
	# Connect mouse hover signals
	mouse_entered.connect(on_mouse_entered)
	mouse_exited.connect(on_mouse_exited)

	# Check that a Gecko is assigned
	if gecko == null:
		push_warning("No Gecko assigned to PointsUI!")
		return

	# Listen for changes to the gecko's points
	gecko.points_changed.connect(_on_points_changed)

	# Display the current points
	_on_points_changed(gecko.current_points)


func _on_points_changed(new_points: int) -> void:
	points_label.text = str(new_points)


func on_mouse_entered() -> void:
	tooltip.toggle(true)


func on_mouse_exited() -> void:
	tooltip.toggle(false)

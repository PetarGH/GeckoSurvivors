extends PanelContainer
@onready var tooltip = $Tooltip

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_entered.connect(on_mouse_entered)
	mouse_exited.connect(on_mouse_exited)

func on_mouse_exited():
	tooltip.toggle(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func on_mouse_entered():
	tooltip.toggle(true)

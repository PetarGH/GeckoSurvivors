extends VBoxContainer
## Temp, moisture, and kill controls shown only while debug mode is on.

@export var environment: EnvironmentManager
@export var gecko: Gecko


func _ready() -> void:
	visible = DebugSettings.enabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	$TempButton.pressed.connect(_on_temp_pressed)
	$MoistureButton.pressed.connect(_on_moisture_pressed)
	$KillButton.pressed.connect(_on_kill_pressed)

	if gecko != null:
		gecko.health_depleted.connect(hide)


func _on_temp_pressed() -> void:
	if environment == null:
		return

	environment.change_temperature(-10.0)


func _on_moisture_pressed() -> void:
	if environment == null:
		return

	environment.change_humidity(-10.0)


func _on_kill_pressed() -> void:
	if gecko == null or not gecko.is_alive():
		return

	gecko.take_damage(gecko.current_health)

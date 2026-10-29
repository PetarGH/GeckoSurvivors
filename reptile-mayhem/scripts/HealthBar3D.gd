
extends Node3D

@onready var health_viewport: SubViewport = $SubViewport
@onready var control: Control = $SubViewport/Control
@onready var health_bar: ProgressBar = $SubViewport/Control/ProgressBar
@onready var health_sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	# Set the viewport size and transparency.
	health_viewport.size = Vector2i(256, 32)
	health_viewport.transparent_bg = true
	health_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Fill the viewport with the UI.
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar.show_percentage = false

	# Display the UI as a texture in 3D space.
	health_sprite.texture = health_viewport.get_texture()
	health_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_sprite.pixel_size = 0.005

	# Find the Gecko parent.
	var gecko := get_parent() as Gecko

	if gecko == null:
		push_warning("HealthBar3D must be a child of Gecko.")
		return

	# Initialize the health bar.
	if gecko.species_data != null:
		health_bar.max_value = gecko.species_data.max_health
	else:
		health_bar.max_value = 100.0

	health_bar.value = gecko.current_health

	# Automatically update when the gecko takes damage.
	gecko.health_changed.connect(_on_health_changed)


func _on_health_changed(new_health: float) -> void:
	health_bar.value = new_health

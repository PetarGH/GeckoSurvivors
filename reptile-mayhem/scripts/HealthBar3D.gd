extends Node3D

@onready var health_viewport: SubViewport = $SubViewport
@onready var control: Control = $SubViewport/Control
@onready var health_bar: ProgressBar = $SubViewport/Control/ProgressBar
@onready var health_sprite: Sprite3D = $Sprite3D

var fill_style: StyleBoxFlat


func _ready() -> void:
	# Set the viewport size and transparency.
	health_viewport.size = Vector2i(256, 32)
	health_viewport.transparent_bg = true
	health_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Fill the viewport with the UI.
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_bar.show_percentage = false

	# Create a separate fill style.
	var original_style = health_bar.get_theme_stylebox("fill")
	fill_style = original_style.duplicate() as StyleBoxFlat

	if fill_style == null:
		fill_style = StyleBoxFlat.new()

	health_bar.add_theme_stylebox_override("fill", fill_style)

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

	# Set the initial colour.
	_update_health_colour()

	# Automatically update when health changes.
	gecko.health_changed.connect(_on_health_changed)


func _on_health_changed(new_health: float) -> void:
	health_bar.value = new_health
	_update_health_colour()


func _update_health_colour() -> void:
	var health_percentage = health_bar.value / health_bar.max_value * 100.0

	if health_percentage < 25.0:
		fill_style.bg_color = Color.RED

	elif health_percentage < 50.0:
		fill_style.bg_color = Color.YELLOW

	else:
		fill_style.bg_color = Color.GREEN

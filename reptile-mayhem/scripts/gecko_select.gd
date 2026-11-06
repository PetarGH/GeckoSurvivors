extends Control
## Selection stage shown after Play: the player picks the gecko they will look after.
## The card is built from [GeckoSpeciesData] so more geckos can be added later.

const TITLE_FONT: Font = preload("res://fonts/Super Waffles.ttf")
const TEMP_ICON: Texture2D = preload(
	"res://images/temperature-sign-for-design-element-png.webp"
)
const DROP_ICON: Texture2D = preload("res://images/water-drop-icon-png.png")
const GECKO_MESH: PackedScene = preload(
	"res://meshes/M_Gekko_Player_Blockout.glb"
)

const MENU_SCENE := "res://scenes/main_menu_scene.tscn"

## Scene loaded when the player picks the gecko.
@export var next_scene: PackedScene
## Species shown on the card.
@export var species: GeckoSpeciesData

const CARD_SIZE := Vector2(460.0, 452.0)
const CARD_TOP_OFFSET := 42.0

const CREAM := Color(0.949, 1.0, 0.984)
const MUTED := Color(0.86, 0.95, 0.92, 0.62)
const CARD_BG := Color(0.078, 0.153, 0.176)
const CARD_BG_HOVER := Color(0.106, 0.204, 0.235)
const CARD_BG_PRESSED := Color(0.129, 0.243, 0.278)
const MINT := Color(0.486, 0.941, 0.769)
const GOOD_BG := Color(0.129, 0.42, 0.275)
const GOOD_BORDER := Color(0.435, 0.89, 0.604)
const BAD_BG := Color(0.451, 0.161, 0.173)
const BAD_BORDER := Color(1.0, 0.541, 0.525)
const PORTRAIT_BG := Color(0.043, 0.098, 0.114)
const INSET_BG := Color(0.055, 0.125, 0.145)

var _card: Button
var _outline: Panel
var _portrait_frame: PanelContainer
var _viewport: SubViewport
var _spin_pivot: Node3D
var _model_root: Node3D
var _hint: Label

var _spin: float = 0.6
var _target_spin: float = 0.6
var _hover_mouse: bool = false
var _hover_focus: bool = false
var _hovered: bool = false
var _leaving: bool = false
var _hover_tween: Tween
var _intro_tween: Tween


func _ready() -> void:
	GameSession.select_species(species)
	_build_card()
	_build_card_content()
	_setup_portrait()
	_play_intro()


func _process(delta: float) -> void:
	if is_instance_valid(_spin_pivot):
		_spin = lerpf(_spin, _target_spin, clampf(delta * 6.0, 0.0, 1.0))
		_spin_pivot.rotate_y(_spin * delta)

	if is_instance_valid(_hint):
		var time := Time.get_ticks_msec() / 1000.0
		var base := 0.95 if _hovered else 0.62
		_hint.modulate.a = clampf(base + sin(time * 3.0) * 0.2, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _leaving:
		_leave_to_menu()


## Creates the clickable card and its glow outline.
func _build_card() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = CARD_BG
	normal.set_corner_radius_all(26)
	normal.set_border_width_all(2)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.1)
	normal.set_content_margin_all(0)
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	normal.shadow_size = 16
	normal.shadow_offset = Vector2(0.0, 8.0)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = CARD_BG_HOVER
	hover.border_color = Color(MINT.r, MINT.g, MINT.b, 0.55)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = CARD_BG_PRESSED
	pressed.border_color = Color(MINT.r, MINT.g, MINT.b, 0.85)

	_card = Button.new()
	_card.name = "GeckoCard"
	_card.text = ""
	_card.focus_mode = Control.FOCUS_ALL
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left = -CARD_SIZE.x * 0.5
	_card.offset_right = CARD_SIZE.x * 0.5
	_card.offset_top = -CARD_SIZE.y * 0.5 + CARD_TOP_OFFSET
	_card.offset_bottom = CARD_SIZE.y * 0.5 + CARD_TOP_OFFSET
	_card.add_theme_stylebox_override("normal", normal)
	_card.add_theme_stylebox_override("hover", hover)
	_card.add_theme_stylebox_override("pressed", pressed)
	_card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_card.add_theme_color_override("font_color", CREAM)
	_card.resized.connect(_on_card_resized)
	_card.mouse_entered.connect(_on_card_mouse_entered)
	_card.mouse_exited.connect(_on_card_mouse_exited)
	_card.focus_entered.connect(_on_card_focus_entered)
	_card.focus_exited.connect(_on_card_focus_exited)
	_card.pressed.connect(_on_card_pressed)
	add_child(_card)

	# The glow ring sits behind the card, so it reads as an outline.
	_outline = Panel.new()
	_outline.name = "Outline"
	_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_outline.offset_left = -7.0
	_outline.offset_top = -7.0
	_outline.offset_right = 7.0
	_outline.offset_bottom = 7.0
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.show_behind_parent = true
	_outline.modulate.a = 0.0

	var glow := StyleBoxFlat.new()
	glow.bg_color = CARD_BG
	glow.set_corner_radius_all(32)
	glow.set_border_width_all(4)
	glow.border_color = Color(MINT.r, MINT.g, MINT.b, 0.9)
	glow.shadow_color = Color(MINT.r, MINT.g, MINT.b, 0.45)
	glow.shadow_size = 18
	glow.set_content_margin_all(0)
	_outline.add_theme_stylebox_override("panel", glow)
	_card.add_child(_outline)

	_card.pivot_offset = CARD_SIZE * 0.5


## Builds the card contents: name, portrait, habitat and food.
func _build_card_content() -> void:
	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var name_label := _make_label(_species_name(), 36, CREAM, TITLE_FONT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)

	_portrait_frame = _build_portrait_frame()
	column.add_child(_portrait_frame)

	column.add_child(_build_environment_row())

	var food_caption := _make_label("WHAT IT EATS", 14, MUTED)
	food_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(food_caption)

	column.add_child(_build_food_row())

	var legend := _make_label(
		"Green is good for it. Never feed it the red one.", 15, MUTED
	)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend)

	_hint = _make_label("Click to continue", 16, CREAM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)


func _build_portrait_frame() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0.0, 160.0)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = PORTRAIT_BG
	style.set_corner_radius_all(18)
	style.set_border_width_all(1)
	style.border_color = Color(1.0, 1.0, 1.0, 0.07)
	style.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", style)

	return frame


## Puts the gecko model in the portrait and slowly turns it.
func _setup_portrait() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_frame.add_child(container)

	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(420, 170)
	container.add_child(_viewport)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.85, 0.95)
	environment.ambient_light_energy = 1.1
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	_viewport.add_child(key_light)

	_spin_pivot = Node3D.new()
	_spin_pivot.name = "SpinPivot"
	_viewport.add_child(_spin_pivot)

	_model_root = GECKO_MESH.instantiate()
	_spin_pivot.add_child(_model_root)
	_spin_pivot.rotation_degrees.y = -25.0

	# Wait for the layout and the mesh transforms before framing the shot.
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_inside_tree() or not is_instance_valid(_viewport):
		return

	_frame_portrait()


## Centres the model and fits the camera to its bounding box.
func _frame_portrait() -> void:
	var model_aabb := AABB()
	var has_mesh := false

	for node in _model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var local := _model_root.global_transform.affine_inverse() \
			* mesh_instance.global_transform
		var box: AABB = local * mesh_instance.get_aabb()

		model_aabb = box if not has_mesh else model_aabb.merge(box)
		has_mesh = true

	if not has_mesh:
		return

	var size := model_aabb.size
	_model_root.position -= model_aabb.get_center()

	var aspect := maxf(_portrait_frame.size.x, 1.0) \
		/ maxf(_portrait_frame.size.y, 1.0)

	var camera := Camera3D.new()
	camera.fov = 32.0

	var half_vertical := tan(deg_to_rad(camera.fov * 0.5))
	var half_horizontal := half_vertical * aspect
	var half_width := maxf(size.x, size.z) * 0.5
	var distance := maxf(
		(half_width * 1.08) / half_horizontal,
		(size.y * 0.62) / half_vertical
	) + half_width

	_viewport.add_child(camera)
	camera.position = Vector3(0.0, size.y * 0.1, distance)
	camera.look_at(Vector3(0.0, size.y * 0.02, 0.0), Vector3.UP)
	camera.current = true

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-distance * 0.6, size.y * 0.5, -distance * 0.4)
	rim_light.light_color = MINT
	rim_light.light_energy = 0.8
	rim_light.omni_range = distance * 2.0
	_viewport.add_child(rim_light)


func _build_environment_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = INSET_BG
	style.set_corner_radius_all(14)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var temperature := species.ideal_temp_range if species != null \
		else Vector2(24.0, 32.0)
	var humidity := species.ideal_humidity_range if species != null \
		else Vector2(30.0, 50.0)

	row.add_child(_icon_value(
		TEMP_ICON,
		"%d–%d °C" % [roundi(minf(temperature.x, temperature.y)),
			roundi(maxf(temperature.x, temperature.y))]
	))
	row.add_child(_icon_value(
		DROP_ICON,
		"%d–%d %%" % [roundi(minf(humidity.x, humidity.y)),
			roundi(maxf(humidity.x, humidity.y))]
	))

	var biome := species.preferred_biome if species != null else 2
	row.add_child(_icon_value(null, _biome_name(biome)))

	return panel


func _build_food_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for food_type in _accepted_foods():
		row.add_child(_make_food_chip(_food_name(food_type), true))

	# Vegetables hurt this gecko, so make that warning impossible to miss.
	if not _is_food_accepted(HabitatEnums.FoodType.BROCCOLI):
		row.add_child(_make_food_chip("Vegetables", false))

	return row


func _make_food_chip(text: String, good: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0.0, 44.0)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = GOOD_BG if good else BAD_BG
	style.border_color = GOOD_BORDER if good else BAD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	chip.add_theme_stylebox_override("panel", style)

	var label := _make_label(text, 17, CREAM if good else Color(1.0, 0.9, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(label)

	return chip


func _icon_value(icon: Texture2D, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if icon != null:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.custom_minimum_size = Vector2(22.0, 22.0)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rect)

	row.add_child(_make_label(text, 17, CREAM))
	return row


func _make_label(
	text: String, font_size: int, color: Color, font: Font = null
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if font != null:
		label.add_theme_font_override("font", font)

	return label


func _species_name() -> String:
	if species == null or species.species_name.is_empty():
		return "Gecko"
	return species.species_name


func _accepted_foods() -> Array:
	if species != null:
		return species.accepted_food_types
	return [
		HabitatEnums.FoodType.SUPERWORM,
		HabitatEnums.FoodType.ROACH,
		HabitatEnums.FoodType.CRICKET,
	]


func _is_food_accepted(food_type: int) -> bool:
	if species == null:
		return food_type != HabitatEnums.FoodType.BROCCOLI
	return species.is_food_accepted(food_type)


func _food_name(food_type: int) -> String:
	match food_type:
		HabitatEnums.FoodType.SUPERWORM:
			return "Superworm"
		HabitatEnums.FoodType.GRASSHOPPER:
			return "Grasshopper"
		HabitatEnums.FoodType.ROACH:
			return "Roach"
		HabitatEnums.FoodType.BEETLE:
			return "Beetle"
		HabitatEnums.FoodType.CRICKET:
			return "Cricket"
		HabitatEnums.FoodType.BANANA:
			return "Banana"
		HabitatEnums.FoodType.PAPAYA:
			return "Papaya"
		HabitatEnums.FoodType.MANGO:
			return "Mango"
		HabitatEnums.FoodType.BROCCOLI:
			return "Broccoli"
	return "Food"


func _biome_name(biome: int) -> String:
	var names: Array = HabitatEnums.BiomeType.keys()
	if biome < 0 or biome >= names.size():
		return "Unknown"
	return String(names[biome]).capitalize()


func _play_intro() -> void:
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE * 0.94

	_intro_tween = create_tween()
	_intro_tween.set_parallel()
	_intro_tween.tween_property(_card, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_card, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_card_resized() -> void:
	_card.pivot_offset = _card.size * 0.5


func _on_card_mouse_entered() -> void:
	_hover_mouse = true
	_refresh_hover()


func _on_card_mouse_exited() -> void:
	_hover_mouse = false
	_refresh_hover()


func _on_card_focus_entered() -> void:
	_hover_focus = true
	_refresh_hover()


func _on_card_focus_exited() -> void:
	_hover_focus = false
	_refresh_hover()


func _refresh_hover() -> void:
	var hovered := _hover_mouse or _hover_focus
	if hovered == _hovered:
		return

	_hovered = hovered
	_target_spin = 2.2 if hovered else 0.6

	# The intro animation would fight the hover scale if both ran at once.
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
		_card.modulate.a = 1.0

	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_parallel()
	_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(
		_outline, "modulate:a", 1.0 if hovered else 0.0, 0.18
	)
	_hover_tween.tween_property(
		_card, "scale", Vector2.ONE * (1.045 if hovered else 1.0), 0.18
	)


func _on_card_pressed() -> void:
	if _leaving:
		return

	_leaving = true
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.focus_mode = Control.FOCUS_NONE
	_target_spin = 4.0
	_hint.text = "Let's go!"

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "scale", Vector2.ONE * 1.07, 0.12)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_card, "scale", Vector2.ONE * 0.94, 0.14)
	tween.parallel().tween_property(_outline, "modulate:a", 1.0, 0.14)
	await tween.finished

	_leave_to(next_scene)


func _on_back_button_pressed() -> void:
	if _leaving:
		return
	_leave_to_menu()


## Fades the screen out and loads [param next_scene].
func _leave_to(next_scene: PackedScene) -> void:
	if next_scene == null:
		return

	_leaving = true
	await _fade_out()
	get_tree().change_scene_to_packed(next_scene)


func _leave_to_menu() -> void:
	_leaving = true
	await _fade_out()
	get_tree().change_scene_to_file(MENU_SCENE)


## Fades the screen to black.
func _fade_out() -> void:
	var fade := ColorRect.new()
	fade.name = "Fade"
	fade.color = Color(0.02, 0.05, 0.06, 0.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

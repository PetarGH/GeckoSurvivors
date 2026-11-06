extends Control
## Overlay shown when a run ends. Subclasses decide when that happens.

const STAT_FONT: Font = preload("res://fonts/Super Waffles.ttf")
const STAT_FONT_SIZE: int = 36

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/main_menu_scene.tscn"

var _stats_root: Control


func _ready() -> void:
	# Hidden until the run ends.
	hide()

	process_mode = Node.PROCESS_MODE_ALWAYS


## Shows this screen with the stats of the finished run and pauses the game.
func show_screen() -> void:
	GameSession.record_selected_run(_run_score(), _is_victory())
	_build_stats()
	show()
	Engine.time_scale = 0


## Overridden by screens that end a successful run.
func _is_victory() -> bool:
	return false


## Score of the run that just ended, read from the terrarium in the level.
func _run_score() -> int:
	var current := get_tree().current_scene

	if current == null:
		return 0

	var terrarium := current.get_node_or_null(^"Terrarium") as Terrarium
	return terrarium.score if terrarium != null else 0


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene_path)
	Engine.time_scale = 1


func _build_stats() -> void:
	if _stats_root != null:
		_stats_root.queue_free()

	var stats_list := VBoxContainer.new()
	stats_list.name = "StatsList"
	stats_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_list.add_theme_constant_override("separation", 10)
	add_child(stats_list)
	_stats_root = stats_list

	for entry: Dictionary in RunStats.get_entries():
		stats_list.add_child(_make_stat_row(entry))

	# Keep the column above the Continue button, centered in the space to its left.
	var list_size := stats_list.get_combined_minimum_size()
	var button_clearance := 300.0
	var available_right := maxf(size.x - button_clearance, list_size.x)
	var left := maxf((available_right - list_size.x) * 0.5, 32.0)
	stats_list.position = Vector2(left, 232.0)
	stats_list.size = list_size


func _make_stat_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)

	var name_label := _make_stat_label(str(entry["label"]), HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value_label := _make_stat_label(str(entry["text"]), HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(value_label)
	return row


func _make_stat_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", STAT_FONT)
	label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

extends Control
## Level select: the levels that belong to the chosen gecko, each showing the
## best score saved on this device. Clicking a card starts that level.

const TITLE_FONT: Font = preload("res://fonts/Super Waffles.ttf")
const TEMP_ICON: Texture2D = preload(
	"res://images/temperature-sign-for-design-element-png.webp"
)
const DROP_ICON: Texture2D = preload("res://images/water-drop-icon-png.png")
const COIN_ICON: Texture2D = preload(
	"res://images/Glossy Gold Star Coin Icon.png"
)

const GECKO_SCENE := "res://scenes/gecko_select.tscn"

const CREAM := Color(0.949, 1.0, 0.984)
const MUTED := Color(0.86, 0.95, 0.92, 0.62)
const CARD_BG := Color(0.078, 0.153, 0.176)
const CARD_BG_HOVER := Color(0.106, 0.204, 0.235)
const CARD_BG_PRESSED := Color(0.129, 0.243, 0.278)
const INSET_BG := Color(0.055, 0.125, 0.145)
const GOOD_BG := Color(0.129, 0.42, 0.275)
const GOOD_BORDER := Color(0.435, 0.89, 0.604)
const ACCENTS: Array[Color] = [
	Color(0.486, 0.941, 0.769),
	Color(0.988, 0.796, 0.353),
	Color(1.0, 0.557, 0.416),
]

const CARD_SIZE := Vector2(296.0, 412.0)
const CARD_GAP := 26.0
const CARD_TOP_OFFSET := 22.0
const SHINE_WIDTH := 120.0

## Everything the screen needs to animate one level card.
class LevelCard:
	var level: LevelData
	var index: int = 0
	var button: Button
	var outline: Panel
	var shine: TextureRect
	var hint: Label
	var hover_mouse: bool = false
	var hover_focus: bool = false
	var hovered: bool = false
	var hover_tween: Tween
	var sweep_tween: Tween
	var intro_tween: Tween


## Fallback gecko used when the screen is opened straight from the editor.
@export var species: GeckoSpeciesData
## Fallback levels used when the species has none assigned.
@export var levels: Array[LevelData] = []

var _species: GeckoSpeciesData
var _level_list: Array[LevelData] = []
var _cards: Array[LevelCard] = []
var _leaving: bool = false


func _ready() -> void:
	_species = GameSession.selected_species if GameSession.selected_species != null \
		else species

	if GameSession.selected_species == null and _species != null:
		GameSession.select_species(_species)

	_level_list = _resolve_levels()
	_update_subtitle()

	if _level_list.is_empty():
		push_warning("LevelSelect: this gecko has no levels")
		return

	_build_row()
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _leaving:
		_leave_to_gecko_select()


## Uses the gecko's own levels, falling back to the exported list.
func _resolve_levels() -> Array[LevelData]:
	if _species != null:
		var from_species := _species.get_levels()

		if not from_species.is_empty():
			return from_species

	return levels


func _update_subtitle() -> void:
	var subtitle := get_node_or_null(^"Subtitle") as Label

	if subtitle == null:
		return

	var gecko_name := _species.species_name if _species != null else "your gecko"
	subtitle.text = "%s · %d levels" % [gecko_name, _level_list.size()]


## Lays a card out per level, centered as one row.
func _build_row() -> void:
	var total_width := CARD_SIZE.x * _level_list.size() \
		+ CARD_GAP * maxf(_level_list.size() - 1, 0)

	var row := HBoxContainer.new()
	row.name = "Cards"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(CARD_GAP))
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_left = -total_width * 0.5
	row.offset_right = total_width * 0.5
	row.offset_top = -CARD_SIZE.y * 0.5 + CARD_TOP_OFFSET
	row.offset_bottom = CARD_SIZE.y * 0.5 + CARD_TOP_OFFSET
	add_child(row)

	for index in _level_list.size():
		_cards.append(_build_card(_level_list[index], index, row))


func _build_card(level: LevelData, index: int, parent: Node) -> LevelCard:
	var card := LevelCard.new()
	card.level = level
	card.index = index

	var accent := _accent_for(index)
	var best := GameSession.get_best_score(_species, level)
	var cleared := GameSession.has_cleared(_species, level)

	card.button = Button.new()
	card.button.name = "Level%dCard" % level.level_number
	card.button.text = ""
	card.button.custom_minimum_size = CARD_SIZE
	card.button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.button.focus_mode = Control.FOCUS_ALL
	card.button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.button.add_theme_stylebox_override(
		"normal", _card_style(CARD_BG, Color(1.0, 1.0, 1.0, 0.08))
	)
	card.button.add_theme_stylebox_override(
		"hover", _card_style(CARD_BG_HOVER, _with_alpha(accent, 0.55))
	)
	card.button.add_theme_stylebox_override(
		"pressed", _card_style(CARD_BG_PRESSED, _with_alpha(accent, 0.9))
	)
	card.button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.button.resized.connect(_on_card_resized.bind(card))
	parent.add_child(card.button)

	# The glow ring sits behind the card, so it reads as an outline.
	card.outline = Panel.new()
	card.outline.name = "Outline"
	card.outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.outline.offset_left = -7.0
	card.outline.offset_top = -7.0
	card.outline.offset_right = 7.0
	card.outline.offset_bottom = 7.0
	card.outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.outline.show_behind_parent = true
	card.outline.modulate.a = 0.0

	var glow := StyleBoxFlat.new()
	glow.bg_color = CARD_BG
	glow.set_corner_radius_all(31)
	glow.set_border_width_all(4)
	glow.border_color = _with_alpha(accent, 0.9)
	glow.shadow_color = _with_alpha(accent, 0.45)
	glow.shadow_size = 18
	glow.set_content_margin_all(0)
	card.outline.add_theme_stylebox_override("panel", glow)
	card.button.add_child(card.outline)

	# A soft light band that sweeps across the card when it gets attention.
	card.shine = TextureRect.new()
	card.shine.texture = _shine_texture()
	card.shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.shine.stretch_mode = TextureRect.STRETCH_SCALE
	card.shine.position = Vector2(-SHINE_WIDTH, 0.0)
	card.shine.size = Vector2(SHINE_WIDTH, CARD_SIZE.y)
	card.shine.modulate.a = 0.0
	card.shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.button.add_child(card.shine)

	_build_content(card, accent, best, cleared)

	card.button.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	card.button.mouse_exited.connect(_on_card_mouse_exited.bind(card))
	card.button.focus_entered.connect(_on_card_focus_entered.bind(card))
	card.button.focus_exited.connect(_on_card_focus_exited.bind(card))
	card.button.pressed.connect(_on_card_pressed.bind(card))

	return card


func _build_content(
	card: LevelCard, accent: Color, best: int, cleared: bool
) -> void:
	var margin := MarginContainer.new()
	margin.name = "Content"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.button.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_build_header(card.level, accent, cleared))

	var name_label := _make_label(card.level.level_name, 30, CREAM, TITLE_FONT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)

	var description := _make_label(card.level.description, 14, MUTED)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(0.0, 40.0)
	column.add_child(description)

	column.add_child(_divider())

	var caption := _make_label("DECAY PER SECOND", 11, MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)

	column.add_child(_stat_row(
		null,
		"FEEDERS",
		"%d × %d-%d bugs" % [card.level.spawner_count, card.level.bugs_per_spawner_min, card.level.bugs_per_spawner_max]
	))
	column.add_child(_stat_row(
		TEMP_ICON,
		"TEMP LOSS",
		_range_text(card.level.temp_decay_min, card.level.temp_decay_max)
	))
	column.add_child(_stat_row(
		DROP_ICON,
		"HUMIDITY LOSS",
		_range_text(
			card.level.humidity_decay_min, card.level.humidity_decay_max
		)
	))

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	column.add_child(_divider())
	column.add_child(_build_best_panel(best))

	card.hint = _make_label("Click to play", 12, CREAM)
	card.hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.hint.modulate.a = 0.55
	column.add_child(card.hint)


func _build_header(
	level: LevelData, accent: Color, cleared: bool
) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = _with_alpha(accent, 0.16)
	style.border_color = _with_alpha(accent, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override("panel", style)
	pill.add_child(_make_label("LEVEL %d" % level.level_number, 12, accent))
	header.add_child(pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	if cleared:
		var cleared_pill := PanelContainer.new()
		cleared_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
		cleared_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var cleared_style := StyleBoxFlat.new()
		cleared_style.bg_color = GOOD_BG
		cleared_style.border_color = GOOD_BORDER
		cleared_style.set_border_width_all(1)
		cleared_style.set_corner_radius_all(9)
		cleared_style.content_margin_left = 9.0
		cleared_style.content_margin_right = 9.0
		cleared_style.content_margin_top = 2.0
		cleared_style.content_margin_bottom = 2.0
		cleared_pill.add_theme_stylebox_override("panel", cleared_style)
		cleared_pill.add_child(_make_label("CLEARED", 11, CREAM))
		header.add_child(cleared_pill)

	return header


func _build_best_panel(best: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = INSET_BG
	style.set_corner_radius_all(12)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var coin := TextureRect.new()
	coin.texture = COIN_ICON
	coin.custom_minimum_size = Vector2(24.0, 24.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.modulate.a = 1.0 if best > 0 else 0.4
	row.add_child(coin)

	var caption := _make_label("BEST", 12, MUTED)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)

	var value := _make_label(
		_format_score(best) if best > 0 else "—",
		19 if best > 0 else 17,
		CREAM if best > 0 else MUTED
	)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)

	return panel


func _stat_row(icon: Texture2D, caption: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if icon != null:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.custom_minimum_size = Vector2(16.0, 16.0)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rect)
	else:
		# Keeps text rows aligned with the rows that carry an icon.
		var gutter := Control.new()
		gutter.custom_minimum_size = Vector2(16.0, 16.0)
		gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gutter)

	var caption_label := _make_label(caption, 12, MUTED)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption_label)

	var value_label := _make_label(value, 14, CREAM)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)

	return row


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1.0, 1.0, 1.0, 0.09)
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _card_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(24)
	style.set_border_width_all(2)
	style.border_color = border
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0.0, 8.0)
	style.set_content_margin_all(0)
	return style


func _shine_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.16),
		Color(1.0, 1.0, 1.0, 0.0),
	])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 96
	texture.height = 8
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


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


func _accent_for(index: int) -> Color:
	return ACCENTS[index % ACCENTS.size()]


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## "0.05 – 0.20": the loss applied per second at its easiest and hardest.
func _range_text(low: float, high: float) -> String:
	return "%.2f – %.2f" % [minf(low, high), maxf(low, high)]


func _format_score(value: int) -> String:
	var digits := str(maxi(value, 0))
	var result := ""
	var counter := 0

	for index in range(digits.length() - 1, -1, -1):
		result = digits[index] + result
		counter += 1

		if counter % 3 == 0 and index > 0:
			result = "," + result

	return result


func _play_intro() -> void:
	for card: LevelCard in _cards:
		card.button.modulate.a = 0.0
		card.button.scale = Vector2.ONE * 0.94
		card.button.pivot_offset = CARD_SIZE * 0.5

		var delay := card.index * 0.08
		card.intro_tween = create_tween()
		card.intro_tween.set_parallel()
		card.intro_tween.tween_property(
			card.button, "modulate:a", 1.0, 0.25
		).set_delay(delay)
		card.intro_tween.tween_property(
			card.button, "scale", Vector2.ONE, 0.42
		).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_card_resized(card: LevelCard) -> void:
	card.button.pivot_offset = card.button.size * 0.5


func _on_card_mouse_entered(card: LevelCard) -> void:
	card.hover_mouse = true
	_refresh_hover(card)


func _on_card_mouse_exited(card: LevelCard) -> void:
	card.hover_mouse = false
	_refresh_hover(card)


func _on_card_focus_entered(card: LevelCard) -> void:
	card.hover_focus = true
	_refresh_hover(card)


func _on_card_focus_exited(card: LevelCard) -> void:
	card.hover_focus = false
	_refresh_hover(card)


## Grows the card, lights its outline and sweeps a highlight over it.
func _refresh_hover(card: LevelCard) -> void:
	var hovered := card.hover_mouse or card.hover_focus

	if hovered == card.hovered:
		return

	card.hovered = hovered

	# The intro animation would fight the hover scale if both ran at once.
	if card.intro_tween != null and card.intro_tween.is_valid():
		card.intro_tween.kill()
		card.button.modulate.a = 1.0
		card.button.scale = Vector2.ONE

	if card.hover_tween != null and card.hover_tween.is_valid():
		card.hover_tween.kill()

	if card.sweep_tween != null and card.sweep_tween.is_valid():
		card.sweep_tween.kill()

	card.hover_tween = create_tween()
	card.hover_tween.set_parallel()
	card.hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	card.hover_tween.tween_property(
		card.outline, "modulate:a", 1.0 if hovered else 0.0, 0.18
	)
	card.hover_tween.tween_property(
		card.button, "scale", Vector2.ONE * (1.05 if hovered else 1.0), 0.18
	)
	card.hover_tween.tween_property(
		card.hint, "modulate:a", 0.95 if hovered else 0.55, 0.18
	)

	if hovered:
		_sweep_shine(card)
	else:
		card.shine.modulate.a = 0.0


func _sweep_shine(card: LevelCard) -> void:
	card.shine.position = Vector2(-SHINE_WIDTH, 0.0)
	card.shine.modulate.a = 1.0

	card.sweep_tween = create_tween()
	card.sweep_tween.tween_property(
		card.shine, "position:x", CARD_SIZE.x, 0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	card.sweep_tween.tween_property(card.shine, "modulate:a", 0.0, 0.1)


func _on_card_pressed(card: LevelCard) -> void:
	if _leaving:
		return

	_leaving = true
	GameSession.select_level(card.level)

	# Fade the levels the player did not pick so the choice reads clearly.
	for other: LevelCard in _cards:
		other.button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		other.button.focus_mode = Control.FOCUS_NONE

		if other == card:
			continue

		var dim := create_tween()
		dim.tween_property(other.button, "modulate:a", 0.2, 0.22)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card.button, "scale", Vector2.ONE * 1.08, 0.12)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card.button, "scale", Vector2.ONE * 0.96, 0.14)
	tween.parallel().tween_property(card.outline, "modulate:a", 1.0, 0.14)
	await tween.finished

	if card.level.scene == null:
		push_warning("LevelSelect: level %d has no scene" % card.level.level_number)
		return

	await _fade_out()
	get_tree().change_scene_to_packed(card.level.scene)


func _on_back_button_pressed() -> void:
	if _leaving:
		return
	_leave_to_gecko_select()


func _leave_to_gecko_select() -> void:
	_leaving = true
	await _fade_out()
	get_tree().change_scene_to_file(GECKO_SCENE)


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

extends Node
## Remembers the gecko and level the player picked, and keeps the best score
## they reached on every level of every gecko between launches.

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://gecko_progress.json"

## Gecko chosen on the selection screen.
var selected_species: GeckoSpeciesData
## Level chosen on the level select screen; applied when the level scene loads.
var selected_level: LevelData

# species_id -> level_id -> { "best": int, "cleared": bool }
var _progress: Dictionary = {}


func _ready() -> void:
	load_progress()


func select_species(species: GeckoSpeciesData) -> void:
	selected_species = species


func select_level(level: LevelData) -> void:
	selected_level = level


## Highest score reached on [param level], or 0 if it was never finished.
func get_best_score(species: GeckoSpeciesData, level: LevelData) -> int:
	return int(_get_record(species, level).get("best", 0))


## True once the player has won this level at least once.
func has_cleared(species: GeckoSpeciesData, level: LevelData) -> bool:
	return bool(_get_record(species, level).get("cleared", false))


## Stores the result of a finished run, keeping the best score and any clear.
func record_run(
	species: GeckoSpeciesData, level: LevelData, score: int, cleared: bool
) -> void:
	if species == null or level == null:
		return

	var species_key := _species_key(species)
	var level_key := level.get_id()

	var levels: Dictionary = _progress.get(species_key, {})
	var record: Dictionary = levels.get(level_key, {"best": 0, "cleared": false})

	var changed := false

	if score > int(record.get("best", 0)):
		record["best"] = int(score)
		changed = true

	if cleared and not bool(record.get("cleared", false)):
		record["cleared"] = true
		changed = true

	if not changed:
		return

	levels[level_key] = record
	_progress[species_key] = levels
	save_progress()


## Records the result of the run that just ended for the current selection.
func record_selected_run(score: int, cleared: bool) -> void:
	record_run(selected_species, selected_level, score, cleared)


func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_warning("GameSession: could not write %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"geckos": _progress,
	}, "\t"))
	file.close()


func load_progress() -> void:
	_progress = {}

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_warning("GameSession: could not read %s" % SAVE_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameSession: %s is not valid save data" % SAVE_PATH)
		return

	var geckos: Variant = (parsed as Dictionary).get("geckos", {})

	if typeof(geckos) == TYPE_DICTIONARY:
		_progress = geckos


func _get_record(species: GeckoSpeciesData, level: LevelData) -> Dictionary:
	if species == null or level == null:
		return {}

	var levels: Variant = _progress.get(_species_key(species), {})

	if typeof(levels) != TYPE_DICTIONARY:
		return {}

	var record: Variant = (levels as Dictionary).get(level.get_id(), {})
	return record if typeof(record) == TYPE_DICTIONARY else {}


## Save key of a species: its explicit id, else its resource path or name.
func _species_key(species: GeckoSpeciesData) -> String:
	if not species.species_id.is_empty():
		return species.species_id

	if not species.resource_path.is_empty():
		return species.resource_path.get_file().get_basename()

	return species.species_name.to_snake_case()

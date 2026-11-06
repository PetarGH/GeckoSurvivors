extends Node3D
## Applies the level picked on the level select screen to this terrarium.
## Without a picked level the scene keeps its own defaults, so it still runs
## on its own from the editor.

## Spawner nodes in the order they are used as a level gets harder.
const SPAWNER_NAMES: Array[StringName] = [
	&"Spawner",
	&"Spawner2",
	&"Spawner3",
	&"Spawner4",
]

var level: LevelData


func _ready() -> void:
	level = GameSession.selected_level

	if level == null:
		return

	_apply_spawners(level)
	_apply_environment(level)


## Uses only the first [member LevelData.spawner_count] spawners, each with
## [member LevelData.bugs_per_spawner] bugs. The rest are hidden and idle.
func _apply_spawners(data: LevelData) -> void:
	for index in SPAWNER_NAMES.size():
		var spawner := get_node_or_null(
			NodePath(SPAWNER_NAMES[index])
		) as Node3D

		if spawner == null:
			continue

		var active := index < data.spawner_count
		spawner.visible = active
		spawner.set("spawn_count", data.bugs_per_spawner if active else 0)


func _apply_environment(data: LevelData) -> void:
	var environment := get_node_or_null(
		^"Terrarium/EnvironmentManager"
	) as EnvironmentManager

	if environment == null:
		push_warning("Level: EnvironmentManager not found!")
		return

	environment.temp_decay_min = data.temp_decay_min
	environment.temp_decay_max = data.temp_decay_max
	environment.humidity_decay_min = data.humidity_decay_min
	environment.humidity_decay_max = data.humidity_decay_max

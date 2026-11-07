class_name LevelData
extends Resource
## One playable level for a gecko species: how many bugs appear and how fast
## the terrarium loses its heat and moisture.

@export_group("Identity")
@export_range(1, 99, 1) var level_number: int = 1
@export var level_name: String = "Level"
@export_multiline var description: String = ""


@export_group("Bugs")
@export_range(1, 12, 1) var spawner_count: int = 2
@export_range(1, 50, 1) var bugs_per_spawner_min: int = 3
@export_range(1, 50, 1) var bugs_per_spawner_max: int = 7
@export_range(0.1, 10.0, 0.1) var spawn_interval: float = 2.0


@export_group("Simulation Rates")
@export_range(0.0, 1.0, 0.01) var temp_decay_min: float = 0.05
@export_range(0.0, 1.0, 0.01) var temp_decay_max: float = 0.2
## Degrees per second the heat climbs instead of decaying. 0 keeps the normal
## cooling; level 3 uses this for its heat wave.
@export_range(0.0, 5.0, 0.05) var temp_rise_rate: float = 0.0
@export_range(0.0, 1.0, 0.01) var humidity_decay_min: float = 0.15
@export_range(0.0, 1.0, 0.01) var humidity_decay_max: float = 0.25


@export_group("Scene")
## Scene started when this level is picked.
@export var scene: PackedScene


## Stable key used to store this level's score in the save file.
func get_id() -> String:
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename()
	return "level_%d" % level_number


## Total number of bugs the player has to deal with.
func total_bugs() -> int:
	return spawner_count * bugs_per_spawner_max

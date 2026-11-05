extends "res://scripts/end_screen.gd"
## Shows the win screen once every bug is gone from the terrarium.

const CHECK_INTERVAL: float = 0.25

@export var spawners: Array[Node] = []
@export var gecko: Gecko

var _check_timer: Timer


func _ready() -> void:
	super()

	_check_timer = Timer.new()
	_check_timer.wait_time = CHECK_INTERVAL
	_check_timer.timeout.connect(_check_for_win)

	add_child(_check_timer)
	_check_timer.start()


func _check_for_win() -> void:
	if not _is_run_won():
		return

	_check_timer.stop()
	show_screen()


## Returns true once the spawners are done and no bug is left in the terrarium.
func _is_run_won() -> bool:
	# A dead gecko ends the run on the lose screen instead.
	if gecko != null and not gecko.is_alive():
		return false

	for spawner in spawners:
		if not is_instance_valid(spawner):
			continue

		if not spawner.has_finished_spawning():
			return false

	return _remaining_bug_count() == 0


## Every bug carries exactly one [FoodItem], so counting them counts the bugs.
func _remaining_bug_count() -> int:
	var level := get_tree().current_scene

	if level == null:
		return 0

	return level.find_children("*", "FoodItem", true, false).size()

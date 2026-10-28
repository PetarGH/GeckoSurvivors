extends Node

@export var countdown_timer: Timer
@export var countdown_label: Label

@export var spawners: Array[Node] = []

var countdown: int = 3


func _ready() -> void:
	countdown_label.text = str(countdown)

	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	countdown_timer.timeout.connect(_on_countdown_timer_timeout)
	countdown_timer.start()


func _on_countdown_timer_timeout() -> void:
	countdown -= 1
	countdown_label.text = str(countdown)

	if countdown <= 0:
		countdown_timer.stop()

		for spawner in spawners:
			if is_instance_valid(spawner):
				spawner.start_spawning()

		countdown_label.text = "Go!"

		await get_tree().create_timer(0.5).timeout
		countdown_label.hide()

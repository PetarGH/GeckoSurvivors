
class_name FloatingFeedback
extends Node3D

@export var rise_height: float = 0.8
@export var lifetime: float = 1.0

@onready var amount_label: Label3D = $AmountLabel
@onready var hp_icon: Sprite3D = $HPIcon


func play(
	message: String,
	text_color: Color,
	show_hp_icon: bool = false
) -> void:
	# Configure the text.
	amount_label.text = message
	amount_label.modulate = text_color
	amount_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Configure the HP icon.
	hp_icon.visible = show_hp_icon
	hp_icon.modulate = Color.WHITE
	hp_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Start the floating and fading animation.
	var tween := create_tween().set_parallel(true)

	var start_position: Vector3 = global_position

	tween.tween_property(
		self,
		"global_position",
		start_position + Vector3.UP * rise_height,
		lifetime
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Fade out the text.
	tween.tween_property(
		amount_label,
		"modulate:a",
		0.0,
		lifetime
	).set_delay(0.2)

	# Fade out the HP icon when visible.
	if show_hp_icon:
		tween.tween_property(
			hp_icon,
			"modulate:a",
			0.0,
			lifetime
		).set_delay(0.2)

	# Remove the feedback after the animation finishes.
	tween.finished.connect(queue_free)

extends Node
## Plays the game's sound effects and music.
##
## Every sound effect gets a short-lived [AudioStreamPlayer] of its own, so sounds
## that overlap (two bugs clicked in a row) layer instead of cutting each other
## off. Music keeps a single player, so starting a new track replaces the old one.

## Small tick played by every button the player presses.
const UI_CLICK: AudioStream = preload("res://audio/sfx/ui-button-click.wav")
## Chime played when the player picks their gecko.
const GECKO_SELECTED: AudioStream = preload("res://audio/sfx/ui-gecko-selected.wav")
## Chime played when the player picks a level.
const LEVEL_SELECTED: AudioStream = preload("res://audio/sfx/ui-level-selected.wav")
## Falling notes played when the player leaves a selection screen.
const UI_BACK: AudioStream = preload("res://audio/sfx/ui-back.wav")

## Buttons carrying this meta key play a sound of their own instead of
## [constant UI_CLICK], so picking a card is not a click and a chime at once.
const SILENT_CLICK_META: StringName = &"silent_click"

## Set on buttons that already got the click hook, so a button is only wired once.
const CLICK_HOOK_META: StringName = &"click_sound_hooked"

var _music_player: AudioStreamPlayer


func _ready() -> void:
	# Keep the music going while the end screens hold the game at time_scale 0.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	# Buttons are built in both the scenes and the menu scripts, so hook them as
	# they enter the tree instead of asking every screen to wire its own sound.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is not BaseButton:
		return

	var button := node as BaseButton

	if button.has_meta(CLICK_HOOK_META):
		return

	button.set_meta(CLICK_HOOK_META, true)
	button.pressed.connect(_play_button_click.bind(button))


func _play_button_click(button: BaseButton) -> void:
	if button.has_meta(SILENT_CLICK_META):
		return

	play_sfx(UI_CLICK)


## Plays [param stream] once, layered over whatever is already playing.
func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


## Plays one of [param streams] picked at random, so repeated actions such as
## slapping bugs do not all sound the same.
func play_random_sfx(streams: Array[AudioStream]) -> void:
	if streams.is_empty():
		return

	play_sfx(streams[randi() % streams.size()])


## Starts [param stream] as the music, replacing any track already playing.
func play_music(stream: AudioStream) -> void:
	if stream == null:
		stop_music()
		return

	_music_player.stream = stream
	_music_player.play()


## Stops the music that is currently playing.
func stop_music() -> void:
	_music_player.stop()

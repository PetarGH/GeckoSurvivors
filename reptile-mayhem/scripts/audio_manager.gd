extends Node
## Plays the game's sound effects and music.
##
## Every sound effect gets a short-lived [AudioStreamPlayer] of its own, so sounds
## that overlap (two bugs clicked in a row) layer instead of cutting each other
## off. Music keeps a single player, so starting a new track replaces the old one.

var _music_player: AudioStreamPlayer


func _ready() -> void:
	# Keep the music going while the end screens hold the game at time_scale 0.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)


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

extends Node
## Sets the master and radio volumes and plays a soft tap for every button in the game,
## without any button needing to know about it.

const TAP := "res://assets/audio/tap.wav"
## The whole mix sits this far under the volume slider (owner: still very loud).
const MASTER_HEADROOM_DB := -6.0

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = load(TAP)
	_player.volume_db = -14.0
	add_child(_player)
	SoundBuses.ensure()
	get_tree().node_added.connect(_on_node_added)
	GameSettings.changed.connect(_apply_volume)
	_apply_volume()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(GameSettings.sound_volume) + MASTER_HEADROOM_DB)
	AudioServer.set_bus_mute(0, GameSettings.sound_volume <= 0.0)
	SoundBuses.set_radio_volume(GameSettings.radio_volume)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_tap)
	elif node is TouchButton:
		(node as TouchButton).pressed_down.connect(_tap)


func _tap() -> void:
	_player.play()

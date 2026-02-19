extends Node2D

signal password_completed()

@onready var sequence_detector: Node = $SequenceDetector
@onready var floating_chars_parent: Node2D = $FloatingCharacters
@onready var error_sfx: AudioStreamPlayer = $ErrorSFX
@onready var white_keys_container: Node2D = $WhiteKeys
@onready var black_keys_container: Node2D = $BlackKeys
@onready var password_images_container: Node2D = $PasswordImages

var key_nodes: Dictionary = {}  # key_id -> PianoKey node
var piano_key_scene: PackedScene = preload("res://scenes/piano_key.tscn")
var password_image_scene: PackedScene = preload("res://scenes/password_image.tscn")

var password_solved: bool = false


func _ready() -> void:
	# Open MIDI inputs
	OS.open_midi_inputs()
	var midi_inputs := OS.get_connected_midi_inputs()
	if midi_inputs.size() > 0:
		print("MIDI devices found: ", midi_inputs)
	else:
		print("No MIDI device found. Using keyboard fallback (Z-M lower, Q-I upper).")

	_create_piano_keys()
	_register_all_keys()

	sequence_detector.password_step.connect(_on_password_step)
	sequence_detector.password_completed.connect(_on_password_completed)

	# Load error sound
	var error_path := Config.get_error_sfx_path()
	if ResourceLoader.exists(error_path):
		error_sfx.stream = load(error_path)


func _create_piano_keys() -> void:
	# Create white keys
	var white_index := 0
	for key_id in Config.WHITE_KEY_ORDER:
		var key_instance = piano_key_scene.instantiate()
		key_instance.key_id = key_id
		key_instance.is_black = false
		key_instance.position = Vector2(
			white_index * (Config.WHITE_KEY_WIDTH + Config.KEY_GAP), 0
		)
		white_keys_container.add_child(key_instance)
		white_index += 1

	# Create black keys on top
	for key_id in Config.BLACK_KEY_IDS:
		var key_instance = piano_key_scene.instantiate()
		key_instance.key_id = key_id
		key_instance.is_black = true

		var white_idx: int = Config.BLACK_KEY_AFTER_WHITE[key_id]
		var white_x: float = white_idx * (Config.WHITE_KEY_WIDTH + Config.KEY_GAP)
		key_instance.position = Vector2(
			white_x + Config.WHITE_KEY_WIDTH - Config.BLACK_KEY_WIDTH / 2.0, 0
		)
		black_keys_container.add_child(key_instance)


func _register_all_keys() -> void:
	for key_node in white_keys_container.get_children():
		key_nodes[key_node.key_id] = key_node
	for key_node in black_keys_container.get_children():
		key_nodes[key_node.key_id] = key_node


func _input(event: InputEvent) -> void:
	# Handle MIDI input
	if event is InputEventMIDI:
		_handle_midi(event)
		return

	# Keyboard fallback
	if event is InputEventKey:
		_handle_keyboard(event)


func _handle_midi(event: InputEventMIDI) -> void:
	print("MIDI: note=%d message=%d velocity=%d -> key_id=%d" % [
		event.pitch, event.message, event.velocity,
		Config.midi_to_key_id(event.pitch)
	])

	if not Config.is_valid_midi_note(event.pitch):
		return

	var key_id := Config.midi_to_key_id(event.pitch)

	if event.message == MIDI_MESSAGE_NOTE_ON and event.velocity > 0:
		if key_id in key_nodes:
			key_nodes[key_id].press()
			if not password_solved:
				sequence_detector.record_note(key_id)
	elif event.message == MIDI_MESSAGE_NOTE_OFF or \
		(event.message == MIDI_MESSAGE_NOTE_ON and event.velocity == 0):
		if key_id in key_nodes:
			key_nodes[key_id].release()


func _handle_keyboard(event: InputEventKey) -> void:
	if event.echo:
		return

	var physical_key: int = event.physical_keycode
	if physical_key not in Config.KEYBOARD_TO_KEY_ID:
		return

	var key_id: int = Config.KEYBOARD_TO_KEY_ID[physical_key]

	if event.pressed:
		if key_id in key_nodes:
			key_nodes[key_id].press()
			if not password_solved:
				sequence_detector.record_note(key_id)
	else:
		if key_id in key_nodes:
			key_nodes[key_id].release()


func _on_password_step(_step: int, _key_id: int) -> void:
	# Optional: could add subtle visual feedback per correct step here
	pass


func _on_password_completed() -> void:
	password_solved = true
	_reveal_password_images()
	password_completed.emit()


func _reveal_password_images() -> void:
	# One circle per unique key, revealed in order of first appearance
	var revealed_keys: Dictionary = {}
	var reveal_index: int = 0

	for step in range(Config.password_sequence.size()):
		var key_id: int = Config.password_sequence[step]

		if key_id in revealed_keys:
			continue  # This key already has a circle

		revealed_keys[key_id] = true
		var delay: float = reveal_index * Config.PASSWORD_REVEAL_DELAY
		reveal_index += 1

		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(_spawn_password_circle.bind(key_id))


func _spawn_password_circle(key_id: int) -> void:
	if key_id not in key_nodes:
		return

	var key_node = key_nodes[key_id]
	var circle = password_image_scene.instantiate()
	var circle_size := Vector2(50, 50)

	# Center above the key
	circle.position = key_node.position + Vector2(
		(key_node.size.x - circle_size.x) / 2.0,
		-circle_size.y - 10
	)
	password_images_container.add_child(circle)
	circle.reveal()


func fade_out_all_keys() -> void:
	var tween = create_tween().set_parallel()
	for key_id in key_nodes:
		tween.tween_property(key_nodes[key_id], "modulate:a", 0.0, 2.0)
	await tween.finished
	set_process_input(false)

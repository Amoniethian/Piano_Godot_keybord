extends Node2D

signal correct_sequence_entered(reward_chars: Array)
signal final_sequence_entered(reward_chars: Array)

@onready var sequence_detector: Node = $SequenceDetector
@onready var floating_chars_parent: Node2D = $FloatingCharacters
@onready var error_sfx: AudioStreamPlayer = $ErrorSFX
@onready var white_keys_container: Node2D = $WhiteKeys
@onready var black_keys_container: Node2D = $BlackKeys

var key_nodes: Dictionary = {}  # key_id -> PianoKey node
var floating_char_scene: PackedScene = preload("res://scenes/floating_character.tscn")
var piano_key_scene: PackedScene = preload("res://scenes/piano_key.tscn")


func _ready() -> void:
	_create_piano_keys()
	_register_all_keys()
	sequence_detector.sequence_result.connect(_on_sequence_result)

	# Load error sound
	if ResourceLoader.exists(Config.ERROR_SFX_PATH):
		error_sfx.stream = load(Config.ERROR_SFX_PATH)


func _create_piano_keys() -> void:
	# Create white keys first
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

		# Position: offset from the white key it sits after
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


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.echo:
		return

	var physical_key: int = event.physical_keycode
	if physical_key not in Config.KEYBOARD_TO_KEY_ID:
		return

	var key_id: int = Config.KEYBOARD_TO_KEY_ID[physical_key]

	if event.pressed:
		if key_id in key_nodes:
			key_nodes[key_id].press()
			sequence_detector.record_note(key_id)
	else:
		if key_id in key_nodes:
			key_nodes[key_id].release()


func _on_sequence_result(is_correct: bool, reward_chars: Array) -> void:
	if is_correct:
		if Config.is_final_stage:
			final_sequence_entered.emit(reward_chars)
		else:
			correct_sequence_entered.emit(reward_chars)
	else:
		error_sfx.play()


func spawn_floating_characters(reward_chars: Array) -> void:
	var delay := 0.0
	for entry in reward_chars:
		var target_key_id: int = entry[0]
		var character: String = entry[1]
		if target_key_id in key_nodes:
			# Stagger spawning for sequential reveal effect
			var timer := get_tree().create_timer(delay)
			timer.timeout.connect(
				_spawn_single_character.bind(target_key_id, character)
			)
			delay += 0.3

func _spawn_single_character(target_key_id: int, character: String) -> void:
	var char_instance = floating_char_scene.instantiate()
	var key_node = key_nodes[target_key_id]
	# Position above the key center
	char_instance.position = key_node.global_position + Vector2(
		key_node.size.x / 2.0, -10
	)
	char_instance.display_character = character
	floating_chars_parent.add_child(char_instance)


func fade_out_all_keys() -> void:
	var tween = create_tween().set_parallel()
	for key_id in key_nodes:
		tween.tween_property(key_nodes[key_id], "modulate:a", 0.0, 2.0)
	await tween.finished
	set_process_unhandled_input(false)

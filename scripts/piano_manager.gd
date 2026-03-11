extends Node2D

signal password_completed()
## Emitted every time a piano key is pressed (key_id 0-24).
## MusicTeacherSystem connects to this to route game logic.
signal key_pressed(key_id: int)

@onready var sequence_detector: Node = $SequenceDetector
@onready var floating_chars_parent: Node2D = $FloatingCharacters
@onready var error_sfx: AudioStreamPlayer = $ErrorSFX
@onready var white_keys_container: Node2D = $WhiteKeys
@onready var black_keys_container: Node2D = $BlackKeys
@onready var password_images_container: Node2D = $PasswordImages

var key_nodes: Dictionary = {}  # key_id -> PianoKey node
var piano_key_scene: PackedScene = preload("res://scenes/piano_key.tscn")
var password_image_scene: PackedScene = preload("res://scenes/password_image.tscn")

# Password system is now handled by MusicTeacherSystem.
var password_solved: bool = true

# Android MIDI plugin reference (null on desktop)
var _midi_plugin = null
# True when the plugin is handling MIDI; suppresses InputEventMIDI duplicates.
var _plugin_midi_active: bool = false

# On-screen debug label (created at runtime so no scene changes needed).
var _debug_label: Label = null


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_debug_label()
	_init_midi()
	_create_piano_keys()
	_register_all_keys()

	var error_path := Config.get_error_sfx_path()
	if ResourceLoader.exists(error_path):
		error_sfx.stream = load(error_path)


# ── Debug label (shown on-screen so you can diagnose without logcat) ──────────

func _setup_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.position    = Vector2(0, -165)
	_debug_label.size        = Vector2(1260, 55)
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_debug_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	_debug_label.add_theme_font_size_override("font_size", 15)
	add_child(_debug_label)
	_dbg("MIDI: starting up…")


func _dbg(text: String) -> void:
	print(text)
	if _debug_label:
		_debug_label.text = text


# ── MIDI initialisation ───────────────────────────────────────────────────────

func _init_midi() -> void:
	var platform := OS.get_name()
	_dbg("Platform: " + platform)

	if platform == "Android":
		# ── Path A: custom USB MIDI plugin ──────────────────────────────
		if Engine.has_singleton("GodotMidiUSB"):
			_plugin_midi_active = true
			_midi_plugin = Engine.get_singleton("GodotMidiUSB")
			_midi_plugin.connect("midi_note_on",          _on_android_midi_note_on)
			_midi_plugin.connect("midi_note_off",         _on_android_midi_note_off)
			_midi_plugin.connect("midi_device_connected", _on_android_midi_device_connected)
			_midi_plugin.connect("midi_device_disconnected", _on_android_midi_device_disconnected)
			_midi_plugin.open_midi_devices()
			var devices = _midi_plugin.get_connected_devices()
			if devices.size() > 0:
				_dbg("Plugin: OK | Device: " + str(devices[0]))
			else:
				_dbg("Plugin: OK | No device yet – plug in MIDI keyboard")
		else:
			_dbg("Plugin: NOT FOUND – using built-in MIDI fallback")

		# ── Path B: Godot built-in MIDI (runs alongside plugin as fallback) ──
		# InputEventMIDI is suppressed when the plugin is active (_plugin_midi_active).
		OS.open_midi_inputs()
		var builtins := OS.get_connected_midi_inputs()
		print("Built-in MIDI inputs: ", builtins)

	else:
		# Desktop
		OS.open_midi_inputs()
		var midi_inputs := OS.get_connected_midi_inputs()
		if midi_inputs.size() > 0:
			_dbg("MIDI: " + str(midi_inputs))
		else:
			_dbg("No MIDI device – use Z/X/C/V/B/N/M and Q/W/E/R/T/Y/U/I keys")


# ── Piano key creation ────────────────────────────────────────────────────────

func _create_piano_keys() -> void:
	var white_index := 0
	for key_id in Config.WHITE_KEY_ORDER:
		var key_instance = piano_key_scene.instantiate()
		key_instance.key_id  = key_id
		key_instance.is_black = false
		key_instance.position = Vector2(
			white_index * (Config.WHITE_KEY_WIDTH + Config.KEY_GAP), 0
		)
		white_keys_container.add_child(key_instance)
		white_index += 1

	for key_id in Config.BLACK_KEY_IDS:
		var key_instance = piano_key_scene.instantiate()
		key_instance.key_id  = key_id
		key_instance.is_black = true
		var white_idx: int   = Config.BLACK_KEY_AFTER_WHITE[key_id]
		var white_x: float   = white_idx * (Config.WHITE_KEY_WIDTH + Config.KEY_GAP)
		key_instance.position = Vector2(
			white_x + Config.WHITE_KEY_WIDTH - Config.BLACK_KEY_WIDTH / 2.0, 0
		)
		black_keys_container.add_child(key_instance)


func _register_all_keys() -> void:
	for key_node in white_keys_container.get_children():
		key_nodes[key_node.key_id] = key_node
		key_node.touched_press.connect(_on_key_touched_press)
	for key_node in black_keys_container.get_children():
		key_nodes[key_node.key_id] = key_node
		key_node.touched_press.connect(_on_key_touched_press)


func _on_key_touched_press(pressed_key_id: int) -> void:
	key_pressed.emit(pressed_key_id)


# ── Input routing ─────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMIDI:
		# Skip if the plugin is already handling MIDI (avoids double-trigger).
		if not _plugin_midi_active:
			_handle_midi(event)
		return

	if event is InputEventKey:
		_handle_keyboard(event)


# ── Android MIDI plugin callbacks ─────────────────────────────────────────────

func _on_android_midi_note_on(pitch: int, velocity: int) -> void:
	var key_id := Config.midi_to_key_id_any_octave(pitch)
	_dbg("NoteOn pitch=%d vel=%d → key=%d" % [pitch, velocity, key_id])
	if key_id < 0:
		return
	if key_id in key_nodes:
		key_nodes[key_id].press()
		key_pressed.emit(key_id)


func _on_android_midi_note_off(pitch: int) -> void:
	var key_id := Config.midi_to_key_id_any_octave(pitch)
	if key_id < 0:
		return
	if key_id in key_nodes:
		key_nodes[key_id].release()


func _on_android_midi_device_connected(device_name: String) -> void:
	_dbg("MIDI connected: " + device_name)


func _on_android_midi_device_disconnected(device_name: String) -> void:
	_dbg("MIDI disconnected: " + device_name)


# ── Built-in MIDI (desktop + Android fallback) ────────────────────────────────

func _handle_midi(event: InputEventMIDI) -> void:
	var key_id := Config.midi_to_key_id_any_octave(event.pitch)
	_dbg("MIDI note=%d msg=%d vel=%d → key=%d" % [
		event.pitch, event.message, event.velocity, key_id
	])
	if key_id < 0:
		return
	if event.message == MIDI_MESSAGE_NOTE_ON and event.velocity > 0:
		if key_id in key_nodes:
			key_nodes[key_id].press()
			key_pressed.emit(key_id)
	elif event.message == MIDI_MESSAGE_NOTE_OFF or \
		(event.message == MIDI_MESSAGE_NOTE_ON and event.velocity == 0):
		if key_id in key_nodes:
			key_nodes[key_id].release()


# ── Computer keyboard fallback ────────────────────────────────────────────────

func _handle_keyboard(event: InputEventKey) -> void:
	if event.echo:
		return

	# On Android, physical_keycode is often 0 for USB/BT keyboards.
	var physical_key: int = event.physical_keycode
	if physical_key == 0:
		physical_key = event.keycode

	# Always show what key was pressed so the user can see it on screen.
	if event.pressed:
		_dbg("Key pressed: keycode=%d physical=%d" % [event.keycode, event.physical_keycode])

	if physical_key not in Config.KEYBOARD_TO_KEY_ID:
		return

	var key_id: int = Config.KEYBOARD_TO_KEY_ID[physical_key]

	if event.pressed:
		if key_id in key_nodes:
			key_nodes[key_id].press()
			key_pressed.emit(key_id)
	else:
		if key_id in key_nodes:
			key_nodes[key_id].release()


# ── Legacy password helpers ───────────────────────────────────────────────────

func _on_password_step(_step: int, _key_id: int) -> void:
	pass


func _on_password_completed() -> void:
	password_solved = true
	_reveal_password_images()
	password_completed.emit()


func _reveal_password_images() -> void:
	var revealed_keys: Dictionary = {}
	var reveal_index: int = 0

	for step in range(Config.password_sequence.size()):
		var key_id: int = Config.password_sequence[step]
		if key_id in revealed_keys:
			continue
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
	circle.position = key_node.position + Vector2(
		(key_node.size.x - circle_size.x) / 2.0,
		-circle_size.y - 10
	)
	password_images_container.add_child(circle)
	circle.reveal()


# ── Music Teacher System: final reveal ────────────────────────────────────────

func reveal_final_images(_sequence: Array, _play_order: Array) -> void:
	var piano_width: float = 15.0 * (Config.WHITE_KEY_WIDTH + Config.KEY_GAP)

	var symbol_label := Label.new()
	symbol_label.text = "⊕"
	symbol_label.add_theme_font_size_override("font_size", 200)
	symbol_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol_label.size = Vector2(piano_width, 230)
	symbol_label.position = Vector2(0, -450)
	symbol_label.modulate.a = 0.0
	password_images_container.add_child(symbol_label)

	var code_label := Label.new()
	code_label.text = "1509"
	code_label.add_theme_font_size_override("font_size", 200)
	code_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_label.size = Vector2(piano_width, 230)
	code_label.position = Vector2(0, -210)
	code_label.modulate.a = 0.0
	password_images_container.add_child(code_label)

	var tween := create_tween()
	tween.tween_property(symbol_label, "modulate:a", 1.0, 1.5)
	tween.tween_interval(0.3)
	tween.tween_property(code_label, "modulate:a", 1.0, 1.5)


func fade_out_all_keys() -> void:
	var tween = create_tween().set_parallel()
	for key_id in key_nodes:
		tween.tween_property(key_nodes[key_id], "modulate:a", 0.0, 2.0)
	await tween.finished
	set_process_input(false)

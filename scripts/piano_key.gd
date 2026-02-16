extends Control

@export var key_id: int = 0
@export var is_black: bool = false

@onready var key_visual: ColorRect = $KeyVisual
@onready var pressed_overlay: ColorRect = $PressedOverlay
@onready var note_player: AudioStreamPlayer = $NotePlayer
@onready var key_label: Label = $KeyLabel

var is_pressed: bool = false
var fade_tween: Tween = null

# Normal colors
var normal_color: Color
var pressed_color: Color


func _ready() -> void:
	if is_black:
		normal_color = Color(0.1, 0.1, 0.1)
		pressed_color = Color(0.25, 0.25, 0.3)
		size = Vector2(Config.BLACK_KEY_WIDTH, Config.BLACK_KEY_HEIGHT)
	else:
		normal_color = Color(1.0, 1.0, 1.0)
		pressed_color = Color(0.85, 0.85, 0.95)
		size = Vector2(Config.WHITE_KEY_WIDTH, Config.WHITE_KEY_HEIGHT)

	key_visual.color = normal_color
	key_visual.size = size
	pressed_overlay.size = size
	pressed_overlay.modulate.a = 0.0

	# Set keyboard label
	if key_id >= 0 and key_id < Config.KEY_ID_TO_LABEL.size():
		key_label.text = Config.KEY_ID_TO_LABEL[key_id]
	key_label.size = Vector2(size.x, 30)
	key_label.position = Vector2(0, size.y - 35)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_black:
		key_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	else:
		key_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

	# Load audio file
	var audio_path := Config.get_note_audio_path(key_id)
	if ResourceLoader.exists(audio_path):
		note_player.stream = load(audio_path)
	else:
		push_warning("Audio file not found for key %d: %s" % [key_id, audio_path])


func press() -> void:
	if is_pressed:
		return
	is_pressed = true

	# Visual feedback
	pressed_overlay.modulate.a = 0.3
	key_visual.color = pressed_color

	# Audio: reset volume and play from start
	note_player.volume_db = Config.INITIAL_VOLUME_DB
	note_player.play()

	# Start volume fade while held
	_start_fade()


func release() -> void:
	if not is_pressed:
		return
	is_pressed = false

	# Revert visuals
	pressed_overlay.modulate.a = 0.0
	key_visual.color = normal_color

	# Stop audio and reset
	_stop_fade()
	note_player.stop()
	note_player.volume_db = Config.INITIAL_VOLUME_DB


func _start_fade() -> void:
	_stop_fade()
	fade_tween = create_tween()
	fade_tween.tween_property(
		note_player, "volume_db",
		Config.FADE_TARGET_DB,
		Config.FADE_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _stop_fade() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = null

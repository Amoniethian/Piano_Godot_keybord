extends Node

## MusicTeacherSystem — manages the 3-level piano lesson game loop.
##
## State machine:
##   AMBIENT      → background star_note16 groups + random teacher dialogue
##                  any key press → DEMONSTRATION
##   DEMONSTRATION → chord + voice + note-by-note demo playback
##                  press sequence[0] → PLAYER_INPUT (demo cancelled, first note counted)
##                  press wrong key → FAILURE
##                  demo finishes → PLAYER_INPUT
##   PLAYER_INPUT  → player repeats the sequence; 2s timeout per note
##                  wrong note or timeout → FAILURE
##                  correct sequence → SUCCESS
##   FAILURE       → failure chord, then immediately restart DEMONSTRATION
##   SUCCESS       → success chord, advance level (or FINAL_REVEAL on level 3)
##   FINAL_REVEAL  → password circles revealed + rearranged by play order

enum State { AMBIENT, DEMONSTRATION, PLAYER_INPUT, FAILURE, SUCCESS, FINAL_REVEAL }

# ── References (resolved in _ready) ──────────────────────────────────────────
var piano_manager: Node2D
var dialogue_label: Label
var voice_player: AudioStreamPlayer

# ── State ─────────────────────────────────────────────────────────────────────
var current_state: State = State.AMBIENT
var current_level: int = 0          # 0, 1, 2  (maps to Config.LEVEL_SEQUENCES)
var player_input: Array[int] = []   # notes pressed by player this round
var level3_play_order: Array[int] = []

# ── Ambient music ─────────────────────────────────────────────────────────────
var shuffled_groups: Array = []
var ambient_group_index: int = 0
var ambient_active: bool = false    # set false to stop ambient loop

# ── Demo cancellation ─────────────────────────────────────────────────────────
# Coroutines (_begin_level, _play_demonstration) check this flag at each await.
var demo_cancel_flag: bool = false
# Tracks which key the demo is currently holding (-1 = between notes / not in demo).
var current_demo_note: int = -1

# ── Input timeout ─────────────────────────────────────────────────────────────
# Set true when PLAYER_INPUT begins; cleared before any failure/success.
var input_timeout_active: bool = false


func _ready() -> void:
	piano_manager = get_parent()
	dialogue_label = piano_manager.get_node("DialogueLabel")
	voice_player   = piano_manager.get_node("VoicePlayer")

	piano_manager.key_pressed.connect(_on_key_pressed)

	_start_ambient()


# ── Ambient ───────────────────────────────────────────────────────────────────

func _start_ambient() -> void:
	ambient_active = true
	_reshuffle_groups()
	_run_ambient_loop()
	_schedule_voice_line()


func _stop_ambient() -> void:
	ambient_active = false


func _reshuffle_groups() -> void:
	shuffled_groups = Config.STAR_NOTE_GROUPS.duplicate()
	shuffled_groups.shuffle()
	ambient_group_index = 0


func _run_ambient_loop() -> void:
	while ambient_active:
		await get_tree().create_timer(Config.STAR_NOTE_INTERVAL).timeout
		if not ambient_active:
			break
		await _play_ambient_group()
		ambient_group_index = (ambient_group_index + 1) % shuffled_groups.size()
		if ambient_group_index == 0:
			shuffled_groups.shuffle()


func _play_ambient_group() -> void:
	var group: Array = shuffled_groups[ambient_group_index]
	for key_id in group:
		if key_id in piano_manager.key_nodes:
			piano_manager.key_nodes[key_id].press()
	await get_tree().create_timer(Config.STAR_NOTE_HOLD).timeout
	for key_id in group:
		if key_id in piano_manager.key_nodes:
			piano_manager.key_nodes[key_id].release()


func _schedule_voice_line() -> void:
	var delay: float = randf_range(Config.VOICE_INTERVAL_MIN, Config.VOICE_INTERVAL_MAX)
	await get_tree().create_timer(delay).timeout
	if current_state == State.AMBIENT:
		_show_random_dialogue()
		# Auto-hide after display duration
		await get_tree().create_timer(Config.DIALOGUE_DISPLAY_DURATION).timeout
		if current_state == State.AMBIENT:
			_hide_dialogue()
		_schedule_voice_line()


func _show_random_dialogue() -> void:
	var idx: int = randi() % Config.TEACHER_DIALOGUE.size()
	_show_dialogue(Config.TEACHER_DIALOGUE[idx])
	_try_play_voice_audio(Config.VOICE_AUDIO_DIR + "dialogue_%02d.wav" % (idx + 1))


# ── Key Input Routing ─────────────────────────────────────────────────────────

func _on_key_pressed(key_id: int) -> void:
	match current_state:
		State.AMBIENT:
			_begin_level()
		State.DEMONSTRATION:
			var sequence: Array = Config.LEVEL_SEQUENCES[current_level]
			if key_id == sequence[0]:
				# Player starts the correct sequence early — cancel demo and let them play
				demo_cancel_flag = true
				if current_demo_note != -1 and current_demo_note in piano_manager.key_nodes:
					piano_manager.key_nodes[current_demo_note].release()
				current_demo_note = -1
				_hide_dialogue()
				current_state = State.PLAYER_INPUT
				player_input.clear()
				player_input.append(key_id)
				_start_input_timeout()
			else:
				_trigger_failure()
		State.PLAYER_INPUT:
			_record_player_note(key_id)


# ── Level Start (DEMONSTRATION) ───────────────────────────────────────────────

func _begin_level() -> void:
	_stop_ambient()
	current_state = State.DEMONSTRATION
	demo_cancel_flag = false
	player_input.clear()
	_hide_dialogue()

	# Release any currently held keys
	_release_all_keys()

	# 1. Play intro chord
	await _play_chord(Config.CHORD_INTRO)
	if demo_cancel_flag:
		return

	# 2. Show bilingual voice line (+ optional audio)
	_show_dialogue(Config.VOICE_LISTEN_TEXT)
	_try_play_voice_audio(Config.VOICE_INTRO_AUDIO)
	await get_tree().create_timer(1.5).timeout
	if demo_cancel_flag:
		return

	# 3. Play demonstration sequence
	await _play_demonstration()


func _play_demonstration() -> void:
	var sequence: Array = Config.LEVEL_SEQUENCES[current_level]
	for i in range(sequence.size()):
		if demo_cancel_flag:
			return
		var key_id: int = sequence[i]
		current_demo_note = key_id   # mark which note is active so player can play along
		# Press key (visual + audio)
		if key_id in piano_manager.key_nodes:
			piano_manager.key_nodes[key_id].press()
		await get_tree().create_timer(Config.DEMO_NOTE_HOLD).timeout
		if demo_cancel_flag:
			return
		if key_id in piano_manager.key_nodes:
			piano_manager.key_nodes[key_id].release()
		current_demo_note = -1   # note released — between notes, any press now fails
		# Gap between notes
		var gap: float = Config.DEMO_NOTE_INTERVAL - Config.DEMO_NOTE_HOLD
		if gap > 0.0:
			await get_tree().create_timer(gap).timeout
		if demo_cancel_flag:
			return

	# Demonstration finished normally → await player input
	_hide_dialogue()
	current_state = State.PLAYER_INPUT
	player_input.clear()
	_start_input_timeout()


# ── Player Input ──────────────────────────────────────────────────────────────

func _record_player_note(key_id: int) -> void:
	var sequence: Array = Config.LEVEL_SEQUENCES[current_level]
	var expected_idx: int = player_input.size()

	if expected_idx >= sequence.size():
		return  # safety guard

	if key_id != sequence[expected_idx]:
		_trigger_failure()
		return

	player_input.append(key_id)

	if player_input.size() >= sequence.size():
		_cancel_input_timeout()
		_trigger_success()
	else:
		_cancel_input_timeout()
		_start_input_timeout()


# ── Failure ───────────────────────────────────────────────────────────────────

func _trigger_failure() -> void:
	if current_state == State.FAILURE:
		return
	_cancel_input_timeout()
	demo_cancel_flag = true
	current_demo_note = -1
	current_state = State.FAILURE
	_hide_dialogue()
	_release_all_keys()

	await _play_chord(Config.CHORD_FAILURE)

	# Immediately replay this level's demonstration
	_begin_level()


# ── Success ───────────────────────────────────────────────────────────────────

func _trigger_success() -> void:
	_cancel_input_timeout()
	current_state = State.SUCCESS

	# Save level 3 play order for image rearrangement
	if current_level == 2:
		level3_play_order = player_input.duplicate()

	await _play_chord(Config.CHORD_SUCCESS)

	if current_level < 2:
		current_level += 1
		_begin_level()
	else:
		_begin_final_reveal()


# ── Final Reveal ──────────────────────────────────────────────────────────────

func _begin_final_reveal() -> void:
	current_state = State.FINAL_REVEAL
	piano_manager.reveal_final_images(Config.LEVEL_SEQUENCES[2], level3_play_order)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _release_all_keys() -> void:
	for key_id in piano_manager.key_nodes:
		piano_manager.key_nodes[key_id].release()


func _start_input_timeout() -> void:
	input_timeout_active = true
	await get_tree().create_timer(2.0).timeout
	if input_timeout_active:
		_trigger_failure()


func _cancel_input_timeout() -> void:
	input_timeout_active = false


func _play_chord(notes: Array) -> void:
	for key_id in notes:
		if key_id in piano_manager.key_nodes:
			piano_manager.key_nodes[key_id].press()
	await get_tree().create_timer(Config.CHORD_HOLD_DURATION).timeout
	for key_id in notes:
		if key_id in piano_manager.key_nodes:
			piano_manager.key_nodes[key_id].release()


func _show_dialogue(text: String) -> void:
	if dialogue_label:
		dialogue_label.text = text
		dialogue_label.visible = true


func _hide_dialogue() -> void:
	if dialogue_label:
		dialogue_label.visible = false


func _try_play_voice_audio(path: String) -> void:
	if voice_player and ResourceLoader.exists(path):
		voice_player.stream = load(path)
		voice_player.play()

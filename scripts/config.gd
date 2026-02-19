extends Node

## Central configuration singleton for the Virtual Piano.
## Now configured for MIDI keyboard (AKAI LPK25 - 25 keys).
## Edit the values below to customize piano and password.

# ======================================================
# --- Note Definitions (25 keys: C3 to C5) ---
# ======================================================
const NOTE_NAMES: Array[String] = [
	"C3", "C#3", "D3", "D#3", "E3", "F3", "F#3", "G3",
	"G#3", "A3", "A#3", "B3", "C4", "C#4", "D4", "D#4",
	"E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", "C5"
]

const TOTAL_KEYS: int = 25

# ======================================================
# --- MIDI Mapping ---
# ======================================================
# Base MIDI note number for the lowest key on your MIDI keyboard.
# AKAI LPK25 default: C3 = MIDI 48. Adjust if octave is shifted.
var midi_base_note: int = 48

func midi_to_key_id(midi_note: int) -> int:
	return midi_note - midi_base_note

func is_valid_midi_note(midi_note: int) -> bool:
	var key_id := midi_to_key_id(midi_note)
	return key_id >= 0 and key_id < TOTAL_KEYS

# ======================================================
# --- Key Layout ---
# ======================================================
# Which key_ids are black keys
const BLACK_KEY_IDS: Array[int] = [1, 3, 6, 8, 10, 13, 15, 18, 20, 22]

# White keys in display order (left to right)
const WHITE_KEY_ORDER: Array[int] = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24]

# Maps black key_id -> white key index it sits to the right of
const BLACK_KEY_AFTER_WHITE: Dictionary = {
	1: 0,    # C#3 after C3
	3: 1,    # D#3 after D3
	6: 3,    # F#3 after F3
	8: 4,    # G#3 after G3
	10: 5,   # A#3 after A3
	13: 7,   # C#4 after C4
	15: 8,   # D#4 after D4
	18: 10,  # F#4 after F4
	20: 11,  # G#4 after G4
	22: 12,  # A#4 after A4
}

# ======================================================
# --- Audio ---
# ======================================================
const NOTE_AUDIO_DIR: String = "res://audio/notes/"
const ERROR_SFX_DIR: String = "res://audio/sfx/"
const SUPPORTED_AUDIO_EXTENSIONS: Array[String] = [".wav", ".ogg"]

func get_note_audio_path(key_id: int) -> String:
	var padded_id := str(key_id + 1).pad_zeros(2)
	var safe_name := NOTE_NAMES[key_id].replace("#", "s")
	var base := NOTE_AUDIO_DIR + "note_" + padded_id + "_" + safe_name
	return _find_audio_file(base)

func get_error_sfx_path() -> String:
	return _find_audio_file(ERROR_SFX_DIR + "error")

func _find_audio_file(base_path: String) -> String:
	for ext in SUPPORTED_AUDIO_EXTENSIONS:
		var path := base_path + ext
		if ResourceLoader.exists(path):
			return path
	return base_path + ".wav"

# ======================================================
# --- PASSWORD SYSTEM ---
# ======================================================
# The password is a sequence of key_ids the player must play in order.
#
# Key ID reference (for easy password editing):
#   0=C3   1=C#3  2=D3   3=D#3  4=E3   5=F3   6=F#3
#   7=G3   8=G#3  9=A3  10=A#3 11=B3  12=C4  13=C#4
#  14=D4  15=D#4 16=E4  17=F4  18=F#4 19=G4  20=G#4
#  21=A4  22=A#4 23=B4  24=C5
#
# Current password: Twinkle Twinkle Little Star first 9 notes
# C  C  G  G  A  A  G  F  F
var password_sequence: Array[int] = [0, 0, 7, 7, 9, 9, 7, 5, 5]

# Password images directory
# Place images named password_01.png, password_02.png, ... password_09.png
const PASSWORD_IMAGE_DIR: String = "res://images/password/"

func get_password_image_path(step: int) -> String:
	var padded := str(step + 1).pad_zeros(2)
	var base := PASSWORD_IMAGE_DIR + "password_" + padded
	for ext: String in [".png", ".jpg", ".webp"]:
		var path: String = base + ext
		if ResourceLoader.exists(path):
			return path
	return base + ".png"

# Time between each image reveal (seconds)
const PASSWORD_REVEAL_DELAY: float = 0.5
# Size of revealed password images
const PASSWORD_IMAGE_SIZE: Vector2 = Vector2(80, 80)

# --- Final Stage Config ---
var is_final_stage: bool = false
const FINAL_VIDEO_PATH: String = "res://video/final_video.ogv"

# ======================================================
# --- Visual Config ---
# ======================================================
const WHITE_KEY_WIDTH: int = 80
const WHITE_KEY_HEIGHT: int = 300
const BLACK_KEY_WIDTH: int = 44
const BLACK_KEY_HEIGHT: int = 185
const KEY_GAP: int = 3

# --- Sound Fade Config ---
const INITIAL_VOLUME_DB: float = 0.0
const FADE_TARGET_DB: float = -25.0
const FADE_DURATION: float = 4.0

# ======================================================
# --- Keyboard Fallback (for testing without MIDI) ---
# ======================================================
# Two-row piano layout on QWERTY keyboard
const KEYBOARD_TO_KEY_ID: Dictionary = {
	# Lower octave white keys (Z row)
	KEY_Z: 0,   # C3
	KEY_X: 2,   # D3
	KEY_C: 4,   # E3
	KEY_V: 5,   # F3
	KEY_B: 7,   # G3
	KEY_N: 9,   # A3
	KEY_M: 11,  # B3
	# Lower octave black keys (S/D/G/H/J)
	KEY_S: 1,   # C#3
	KEY_D: 3,   # D#3
	KEY_G: 6,   # F#3
	KEY_H: 8,   # G#3
	KEY_J: 10,  # A#3
	# Upper octave white keys (Q row)
	KEY_Q: 12,  # C4
	KEY_W: 14,  # D4
	KEY_E: 16,  # E4
	KEY_R: 17,  # F4
	KEY_T: 19,  # G4
	KEY_Y: 21,  # A4
	KEY_U: 23,  # B4
	# Upper octave black keys (number row)
	KEY_2: 13,  # C#4
	KEY_3: 15,  # D#4
	KEY_5: 18,  # F#4
	KEY_6: 20,  # G#4
	KEY_7: 22,  # A#4
	# Highest note
	KEY_I: 24,  # C5
}

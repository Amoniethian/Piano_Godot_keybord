extends Node

## Central configuration singleton for the Virtual Piano.
## Registered as Autoload "Config" in project.godot.
## Edit the values below to customize the piano behavior.

# --- Note Definitions ---
# 16 keys covering C4 to D#5 (two octaves from middle C)
const NOTE_NAMES: Array[String] = [
	"C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4",
	"G#4", "A4", "A#4", "B4", "C5", "C#5", "D5", "D#5"
]

# --- Keyboard Mapping ---
# Maps physical keyboard key to key_id (0-15)
# Uses physical_keycode so layout doesn't matter
const KEYBOARD_TO_KEY_ID: Dictionary = {
	KEY_A: 0,   # C4  (white)
	KEY_W: 1,   # C#4 (black)
	KEY_S: 2,   # D4  (white)
	KEY_E: 3,   # D#4 (black)
	KEY_D: 4,   # E4  (white)
	KEY_F: 5,   # F4  (white)
	KEY_T: 6,   # F#4 (black)
	KEY_G: 7,   # G4  (white)
	KEY_Y: 8,   # G#4 (black)
	KEY_H: 9,   # A4  (white)
	KEY_U: 10,  # A#4 (black)
	KEY_J: 11,  # B4  (white)
	KEY_K: 12,  # C5  (white)
	KEY_O: 13,  # C#5 (black)
	KEY_L: 14,  # D5  (white)
	KEY_P: 15,  # D#5 (black)
}

# Reverse mapping: key_id -> keyboard key name (for labels)
const KEY_ID_TO_LABEL: Array[String] = [
	"A", "W", "S", "E", "D", "F", "T", "G",
	"Y", "H", "U", "J", "K", "O", "L", "P"
]

# --- Which keys are black ---
const BLACK_KEY_IDS: Array[int] = [1, 3, 6, 8, 10, 13, 15]

# --- White key indices (maps key_id to position among white keys) ---
# key_id -> white_key_index: 0=C4, 2=D4, 4=E4, 5=F4, 7=G4, 9=A4, 11=B4, 12=C5, 14=D5
const WHITE_KEY_ORDER: Array[int] = [0, 2, 4, 5, 7, 9, 11, 12, 14]

# --- Black key positioning ---
# Maps black key_id to the white key index it sits to the right of
const BLACK_KEY_AFTER_WHITE: Dictionary = {
	1: 0,   # C#4 after C4 (white index 0)
	3: 1,   # D#4 after D4 (white index 1)
	6: 3,   # F#4 after F4 (white index 3)
	8: 4,   # G#4 after G4 (white index 4)
	10: 5,  # A#4 after A4 (white index 5)
	13: 7,  # C#5 after C5 (white index 7)
	15: 8,  # D#5 after D5 (white index 8)
}

# --- Audio file paths ---
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
	# Fallback: return .wav path so caller can handle missing file
	return base_path + ".wav"

# --- Sequence Detection Config ---
const SEQUENCE_LENGTH: int = 6

# The correct 6-note sequence as key_ids (0-indexed)
# EDIT THIS to change the puzzle solution
var correct_sequence: Array[int] = [0, 4, 7, 0, 4, 7]  # C4, E4, G4, C4, E4, G4

# Characters to display when correct sequence is entered
# Each entry: [key_id, character]
var reward_characters: Array = [
	[0, "H"], [4, "E"], [7, "L"], [0, "L"], [4, "O"], [7, "!"]
]

# --- Final Stage Config ---
var is_final_stage: bool = false
const FINAL_VIDEO_PATH: String = "res://video/final_video.ogv"

# --- Visual Config ---
const WHITE_KEY_WIDTH: int = 80
const WHITE_KEY_HEIGHT: int = 300
const BLACK_KEY_WIDTH: int = 50
const BLACK_KEY_HEIGHT: int = 190
const KEY_GAP: int = 4

# --- Sound Fade Config ---
const INITIAL_VOLUME_DB: float = 0.0
const FADE_TARGET_DB: float = -25.0
const FADE_DURATION: float = 4.0

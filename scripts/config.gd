extends Node

## Central configuration singleton for the Virtual Piano.
## Now configured for MIDI keyboard (AKAI LPK25 - 25 keys).
## Edit the values below to customize piano and password.

# ======================================================
# --- Note Definitions (25 keys: C4 to C6) ---
# ======================================================
const NOTE_NAMES: Array[String] = [
	"C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4",
	"G#4", "A4", "A#4", "B4", "C5", "C#5", "D5", "D#5",
	"E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5", "C6"
]

const TOTAL_KEYS: int = 25

# ======================================================
# --- MIDI Mapping ---
# ======================================================
# Base MIDI note number for the lowest key on your MIDI keyboard.
# AKAI LPK25 with octave+1: C4 = MIDI 60. Adjust if octave is shifted.
var midi_base_note: int = 60

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
	1: 0,    # C#4 after C4
	3: 1,    # D#4 after D4
	6: 3,    # F#4 after F4
	8: 4,    # G#4 after G4
	10: 5,   # A#4 after A4
	13: 7,   # C#5 after C5
	15: 8,   # D#5 after D5
	18: 10,  # F#5 after F5
	20: 11,  # G#5 after G5
	22: 12,  # A#5 after A5
}

# ======================================================
# --- Tone Generation (fallback when no audio samples) ---
# ======================================================
func midi_note_to_frequency(midi_note: int) -> float:
	return 440.0 * pow(2.0, (midi_note - 69.0) / 12.0)

func generate_note_tone(key_id: int) -> AudioStreamWAV:
	var midi_note: int = key_id + midi_base_note
	var freq: float = midi_note_to_frequency(midi_note)
	return _generate_piano_tone(freq)

func _generate_piano_tone(frequency: float, duration: float = 2.0) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var num_samples: int = int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var envelope: float = exp(-t * 3.0)
		# Fundamental + harmonics for richer piano-like tone
		var sample_val: float = 0.0
		sample_val += sin(TAU * frequency * t) * 1.0
		sample_val += sin(TAU * frequency * 2.0 * t) * 0.5
		sample_val += sin(TAU * frequency * 3.0 * t) * 0.25
		sample_val *= envelope * 0.2
		var sample_16: int = clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = sample_16 & 0xFF
		data[i * 2 + 1] = (sample_16 >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

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
#   0=C4   1=C#4  2=D4   3=D#4  4=E4   5=F4   6=F#4
#   7=G4   8=G#4  9=A4  10=A#4 11=B4  12=C5  13=C#5
#  14=D5  15=D#5 16=E5  17=F5  18=F#5 19=G5  20=G#5
#  21=A5  22=A#5 23=B5  24=C6
#
# Current password: D#4 D4 E4 C4 C4 D4 A4 F5 B4
var password_sequence: Array[int] = [3, 2, 4, 0, 0, 2, 9, 17, 11]

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
	KEY_Z: 0,   # C4
	KEY_X: 2,   # D4
	KEY_C: 4,   # E4
	KEY_V: 5,   # F4
	KEY_B: 7,   # G4
	KEY_N: 9,   # A4
	KEY_M: 11,  # B4
	# Lower octave black keys (S/D/G/H/J)
	KEY_S: 1,   # C#4
	KEY_D: 3,   # D#4
	KEY_G: 6,   # F#4
	KEY_H: 8,   # G#4
	KEY_J: 10,  # A#4
	# Upper octave white keys (Q row)
	KEY_Q: 12,  # C5
	KEY_W: 14,  # D5
	KEY_E: 16,  # E5
	KEY_R: 17,  # F5
	KEY_T: 19,  # G5
	KEY_Y: 21,  # A5
	KEY_U: 23,  # B5
	# Upper octave black keys (number row)
	KEY_2: 13,  # C#5
	KEY_3: 15,  # D#5
	KEY_5: 18,  # F#5
	KEY_6: 20,  # G#5
	KEY_7: 22,  # A#5
	# Highest note
	KEY_I: 24,  # C6
}

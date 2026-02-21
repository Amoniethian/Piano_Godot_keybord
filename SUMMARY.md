# Piano Godot Keyboard — Developer Quick Reference

## Project Overview
Godot 4.3 virtual piano (25 keys, C4–C6) with MIDI + keyboard support.
Now includes a 3-level music teacher game system.

---

## Key IDs (0–24)
```
 0=C4   1=C#4  2=D4   3=D#4  4=E4   5=F4   6=F#4
 7=G4   8=G#4  9=A4  10=A#4 11=B4  12=C5  13=C#5
14=D5  15=D#5 16=E5  17=F5  18=F#5 19=G5  20=G#5
21=A5  22=A#5 23=B5  24=C6
```

---

## Files & Responsibilities

| File | Purpose |
|---|---|
| `scripts/config.gd` | Autoload singleton — all constants, mappings, audio paths |
| `scripts/piano_manager.gd` | Creates keys, routes input, emits `key_pressed`, handles final reveal |
| `scripts/piano_key.gd` | Individual key: `press()` / `release()`, audio + visual |
| `scripts/music_teacher_system.gd` | **NEW** — game state machine (ambient → demo → input → success/fail) |
| `scripts/password_image.gd` | Gray circle above key: `reveal()`, `animate_to(pos)` |
| `scripts/sequence_detector.gd` | Legacy password detector (bypassed; `password_solved = true`) |
| `scripts/main.gd` | Scene root: connects password_completed for optional video ending |
| `scripts/video_player_overlay.gd` | Final stage video fade-in playback |
| `scenes/main.tscn` | Main scene — all nodes wired here |

---

## Music Teacher Game States

```
AMBIENT
  │  (any key press)
  ▼
DEMONSTRATION  ←──────────────────────────────────┐
  │  (demo finishes)     │ (player presses key)   │
  ▼                      ▼                         │
PLAYER_INPUT          FAILURE ──► _play_chord(CHORD_FAILURE)
  │  (wrong note)        │                         │
  ├──────────────────────┘                         │
  │  (correct sequence)                            │
  ▼                                                │
SUCCESS ──► _play_chord(CHORD_SUCCESS)             │
  │  (level < 3: advance level) ──────────────────►┘
  │  (level 3 done)
  ▼
FINAL_REVEAL
```

**Level reset after failure:** immediately replays DEMONSTRATION (no ambient pause).

---

## Config Constants (config.gd)

### star_note16 ambient groups
```gdscript
Config.STAR_NOTE_GROUPS   # Array[Array] — 6 groups × 3 key_ids
```
Groups: C major, F major, G major, ascending, descending, rising-skip.

### Level sequences
```gdscript
Config.LEVEL_SEQUENCES[0]  # Level 1: [0,4,7,5,4,2]       6 notes
Config.LEVEL_SEQUENCES[1]  # Level 2: [0,2,4,5,7,9,11,12,14] 9 notes
Config.LEVEL_SEQUENCES[2]  # Level 3: [3,2,4,0,0,2,9,17,11] 9 notes
```

### Chords
```gdscript
Config.CHORD_INTRO    # [0,4,7,12]       C major + octave
Config.CHORD_SUCCESS  # [0,4,7,12,16]    C major extended
Config.CHORD_FAILURE  # [1,4,6]          Dissonant cluster
```

### Timing
```gdscript
Config.DEMO_NOTE_INTERVAL   = 0.5   # s between demo notes
Config.DEMO_NOTE_HOLD       = 0.3   # s each note held in demo
Config.STAR_NOTE_INTERVAL   = 2.0   # s between ambient groups
Config.STAR_NOTE_HOLD       = 0.25  # s each ambient note held
Config.VOICE_INTERVAL_MIN   = 10.0  # s (min) between dialogue lines
Config.VOICE_INTERVAL_MAX   = 15.0  # s (max) between dialogue lines
Config.CHORD_HOLD_DURATION  = 1.0   # s chords are held
Config.DIALOGUE_DISPLAY_DURATION = 5.0  # s label stays visible
```

### Dialogue / Voice
```gdscript
Config.TEACHER_DIALOGUE   # Array[String] — 5 bilingual placeholder lines
Config.VOICE_LISTEN_TEXT  # "听好了，跟上我的示范\nListen carefully..."
```

---

## Audio File Conventions

| Type | Path pattern | Notes |
|---|---|---|
| Piano notes | `res://audio/notes/note_NN_NAME.wav` | Generated if absent |
| Error SFX | `res://audio/sfx/error.wav` | Optional |
| Intro voice | `res://audio/voice/intro_listen.wav` | Played at demo start |
| Dialogue N | `res://audio/voice/dialogue_01.wav` … `dialogue_05.wav` | 5 lines |

If an audio file is **absent**, only the text label is shown; playback is silently skipped.

---

## Key Signals

```gdscript
# piano_manager.gd
signal key_pressed(key_id: int)   # emitted on every key press (MIDI or keyboard)
signal password_completed()        # legacy (not used in new flow)
```

---

## Key Functions

### piano_manager.gd
```gdscript
reveal_final_images(sequence: Array, play_order: Array) -> void
    # Reveals circles sorted by key_id, then rearranges to play_order after 1 s.

fade_out_all_keys() -> void
    # Fades all keys to transparent (used before final video).
```

### music_teacher_system.gd
```gdscript
_begin_level() -> void          # chord → voice → demonstration
_play_demonstration() -> void   # plays sequence note by note; checks demo_cancel_flag
_record_player_note(key_id)     # validates player input against current level sequence
_trigger_failure() -> void      # failure chord → _begin_level()
_trigger_success() -> void      # success chord → next level or final reveal
_begin_final_reveal() -> void   # calls piano_manager.reveal_final_images()
_start_ambient() -> void        # starts ambient loop + voice schedule
_stop_ambient() -> void         # stops ambient loop (called when level starts)
```

### password_image.gd
```gdscript
reveal() -> void                       # fade-in animation (alpha 0→1, 0.4 s)
animate_to(target_pos: Vector2) -> void  # move to new position (0.5 s ease-in-out)
```

---

## Scene Node Tree (main.tscn)
```
Main (Node2D)
├── Background (ColorRect)
├── PianoManager (Node2D) @position (332, 500)
│   ├── WhiteKeys (Node2D)
│   ├── BlackKeys (Node2D)
│   ├── SequenceDetector (Node)   ← bypassed; password_solved=true
│   ├── FloatingCharacters (Node2D)
│   ├── PasswordImages (Node2D)   ← circles spawned here
│   ├── ErrorSFX (AudioStreamPlayer)
│   ├── MusicTeacherSystem (Node) ← NEW game loop
│   ├── DialogueLabel (Label)     ← NEW bilingual text, y=-130, 1260×70
│   └── VoicePlayer (AudioStreamPlayer) ← NEW reserved audio player
└── VideoPlayerOverlay (ColorRect)
    └── VideoStreamPlayer
```

---

## Keyboard Fallback Map
```
White (lower): Z=C4 X=D4 C=E4 V=F4 B=G4 N=A4 M=B4
Black (lower): S=C#4 D=D#4 G=F#4 H=G#4 J=A#4
White (upper): Q=C5 W=D5 E=E5 R=F5 T=G5 Y=A5 U=B5
Black (upper): 2=C#5 3=D#5 5=F#5 6=G#5 7=A#5
Highest:       I=C6
```

---

## How to Modify Level Sequences
Edit `Config.LEVEL_SEQUENCES` in `scripts/config.gd`:
```gdscript
const LEVEL_SEQUENCES: Array = [
    [/* Level 1: 6 key_ids */],
    [/* Level 2: 9 key_ids */],
    [/* Level 3: 9 key_ids */],
]
```

## How to Replace Dialogue Lines
Edit `Config.TEACHER_DIALOGUE` in `scripts/config.gd` (keep bilingual format):
```gdscript
const TEACHER_DIALOGUE: Array[String] = [
    "Chinese line\nEnglish line",
    ...
]
```

## How to Add Voice Audio
Place `.wav` or `.ogg` files at the paths listed in the **Audio File Conventions** table above.
No code change needed — the system auto-loads if the file exists.

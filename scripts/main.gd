extends Node2D

@onready var piano_manager: Node2D = $PianoManager
@onready var video_overlay = $VideoPlayerOverlay


func _ready() -> void:
	piano_manager.correct_sequence_entered.connect(_on_correct_sequence)
	piano_manager.final_sequence_entered.connect(_on_final_sequence)


func _on_correct_sequence(reward_chars: Array) -> void:
	piano_manager.spawn_floating_characters(reward_chars)


func _on_final_sequence(reward_chars: Array) -> void:
	piano_manager.spawn_floating_characters(reward_chars)
	await get_tree().create_timer(2.5).timeout
	await piano_manager.fade_out_all_keys()
	video_overlay.play_video()

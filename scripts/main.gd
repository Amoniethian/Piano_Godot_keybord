extends Node2D

@onready var piano_manager: Node2D = $PianoManager
@onready var video_overlay = $VideoPlayerOverlay


func _ready() -> void:
	piano_manager.password_completed.connect(_on_password_completed)


func _on_password_completed() -> void:
	# Password is solved - images are being revealed by piano_manager.
	# Player can now freely play the piano.
	if Config.is_final_stage:
		# Wait for all images to reveal, then proceed to video
		var total_reveal_time: float = \
			Config.password_sequence.size() * Config.PASSWORD_REVEAL_DELAY + 2.0
		await get_tree().create_timer(total_reveal_time).timeout
		await piano_manager.fade_out_all_keys()
		video_overlay.play_video()

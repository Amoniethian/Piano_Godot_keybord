extends ColorRect

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ResourceLoader.exists(Config.FINAL_VIDEO_PATH):
		video_player.stream = load(Config.FINAL_VIDEO_PATH)


func play_video() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fade in black overlay
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.5)
	await tween.finished

	# Start video
	video_player.play()
	video_player.finished.connect(_on_video_finished)


func _on_video_finished() -> void:
	pass

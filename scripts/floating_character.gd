extends Label

var display_character: String = "?"

const FLOAT_DISTANCE: float = -200.0
const FLOAT_DURATION: float = 2.0
const FONT_SIZE: int = 64


func _ready() -> void:
	text = display_character
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pivot_offset = size / 2.0

	# Animate: float up and fade out
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y + FLOAT_DISTANCE, FLOAT_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, FLOAT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	tween.chain().tween_callback(queue_free)

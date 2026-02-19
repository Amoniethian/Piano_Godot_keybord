extends Control

## A single password image that fades in and stays visible.

var step_index: int = 0

@onready var texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	modulate.a = 0.0
	size = Config.PASSWORD_IMAGE_SIZE
	texture_rect.size = Config.PASSWORD_IMAGE_SIZE

	# Load password image for this step
	var image_path := Config.get_password_image_path(step_index)
	if ResourceLoader.exists(image_path):
		texture_rect.texture = load(image_path)


func reveal() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

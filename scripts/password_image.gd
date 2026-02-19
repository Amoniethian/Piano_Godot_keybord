extends Control

## A gray circle indicator that appears above a password key.

const CIRCLE_RADIUS: float = 25.0
const CIRCLE_COLOR: Color = Color(0.5, 0.5, 0.5, 1.0)


func _ready() -> void:
	modulate.a = 0.0
	size = Vector2(CIRCLE_RADIUS * 2, CIRCLE_RADIUS * 2)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(CIRCLE_RADIUS, CIRCLE_RADIUS), CIRCLE_RADIUS, CIRCLE_COLOR)


func reveal() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

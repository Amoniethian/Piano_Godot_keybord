extends Node

## Step-by-step password sequence detector.
## Tracks which step the player is on and advances when correct notes are played.
## Wrong notes silently reset the sequence.

signal password_step(step: int, key_id: int)
signal password_completed()

var current_step: int = 0


func record_note(key_id: int) -> void:
	var expected: int = Config.password_sequence[current_step]

	if key_id == expected:
		# Correct note for current step
		password_step.emit(current_step, key_id)
		current_step += 1

		if current_step >= Config.password_sequence.size():
			# All steps completed - password solved!
			password_completed.emit()
			current_step = 0
	else:
		# Wrong note - reset, but check if it matches the first step
		current_step = 0
		if key_id == Config.password_sequence[0]:
			password_step.emit(0, key_id)
			current_step = 1


func reset() -> void:
	current_step = 0

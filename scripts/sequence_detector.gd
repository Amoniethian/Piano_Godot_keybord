extends Node

signal sequence_result(is_correct: bool, reward_chars: Array)

var note_buffer: Array[int] = []


func record_note(key_id: int) -> void:
	note_buffer.append(key_id)

	if note_buffer.size() >= Config.SEQUENCE_LENGTH:
		_check_sequence()


func _check_sequence() -> void:
	var last_n: Array[int] = []
	for i in range(Config.SEQUENCE_LENGTH):
		last_n.append(note_buffer[note_buffer.size() - Config.SEQUENCE_LENGTH + i])

	var is_correct: bool = (last_n == Config.correct_sequence)

	if is_correct:
		sequence_result.emit(true, Config.reward_characters)
	else:
		sequence_result.emit(false, [])

	note_buffer.clear()


func reset() -> void:
	note_buffer.clear()

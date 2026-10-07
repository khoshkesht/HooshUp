extends AudioStreamPlayer
class_name ChatTypingSound

func _ready() -> void:
	var typing_stream := stream as AudioStreamMP3
	if typing_stream != null:
		typing_stream.loop = true

func start_typing() -> void:
	if stream == null:
		return
	# Restart from a predictable audible point for every player message.
	stop()
	play()

func stop_typing() -> void:
	stop()

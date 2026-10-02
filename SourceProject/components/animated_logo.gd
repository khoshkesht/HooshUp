extends Node2D

signal activated

@export_range(0.05, 5.0, 0.05, "suffix:s") var frame_duration := 0.5

const FRAMES: Array[Texture2D] = [
	preload("res://assets/pics/ui/logo/logo1.png"),
	preload("res://assets/pics/ui/logo/logo7.png"),
	preload("res://assets/pics/ui/logo/logo2.png"),
	preload("res://assets/pics/ui/logo/logo3.png"),
	preload("res://assets/pics/ui/logo/logo4.png"),
	preload("res://assets/pics/ui/logo/logo5.png"),
	preload("res://assets/pics/ui/logo/logo8.png"),
	preload("res://assets/pics/ui/logo/logo6.png"),
]

@onready var visible_layer: Sprite2D = $VisibleLayer
@onready var incoming_layer: Sprite2D = $IncomingLayer

func _process(delta: float) -> void:
	rotation += PI * delta / (frame_duration * FRAMES.size())

func _ready() -> void:
	visible_layer.texture = FRAMES[0]
	visible_layer.modulate.a = 1.0
	incoming_layer.modulate.a = 0.0
	play_loop()

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if visible_layer.get_rect().has_point(to_local(event.position)):
		get_viewport().set_input_as_handled()
		activated.emit()

func play_loop() -> void:
	var frame_index := 0
	while true:
		var next_index := (frame_index + 1) % FRAMES.size()
		incoming_layer.texture = FRAMES[next_index]
		incoming_layer.modulate.a = 0.0

		var fade := create_tween().set_parallel(true)
		fade.tween_property(visible_layer, "modulate:a", 0.0, frame_duration)
		fade.tween_property(incoming_layer, "modulate:a", 1.0, frame_duration)
		await fade.finished

		var previous_layer := visible_layer
		visible_layer = incoming_layer
		incoming_layer = previous_layer
		frame_index = next_index

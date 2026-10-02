extends Node

const MAP_SCENE := "res://scenes/map.tscn"
const SPLASH_TEXTURE := preload("res://assets/pics/ui/hoosh-up.png")
const SPLASH_DURATION_SECONDS := 2.0

func _ready() -> void:
	show_splash_and_open_initial_scene()

func show_splash_and_open_initial_scene() -> void:
	var splash_layer := CanvasLayer.new()
	splash_layer.layer = 100
	add_child(splash_layer)
	var splash := TextureRect.new()
	splash.name = "Splash"
	splash.layout_direction = Control.LAYOUT_DIRECTION_LTR
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.texture = SPLASH_TEXTURE
	splash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	splash.mouse_filter = Control.MOUSE_FILTER_STOP
	splash_layer.add_child(splash)
	await get_tree().create_timer(SPLASH_DURATION_SECONDS).timeout
	get_tree().change_scene_to_file(MAP_SCENE)

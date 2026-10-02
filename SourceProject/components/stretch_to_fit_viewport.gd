extends Control
class_name StretchToFitViewport

@onready var scene_image: TextureRect = $SceneImage

var scene_zoom := 1.0
var is_dragging := false
var press_position := Vector2.ZERO
var did_pan := false

const TAP_DRAG_THRESHOLD := 12.0

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_STOP
	scene_image.layout_direction = Control.LAYOUT_DIRECTION_LTR
	scene_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene_image.stretch_mode = TextureRect.STRETCH_SCALE

func show_scene(texture: Texture2D, zoom_amount := 1.0) -> void:
	scene_image.texture = texture
	scene_zoom = zoom_amount
	call_deferred("apply_zoom")
	show()

func apply_zoom() -> void:
	scene_image.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var scene_scale := ResponsiveLayout.cover_scale(size) * scene_zoom
	scene_image.size = ResponsiveLayout.DESIGN_SIZE * scene_scale
	reset_view()

func reset_view() -> void:
	scene_image.position = ResponsiveLayout.centered_position(size, scene_image.size, 1.0)
	clamp_scene_position()

func clamp_scene_position() -> void:
	var minimum_position := size - scene_image.size
	scene_image.position.x = clamp(scene_image.position.x, minimum_position.x, 0.0)
	scene_image.position.y = clamp(scene_image.position.y, minimum_position.y, 0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			press_position = event.position
			did_pan = false
		else:
			is_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and is_dragging:
		if event.position.distance_to(press_position) >= TAP_DRAG_THRESHOLD:
			did_pan = true
		scene_image.position += event.relative
		clamp_scene_position()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			press_position = event.position
			did_pan = false
		else:
			is_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and is_dragging:
		if event.position.distance_to(press_position) >= TAP_DRAG_THRESHOLD:
			did_pan = true
		scene_image.position += event.relative
		clamp_scene_position()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(scene_image):
		call_deferred("apply_zoom")

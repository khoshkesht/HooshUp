extends Control
class_name PanZoomViewport

signal world_tapped(world_position: Vector2)

# The world is authored on the 1280x720 canvas.  Keep its base transform as
# cover; any extra zoom would move authored hotspots away from their scene
# landmarks on non-16:9 displays.
@export_range(1.0, 2.0, 0.05) var zoom := 1.0

const TAP_DRAG_THRESHOLD := 12.0

@onready var world: Control = $World

var is_dragging := false
var pan_enabled := true
var press_position := Vector2.ZERO
var did_pan := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	world.layout_direction = Control.LAYOUT_DIRECTION_LTR
	world.set_anchors_preset(Control.PRESET_TOP_LEFT)
	world.size = ResponsiveLayout.DESIGN_SIZE
	call_deferred("reset_view")

func reset_view() -> void:
	var zoom_amount := zoom if pan_enabled else 1.0
	var world_scale := ResponsiveLayout.cover_scale(size) * zoom_amount
	world.scale = Vector2.ONE * world_scale
	world.position = ResponsiveLayout.centered_position(size, ResponsiveLayout.DESIGN_SIZE, world_scale)
	clamp_world_position()

func set_pan_enabled(enabled: bool) -> void:
	pan_enabled = enabled
	is_dragging = false
	if not pan_enabled:
		reset_view()

func _gui_input(event: InputEvent) -> void:
	if not pan_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			press_position = event.position
			did_pan = false
		else:
			if is_dragging and not did_pan:
				world_tapped.emit(get_world_position(event.position))
			is_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and is_dragging:
		if event.position.distance_to(press_position) >= TAP_DRAG_THRESHOLD:
			did_pan = true
		world.position += event.relative
		clamp_world_position()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			press_position = event.position
			did_pan = false
		else:
			if is_dragging and not did_pan:
				world_tapped.emit(get_world_position(event.position))
			is_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and is_dragging:
		if event.position.distance_to(press_position) >= TAP_DRAG_THRESHOLD:
			did_pan = true
		world.position += event.relative
		clamp_world_position()
		accept_event()

func get_world_position(viewport_position: Vector2) -> Vector2:
	return (viewport_position - world.position) / world.scale

func clamp_world_position() -> void:
	var minimum_position := size - world.size * world.scale.x
	world.position.x = clamp(world.position.x, minimum_position.x, 0.0)
	world.position.y = clamp(world.position.y, minimum_position.y, 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_instance_valid(world):
		call_deferred("reset_view")

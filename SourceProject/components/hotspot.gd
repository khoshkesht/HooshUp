extends Control
class_name Hotspot

signal activated

@export_range(12.0, 100.0, 1.0, "suffix:px") var radius := 22.0
@export_range(1.0, 10.0, 0.1, "suffix:s") var pulse_duration := 2.6
@export_range(0.0, 1.0, 0.01) var minimum_alpha := 0.45
@export_range(0.0, 1.0, 0.01) var maximum_alpha := 0.95

var elapsed := 0.0
var alerting := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = Vector2.ONE * radius * 2.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if alerting:
		queue_redraw()
		return
	var phase := (sin(elapsed * TAU / pulse_duration) + 1.0) * 0.5
	modulate.a = lerp(minimum_alpha, maximum_alpha, phase)

func set_alerting(value: bool) -> void:
	alerting = value
	modulate.a = 1.0
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	if alerting:
		var flash := (sin(elapsed * TAU / 0.7) + 1.0) * 0.5
		draw_circle(center, radius + 10.0, Color(0.2, 0.75, 1.0, 0.12 + flash * 0.18))
		draw_circle(center, radius + 4.0, Color(0.35, 0.88, 1.0, 0.3 + flash * 0.35))
		draw_circle(center, radius * 0.62, Color(0.92, 0.98, 1.0, 0.55 + flash * 0.4))
		return
	draw_circle(center, radius + 8.0, Color(1.0, 0.72, 0.12, 0.14))
	draw_circle(center, radius + 3.0, Color(1.0, 0.78, 0.2, 0.35))
	draw_circle(center, radius, Color(0.96, 0.66, 0.08, 0.95))
	draw_circle(center, radius * 0.6, Color(1.0, 0.87, 0.38, 0.9))

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activated.emit()
		accept_event()

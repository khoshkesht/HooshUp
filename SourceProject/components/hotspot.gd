extends Control
class_name Hotspot

signal activated

@export_range(12.0, 100.0, 1.0, "suffix:px") var radius := 22.0
@export_range(1.0, 10.0, 0.1, "suffix:s") var pulse_duration := 2.6
@export_range(0.0, 1.0, 0.01) var minimum_alpha := 0.45
@export_range(0.0, 1.0, 0.01) var maximum_alpha := 0.95
@export_range(0.0, 1.0, 0.01) var initial_alpha := 0.3
@export_range(0.0, 5.0, 0.1, "suffix:s") var initial_alpha_duration := 2.0

var elapsed := 0.0
var alerting := false
var forced_alpha := -1.0
var forced_alpha_remaining := 0.0
var initial_reveal_started := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = Vector2.ONE * radius * 2.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("start_initial_reveal_if_visible")
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if forced_alpha_remaining > 0.0:
		forced_alpha_remaining = maxf(0.0, forced_alpha_remaining - delta)
		modulate.a = forced_alpha
		if forced_alpha_remaining <= 0.0 and alerting:
			modulate.a = 1.0
		return
	if alerting:
		modulate.a = 1.0
		queue_redraw()
		return
	var phase := (sin(elapsed * TAU / pulse_duration) + 1.0) * 0.5
	modulate.a = lerp(minimum_alpha, maximum_alpha, phase)

func set_alerting(value: bool) -> void:
	alerting = value
	if forced_alpha_remaining <= 0.0:
		modulate.a = 1.0
	queue_redraw()

func _on_visibility_changed() -> void:
	start_initial_reveal_if_visible()

func start_initial_reveal_if_visible() -> void:
	if initial_reveal_started or not is_visible_in_tree():
		return
	initial_reveal_started = true
	show_at_alpha_for(initial_alpha, initial_alpha_duration)

func show_at_alpha_for(alpha: float, duration_seconds: float) -> void:
	forced_alpha = clampf(alpha, 0.0, 1.0)
	forced_alpha_remaining = maxf(0.0, duration_seconds)
	modulate.a = forced_alpha

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

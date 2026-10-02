extends Control

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	queue_redraw()

func _draw() -> void:
	var bubble := Rect2(Vector2(3, 4), size - Vector2(6, 12))
	draw_style_box(make_bubble_style(), bubble)
	var tail := PackedVector2Array([Vector2(15, size.y - 10), Vector2(10, size.y - 2), Vector2(25, size.y - 10)])
	draw_colored_polygon(tail, Color.WHITE)
	draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2]]), Color(0.08, 0.1, 0.14, 1.0), 2.0)
	var dot_y := size.y * 0.5
	for dot_x in [size.x * 0.34, size.x * 0.5, size.x * 0.66]:
		draw_circle(Vector2(dot_x, dot_y), 3.2, Color(0.08, 0.1, 0.14, 1.0))

func make_bubble_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.78, 0.2, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.08, 0.1, 0.14, 1.0)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	return style

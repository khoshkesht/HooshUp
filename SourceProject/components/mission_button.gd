class_name MissionButton
extends Button

# سطح لمس بزرگ‌تر می‌شود؛ اندازه و رسم دکمهٔ هنری عوض نمی‌شود.
func get_touch_rect() -> Rect2:
	var padding := (Vector2(72, 72) - size).max(Vector2.ZERO) * 0.5
	return Rect2(-padding, size + padding * 2)

func _has_point(point: Vector2) -> bool:
	return get_touch_rect().has_point(point)

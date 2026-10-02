class_name ResponsiveLayout
extends RefCounted

# All authored world and UI coordinates use this landscape design canvas.
const DESIGN_SIZE := Vector2(1280.0, 720.0)

static func cover_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return maxf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)

static func contain_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)

static func centered_position(viewport_size: Vector2, content_size: Vector2, content_scale: float) -> Vector2:
	return (viewport_size - content_size * content_scale) * 0.5

static func safe_origin(viewport_size: Vector2) -> Vector2:
	var scale := contain_scale(viewport_size)
	return centered_position(viewport_size, DESIGN_SIZE, scale)

static func design_to_safe(viewport_size: Vector2, design_position: Vector2) -> Vector2:
	var scale := contain_scale(viewport_size)
	return safe_origin(viewport_size) + design_position * scale

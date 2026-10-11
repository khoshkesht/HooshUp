class_name MobileUiRoot
extends Control

signal safe_area_changed(rect: Rect2)

const UI_THEME := preload("res://assets/themes/mobile_ui.tres")
const HUD_LAYER := 10
const OVERLAY_LAYER := 20
const DIAGNOSTICS_LAYER := 30
const SAFE_PADDING := Vector2(32, 24)
const REFRESH_INTERVAL := 0.25

var safe_area: Control
var safe_margin: MarginContainer
var safe_rect := Rect2()
var safe_area_source := "window"
# پیش‌نمایش بریدگی فقط در اجرای Debug دسکتاپ؛ مختصات فیزیکی نمایشگر.
var preview_display_safe_rect := Rect2()
var _refresh_elapsed := 0.0

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	theme = UI_THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area = Control.new()
	safe_area.name = "SafeArea"
	safe_area.layout_direction = Control.LAYOUT_DIRECTION_LTR
	safe_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe_area)
	safe_margin = MarginContainer.new()
	safe_margin.name = "SafeMargin"
	safe_margin.layout_direction = Control.LAYOUT_DIRECTION_LTR
	safe_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		safe_margin.add_theme_constant_override("margin_" + side, int(SAFE_PADDING.x))
	for side in ["top", "bottom"]:
		safe_margin.add_theme_constant_override("margin_" + side, int(SAFE_PADDING.y))
	safe_area.add_child(safe_margin)
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(refresh_safe_area)
	refresh_safe_area()

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= REFRESH_INTERVAL:
		_refresh_elapsed = 0.0
		refresh_safe_area()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(safe_area):
		call_deferred("refresh_safe_area")

func refresh_safe_area() -> void:
	if not is_instance_valid(safe_area) or size.x <= 0 or size.y <= 0:
		return
	var next_rect := Rect2(Vector2.ZERO, size)
	safe_area_source = "window"
	var display_rect := Rect2()
	if OS.has_feature("android") or OS.has_feature("ios"):
		display_rect = Rect2(DisplayServer.get_display_safe_area())
		safe_area_source = "device"
	elif OS.is_debug_build() and preview_display_safe_rect.has_area():
		display_rect = preview_display_safe_rect
		safe_area_source = "preview"
	if display_rect.has_area():
		var converted := display_rect_to_local(self, display_rect)
		if converted.has_area():
			next_rect = converted
		else:
			safe_area_source = "fallback"
	elif safe_area_source == "device":
		safe_area_source = "fallback"
	if next_rect == safe_rect:
		return
	safe_rect = next_rect
	safe_area.position = safe_rect.position
	safe_area.size = safe_rect.size
	safe_area_changed.emit(safe_rect)

static func display_rect_to_local(root: Control, display_rect: Rect2) -> Rect2:
	var screen_transform := root.get_screen_transform()
	if is_zero_approx(screen_transform.determinant()):
		return Rect2()
	var local_rect: Rect2 = screen_transform.affine_inverse() * display_rect
	return local_rect.intersection(Rect2(Vector2.ZERO, root.size))

func get_content_rect() -> Rect2:
	var content_size := (safe_rect.size - SAFE_PADDING * 2).max(Vector2.ZERO)
	return Rect2(safe_rect.position + SAFE_PADDING, content_size)

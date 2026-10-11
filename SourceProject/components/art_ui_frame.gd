class_name ArtUiFrame
extends Control

# قاب هنری ثابت می‌ماند؛ Container نسبت تصویر و Anchor هندسهٔ کنترل‌ها را حفظ می‌کنند.
var canvas_size := Vector2(1280, 720)
var maximum_size := Vector2(1800, 1012.5)
var alignment := Vector2(0.5, 0.5)
var ui_root: MobileUiRoot
var safe_host: Control
var aspect: AspectRatioContainer
var artwork: Control
var animation_offset := Vector2.ZERO:
	set(value):
		animation_offset = value
		refresh_layout()

static func wrap(owner: Node, image: Control, design: Vector2, maximum: Vector2, align := Vector2(0.5, 0.5)) -> ArtUiFrame:
	var frame := ArtUiFrame.new()
	frame.name = image.name + "Layout"
	frame.canvas_size = design
	frame.maximum_size = maximum
	frame.alignment = align
	owner.add_child(frame)
	image.reparent(frame.aspect, false)
	image.scale = Vector2.ONE
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.artwork = image
	frame.refresh_layout()
	return frame

static func anchor(control: Control, rect: Rect2, design: Vector2) -> void:
	control.layout_direction = Control.LAYOUT_DIRECTION_LTR
	control.anchor_left = rect.position.x / design.x
	control.anchor_top = rect.position.y / design.y
	control.anchor_right = rect.end.x / design.x
	control.anchor_bottom = rect.end.y / design.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0

static func anchor_children(parent: Control, design: Vector2, font_ratio := 1.0) -> void:
	for child in parent.get_children():
		if child is Control:
			var rect := Rect2(child.position, child.size)
			anchor(child, rect, design)
			if child is Label or child is Button or child is LineEdit:
				child.add_theme_font_size_override("font_size", roundi(child.get_theme_font_size("font_size") * font_ratio))

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is MobileUiRoot:
			ui_root = ancestor
			break
		ancestor = ancestor.get_parent()
	safe_host = Control.new()
	safe_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe_host)
	var box := VBoxContainer.new()
	box.layout_direction = Control.LAYOUT_DIRECTION_LTR
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER if alignment.y == 0.5 else BoxContainer.ALIGNMENT_BEGIN
	safe_host.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect = AspectRatioContainer.new()
	aspect.layout_direction = Control.LAYOUT_DIRECTION_LTR
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.ratio = canvas_size.x / canvas_size.y
	aspect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if alignment.x == 0.5 else Control.SIZE_SHRINK_BEGIN
	box.add_child(aspect)
	resized.connect(refresh_layout)
	if ui_root != null:
		ui_root.safe_area_changed.connect(_on_safe_area_changed)
	refresh_layout()

func refresh_layout() -> void:
	if safe_host == null:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	if ui_root != null:
		bounds = get_global_transform().affine_inverse() * (ui_root.get_global_transform() * ui_root.get_content_rect())
		bounds = bounds.intersection(Rect2(Vector2.ZERO, size))
	safe_host.position = bounds.position + animation_offset
	safe_host.size = bounds.size
	var available := bounds.size.min(maximum_size)
	var ratio := minf(available.x / canvas_size.x, available.y / canvas_size.y)
	aspect.custom_minimum_size = canvas_size * maxf(0, ratio)

func _on_safe_area_changed(_rect: Rect2) -> void:
	refresh_layout()

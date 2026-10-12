class_name MissionUiSurface
extends Control

# هندسهٔ قاب موجود نسبی می‌شود؛ زوم محیط و Scale ریشه در UI دخالت ندارند.
var frame: ArtUiFrame
var design_size := Vector2.ZERO
var content: Control
var metrics: Array[Dictionary] = []
var image_canvas: Control
var source_image: Control

static func mount(host: MobileUiRoot, artwork: Control, design: Vector2) -> MissionUiSurface:
	var surface := MissionUiSurface.new()
	surface.name = artwork.name + "Surface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.design_size = design
	var canvas := Control.new()
	canvas.name = "ArtCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = design
	surface.add_child(canvas)
	var rect := Rect2(artwork.position, artwork.size)
	artwork.reparent(canvas, false)
	ArtUiFrame.anchor(artwork, rect, design)
	surface.content = artwork
	surface.register_children(artwork)
	surface.frame = ArtUiFrame.wrap(surface, canvas, design, Vector2(1800, 1012.5))
	canvas.resized.connect(surface.refresh_metrics)
	artwork.tree_exiting.connect(surface.queue_free)
	surface.refresh_metrics()
	return surface

static func mount_on_image(host: MobileUiRoot, artwork: Control, image: Control) -> MissionUiSurface:
	var surface := MissionUiSurface.new()
	surface.name = artwork.name + "Surface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.design_size = image.size
	surface.source_image = image
	var canvas := Control.new()
	canvas.name = "ImageCanvas"
	canvas.layout_direction = Control.LAYOUT_DIRECTION_LTR
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = image.size
	surface.add_child(canvas)
	surface.image_canvas = canvas
	var rect := Rect2(artwork.position, artwork.size)
	artwork.reparent(canvas, false)
	ArtUiFrame.anchor(artwork, rect, surface.design_size)
	surface.content = artwork
	surface.register_children(artwork)
	canvas.resized.connect(surface.refresh_metrics)
	artwork.tree_exiting.connect(surface.queue_free)
	surface.sync_image_geometry()
	return surface

func _process(_delta: float) -> void:
	if source_image != null:
		sync_image_geometry()

func sync_image_geometry() -> void:
	if not is_instance_valid(source_image) or not is_instance_valid(image_canvas):
		return
	var image_to_viewport := source_image.get_global_transform_with_canvas()
	var viewport_to_surface := get_global_transform_with_canvas().affine_inverse()
	var image_rect := viewport_to_surface * (image_to_viewport * Rect2(Vector2.ZERO, source_image.size))
	image_canvas.position = image_rect.position
	image_canvas.size = image_rect.size

func register_children(parent: Control) -> void:
	for child in parent.get_children():
		if child is Control:
			register_control(child, parent)
	if not parent.child_entered_tree.is_connected(_on_child_entered):
		parent.child_entered_tree.connect(_on_child_entered)

func register_control(control: Control, parent: Control) -> void:
	if control.has_meta("mission_ui_registered") or parent.size.x <= 0 or parent.size.y <= 0:
		return
	if control is Label and control.autowrap_mode != TextServer.AUTOWRAP_OFF and not parent is Container:
		var scroll := scroll_text(control)
		register_control(scroll, parent)
		return
	control.set_meta("mission_ui_registered", true)
	var ratio := current_ratio()
	var metric := {"control": control, "pivot": control.pivot_offset / ratio}
	if control is Label or control is Button:
		metric["font"] = control.get_theme_font_size("font_size") / ratio
		if control is Label:
			control.clip_text = false
	if not parent is Container:
		ArtUiFrame.anchor(control, Rect2(control.position, control.size), parent.size)
	metrics.append(metric)
	register_children(control)

func _on_child_entered(child: Node) -> void:
	# سازنده ابتدا هندسه و متن را تنظیم می‌کند؛ سپس Anchor ثبت می‌شود.
	if child is Control:
		call_deferred("_register_new_child", child)

func _register_new_child(child: Variant) -> void:
	if is_instance_valid(child) and child.is_inside_tree() and is_ancestor_of(child):
		register_control(child, child.get_parent() as Control)
		refresh_metrics()

func current_ratio() -> float:
	if image_canvas != null:
		return maxf(0.01, image_canvas.size.y / design_size.y)
	if frame == null or not is_instance_valid(frame.artwork):
		return 1.0
	return maxf(0.01, frame.artwork.size.y / design_size.y)

func refresh_metrics() -> void:
	var ratio := current_ratio()
	for metric in metrics:
		if not is_instance_valid(metric.control):
			continue
		var control: Control = metric.control
		control.pivot_offset = metric.pivot * ratio
		if metric.has("font"):
			control.add_theme_font_size_override("font_size", maxi(1, roundi(metric.font * ratio)))

static func scroll_text(label: Label) -> ScrollContainer:
	var parent := label.get_parent()
	var scroll := ScrollContainer.new()
	scroll.name = label.name + "Scroll"
	scroll.layout_direction = Control.LAYOUT_DIRECTION_LTR
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(scroll)
	scroll.position = label.position
	scroll.size = label.size
	label.reparent(scroll, false)
	label.position = Vector2.ZERO
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	# علامت و عنوان تک‌خطی نوار تازه‌ای روی گرافیک ایجاد نمی‌کنند.
	label.minimum_size_changed.connect(func() -> void:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if label.get_line_count() > 1 else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if label.get_line_count() > 1 else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	return scroll

class_name BadgesPanel
extends Control

signal closed

const BACKGROUND_TEXTURE := preload("res://assets/pics/ui/menu-blank.png")
const LOCKED_BADGE_SHADER := preload("res://shaders/badge_locked.gdshader")
const DESIGN_SIZE := Vector2(1672, 941)
# The badge artwork is larger than the shared 1280x720 UI canvas. Keep its
# authored coordinates, then fit it to that same canvas as the global menu.
const PANEL_BASE_SCALE := ResponsiveLayout.DESIGN_SIZE.y / DESIGN_SIZE.y
const BADGES_PER_ROW := 4
const BADGE_CELL_SIZE := Vector2(320, 305)
const BADGES_VIEWPORT_POSITION := Vector2(130, 215)
const BADGES_VIEWPORT_SIZE := Vector2(1412, 615)
const BADGES := [
	{"title": "هوش باز", "file": "badge-01-open-intelligence.png"},
	{"title": "مهندس پرامپت", "file": "badge-02-prompt-engineer.png"},
	{"title": "سرنخ یاب", "file": "badge-03-clue-finder.png"},
	{"title": "معمار پاسخ", "file": "badge-04-answer-architect.png"},
	{"title": "هم‌کلاسی هوشمند", "file": "badge-05-smart-classmate.png"},
	{"title": "جرقه‌ساز", "file": "badge-06-spark-maker.png"},
	{"title": "شکارچی خطا", "file": "badge-07-error-hunter.png"},
	{"title": "ردیاب حقیقت", "file": "badge-08-truth-tracker.png"},
	{"title": "نگهبان داده", "file": "badge-09-data-guardian.png"},
	{"title": "فرمانده هوشمند", "file": "badge-10-ai-commander.png"}
]

var background: TextureRect
var content: Control
var badge_grid: Control

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_page()
	resized.connect(refresh_layout)
	refresh_layout()
	hide()

func open_badges() -> void:
	refresh_badges()
	show()

func build_page() -> void:
	background = TextureRect.new()
	background.name = "BadgesBackground"
	background.layout_direction = Control.LAYOUT_DIRECTION_LTR
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = DESIGN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	content = Control.new()
	content.name = "BadgesContent"
	content.layout_direction = Control.LAYOUT_DIRECTION_LTR
	content.size = DESIGN_SIZE
	content.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(content)
	add_label("Title", "نشان‌ها", Vector2(570, 67), Vector2(532, 76), 50, Color("f5deb0"))
	add_label("Subtitle", "نشان‌های به‌دست‌آمده در مسیر یادگیری", Vector2(470, 140), Vector2(732, 45), 26, Color("d1e9f2"))
	add_close_button()
	build_badges()
	refresh_badges()

func build_badges() -> void:
	var scroll_container := ScrollContainer.new()
	scroll_container.name = "BadgesScroll"
	scroll_container.layout_direction = Control.LAYOUT_DIRECTION_LTR
	scroll_container.position = BADGES_VIEWPORT_POSITION
	scroll_container.size = BADGES_VIEWPORT_SIZE
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(scroll_container)

	badge_grid = Control.new()
	badge_grid.name = "BadgeGrid"
	badge_grid.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var row_count := ceili(float(BADGES.size()) / BADGES_PER_ROW)
	badge_grid.size = Vector2(BADGES_VIEWPORT_SIZE.x, row_count * BADGE_CELL_SIZE.y)
	badge_grid.custom_minimum_size = badge_grid.size
	scroll_container.add_child(badge_grid)

	for index in BADGES.size():
		var stage_number := index + 1
		var column := index % BADGES_PER_ROW
		var row := index / BADGES_PER_ROW
		var center := Vector2(
			(BADGES_VIEWPORT_SIZE.x - BADGES_PER_ROW * BADGE_CELL_SIZE.x) * 0.5 + (column + 0.5) * BADGE_CELL_SIZE.x,
			(row + 0.5) * BADGE_CELL_SIZE.y
		)
		var badge_data: Dictionary = BADGES[index]
		var badge := TextureRect.new()
		badge.name = "Badge%d" % stage_number
		badge.layout_direction = Control.LAYOUT_DIRECTION_LTR
		badge.texture = load("res://assets/pics/badges/%s" % str(badge_data.get("file", ""))) as Texture2D
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.position = center - Vector2(108, 118)
		badge.size = Vector2(216, 216)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_grid.add_child(badge)
		var caption := add_badge_label("BadgeTitle%d" % stage_number, str(badge_data.get("title", "")), center + Vector2(-132, 115), Vector2(264, 45), 25, Color("eff6ff"))
		caption.tooltip_text = "مرحله %s" % to_persian_digits(stage_number)

func refresh_badges() -> void:
	if not is_instance_valid(content):
		return
	for stage_number in range(1, BADGES.size() + 1):
		var unlocked := ProgressStore.has_stage_badge(stage_number)
		var badge := badge_grid.get_node_or_null("Badge%d" % stage_number) as TextureRect
		var caption := badge_grid.get_node_or_null("BadgeTitle%d" % stage_number) as Label
		if badge != null:
			badge.material = null
			if not unlocked:
				var material := ShaderMaterial.new()
				material.shader = LOCKED_BADGE_SHADER
				badge.material = material
		if caption != null:
			caption.add_theme_color_override("font_color", Color("eff6ff") if unlocked else Color("9aa6ad"))

func refresh_layout() -> void:
	if not is_instance_valid(background):
		return
	var scale_factor := ResponsiveLayout.contain_scale(size) * PANEL_BASE_SCALE
	var origin := ResponsiveLayout.safe_origin(size)
	background.position = origin
	background.scale = Vector2.ONE * scale_factor
	content.position = origin
	content.scale = Vector2.ONE * scale_factor

func add_label(node_name: String, text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return label

func add_close_button() -> void:
	var button := Button.new()
	button.name = "CloseButton"
	button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	button.text_direction = Control.TEXT_DIRECTION_RTL
	button.text = "بازگشت"
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.position = Vector2(1412, 82)
	button.size = Vector2(132, 46)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("eff6ff"))
	button.add_theme_stylebox_override("normal", make_button_style(Color("25445e"), Color("78bed0")))
	button.add_theme_stylebox_override("hover", make_button_style(Color("31617a"), Color("a1e1ed")))
	button.pressed.connect(close_badges)
	content.add_child(button)

func add_badge_label(node_name: String, text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_grid.add_child(label)
	return label

func make_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style

func close_badges() -> void:
	hide()
	closed.emit()

func to_persian_digits(value: int) -> String:
	var result := str(value)
	var persian_digits := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for digit in 10:
		result = result.replace(str(digit), persian_digits[digit])
	return result

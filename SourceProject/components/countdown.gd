class_name Countdown
extends Control

signal finished

const BACKGROUND_TEXTURE := preload("res://assets/pics/ui/countdown.png")

@export var display_size := Vector2(72, 72)

var number_label: Label
var timer: Timer
var remaining_seconds := 0
var is_running := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = display_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := TextureRect.new()
	background.layout_direction = Control.LAYOUT_DIRECTION_LTR
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	number_label = Label.new()
	number_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	number_label.text_direction = Control.TEXT_DIRECTION_LTR
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.add_theme_color_override("font_color", Color("9f2630"))
	number_label.add_theme_font_size_override("font_size", 27)
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(number_label)
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func start(duration_seconds: int) -> void:
	remaining_seconds = maxi(duration_seconds, 0)
	is_running = true
	refresh_number()
	if remaining_seconds == 0:
		finish()
		return
	timer.start()

func stop() -> void:
	is_running = false
	if is_instance_valid(timer):
		timer.stop()

func place_bottom_right(parent_size: Vector2, margin := Vector2(24, 24)) -> void:
	position = parent_size - size - margin

func _on_timer_timeout() -> void:
	remaining_seconds -= 1
	refresh_number()
	if remaining_seconds <= 0:
		finish()

func finish() -> void:
	if not is_running:
		return
	stop()
	finished.emit()

func refresh_number() -> void:
	number_label.text = to_persian_digits(remaining_seconds)

func to_persian_digits(value: int) -> String:
	var result := str(value)
	var persian_digits := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for digit in 10:
		result = result.replace(str(digit), persian_digits[digit])
	return result

extends Control
class_name PhoneMessageOverlay

signal closed

@onready var phone: TextureRect = $Phone
@onready var screen: Control = $Phone/Screen
@onready var notch: Panel = $Phone/Notch
@onready var status: Label = $Phone/Screen/Status
@onready var conversation_title: Label = $Phone/Screen/ConversationTitle
@onready var message_bubble: Control = $Phone/Screen/MessageBubble
@onready var message_text: Label = $Phone/Screen/MessageBubble/MessageText
@onready var close_button: Button = $Phone/Screen/CloseButton

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	for label in [conversation_title, message_text]:
		label.layout_direction = Control.LAYOUT_DIRECTION_LTR
		label.text_direction = Control.TEXT_DIRECTION_RTL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.layout_direction = Control.LAYOUT_DIRECTION_LTR
	status.text_direction = Control.TEXT_DIRECTION_LTR
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	close_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	close_button.text_direction = Control.TEXT_DIRECTION_RTL
	close_button.pressed.connect(close_message)
	resized.connect(refresh_layout)
	hide()

func show_message(message: String, close_text := "بستن") -> void:
	message_text.text = message
	close_button.text = close_text
	show()
	refresh_layout()

func close_message() -> void:
	hide()
	closed.emit()

func refresh_layout() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var phone_height := viewport_size.y * 0.85
	var phone_width := minf(phone_height * 0.55, viewport_size.x * 0.45)
	phone.size = Vector2(phone_width, phone_height)
	phone.position = Vector2(viewport_size.x * 0.75 - phone_width * 0.5, (viewport_size.y - phone_height) * 0.5)
	screen.position = Vector2.ZERO
	screen.size = phone.size
	var scale_factor := phone_height / 612.0
	status.position = Vector2(screen.size.x * 0.10, screen.size.y * 0.052)
	status.size = Vector2(screen.size.x * 0.22, 24.0 * scale_factor)
	status.add_theme_font_size_override("font_size", roundi(15.0 * scale_factor))
	conversation_title.position = Vector2(screen.size.x * 0.31, screen.size.y * 0.105)
	conversation_title.size = Vector2(screen.size.x * 0.25, 42.0 * scale_factor)
	conversation_title.add_theme_font_size_override("font_size", roundi(20.0 * scale_factor))
	message_bubble.position = Vector2(screen.size.x * 0.29, screen.size.y * 0.24)
	message_bubble.size = Vector2(screen.size.x * 0.62, screen.size.y * 0.35)
	message_text.position = Vector2(14.0 * scale_factor, 12.0 * scale_factor)
	message_text.size = message_bubble.size - Vector2(28.0, 24.0) * scale_factor
	message_text.add_theme_font_size_override("font_size", roundi(19.0 * scale_factor))
	close_button.size = Vector2(screen.size.x * 0.36, 40.0 * scale_factor)
	close_button.position = Vector2((screen.size.x - close_button.size.x) * 0.5, screen.size.y * 0.68)
	close_button.add_theme_font_size_override("font_size", roundi(18.0 * scale_factor))

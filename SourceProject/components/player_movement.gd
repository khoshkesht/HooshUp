extends Node
class_name PlayerMovement

var player: AnimatedSprite2D
var is_walking := false

var player_data: Dictionary
var canvas_size := Vector2.ZERO
var visual_size := Vector2.ZERO
var base_scale := Vector2.ONE
var ground_contact_offset_y := 0.0
var move_area_image: Image
var asset_path_resolver: Callable
var avatar_asset_path_resolver: Callable

func configure(configuration: Dictionary, visual_parent: Node, new_canvas_size: Vector2, background_texture: Texture2D, move_area_texture: Texture2D, new_asset_path_resolver: Callable, new_avatar_asset_path_resolver: Callable) -> bool:
	player_data = configuration
	canvas_size = new_canvas_size
	asset_path_resolver = new_asset_path_resolver
	avatar_asset_path_resolver = new_avatar_asset_path_resolver
	ground_contact_offset_y = float(player_data.get("ground_contact_offset_y", 0.0))
	if move_area_texture != null:
		move_area_image = move_area_texture.get_image()
		if background_texture == null or move_area_image.get_width() != background_texture.get_width() or move_area_image.get_height() != background_texture.get_height():
			if background_texture == null:
				push_error("Move-area mask requires a background texture.")
				move_area_image = null
			else:
				move_area_image.resize(background_texture.get_width(), background_texture.get_height(), Image.INTERPOLATE_NEAREST)
	return create_player(visual_parent)

func move_to_requested_position(requested_position: Vector2) -> void:
	if is_walking or move_area_image == null:
		return
	var target_position := get_last_walkable_target(requested_position)
	if target_position == Vector2.INF or target_position.distance_to(get_normalized_position()) < 0.001:
		return
	await move_to_normalized_position([target_position.x, target_position.y])

func move_to_normalized_position(normalized_target: Array, requested_animation := "") -> void:
	if not is_instance_valid(player) or normalized_target.size() < 2:
		return
	is_walking = true
	var start_position := player.position
	var target_position := get_player_position(normalized_target)
	var walk_speed := float(player_data.get("walk_speed", 300.0))
	var duration := maxf(0.45, start_position.distance_to(target_position) / walk_speed)
	var direction := target_position - start_position
	var walking_left := direction.x < 0.0
	var animation_name: StringName = &"walk_left" if walking_left else &"walk_right"
	if direction.y > 0.0 and absf(direction.y) > absf(direction.x) * 0.35:
		animation_name = &"walk_front"
	if not requested_animation.is_empty() and player.sprite_frames.has_animation(StringName(requested_animation)):
		animation_name = StringName(requested_animation)
	player.flip_h = animation_name == &"walk_left" or (animation_name == &"walk_front" and walking_left)
	player.play(animation_name)
	var tween := create_tween()
	tween.tween_method(update_player_walk.bind(start_position, target_position), 0.0, 1.0, duration)
	await tween.finished
	player.position = target_position
	player.play(&"idle")
	player.frame = 0
	player.scale = base_scale
	is_walking = false

func hide_player() -> void:
	if is_instance_valid(player):
		player.hide()

func place_at_normalized_position(normalized_position: Array) -> void:
	if not is_instance_valid(player) or normalized_position.size() < 2:
		return
	player.position = get_player_position(normalized_position)
	player.play(&"idle")
	player.frame = 0
	player.scale = base_scale

func get_last_walkable_target(requested_target: Vector2) -> Vector2:
	var start_position := get_normalized_position()
	var distance_in_mask_pixels := maxf(
		absf(requested_target.x - start_position.x) * float(move_area_image.get_width() - 1),
		absf(requested_target.y - start_position.y) * float(move_area_image.get_height() - 1)
	)
	var steps: int = maxi(1, ceili(distance_in_mask_pixels))
	var last_walkable_position := Vector2.INF
	for step in range(steps + 1):
		var sampled_position := start_position.lerp(requested_target, float(step) / float(steps))
		if is_walkable_position(sampled_position):
			last_walkable_position = sampled_position
		elif last_walkable_position != Vector2.INF:
			break
	return last_walkable_position

func get_normalized_position() -> Vector2:
	return Vector2(
		player.position.x / canvas_size.x,
		(player.position.y + visual_size.y * 0.5 - ground_contact_offset_y) / canvas_size.y
	)

func is_walkable_position(normalized_position: Vector2) -> bool:
	if normalized_position.x < 0.0 or normalized_position.x > 1.0 or normalized_position.y < 0.0 or normalized_position.y > 1.0:
		return false
	var pixel_position := Vector2i(
		clampi(roundi(normalized_position.x * float(move_area_image.get_width() - 1)), 0, move_area_image.get_width() - 1),
		clampi(roundi(normalized_position.y * float(move_area_image.get_height() - 1)), 0, move_area_image.get_height() - 1)
	)
	return move_area_image.get_pixelv(pixel_position).get_luminance() >= 0.5

func create_player(visual_parent: Node) -> bool:
	if player_data.is_empty():
		return false
	var walk_sprite_path := get_sprite_asset_path("walk_sprite_asset")
	# Imported textures are packed as Godot resources in Android exports, where
	# FileAccess may not see the source PNG.  Resolve them through ResourceLoader.
	var has_walk_sprite := not walk_sprite_path.is_empty() and ResourceLoader.exists(walk_sprite_path, "Texture2D")
	var texture: Texture2D
	if has_walk_sprite:
		texture = load(walk_sprite_path) as Texture2D
	else:
		texture = load(get_sprite_asset_path("asset", "avatar")) as Texture2D
	if texture == null:
		return false
	var size_data: Array = player_data.get("size", [118, 142])
	visual_size = Vector2(float(size_data[0]), float(size_data[1]))
	var frame_size := texture.get_size()
	if has_walk_sprite:
		var walk_frame_size: Array = player_data.get("walk_frame_size", [texture.get_width(), texture.get_height()])
		frame_size = Vector2(float(walk_frame_size[0]), float(walk_frame_size[1]))
	var idle_texture := texture
	var idle_frame_size := frame_size
	var idle_frame_count := 1
	var idle_fps := 1.0
	var idle_frame_offsets: Array = []
	var idle_sprite_path := get_sprite_asset_path("idle_sprite_asset")
	if not idle_sprite_path.is_empty() and ResourceLoader.exists(idle_sprite_path, "Texture2D"):
		var loaded_idle_texture := load(idle_sprite_path) as Texture2D
		if loaded_idle_texture != null:
			idle_texture = loaded_idle_texture
			var configured_idle_size := GameSettings.get_avatar_idle_frame_size(str(player_data.get("sprite_sheet", "")))
			var idle_size_data: Array = configured_idle_size if not configured_idle_size.is_empty() else player_data.get("idle_frame_size", [idle_texture.get_width(), idle_texture.get_height()])
			idle_frame_size = Vector2(float(idle_size_data[0]), float(idle_size_data[1]))
			idle_frame_count = int(player_data.get("idle_frames", 1))
			idle_fps = float(player_data.get("idle_fps", 1.0))
			idle_frame_offsets = get_idle_frame_offsets()
	var front_walk_texture := texture
	var front_walk_frame_size := frame_size
	var front_walk_frame_count := int(player_data.get("walk_frames", 4)) if has_walk_sprite else 1
	var front_walk_fps := float(player_data.get("walk_fps", 6.0))
	var front_walk_sprite_path := get_sprite_asset_path("walk_front_sprite_asset")
	if not front_walk_sprite_path.is_empty() and ResourceLoader.exists(front_walk_sprite_path, "Texture2D"):
		var loaded_front_walk_texture := load(front_walk_sprite_path) as Texture2D
		if loaded_front_walk_texture != null:
			front_walk_texture = loaded_front_walk_texture
			var front_walk_size_data: Array = player_data.get("walk_front_frame_size", [front_walk_texture.get_width(), front_walk_texture.get_height()])
			front_walk_frame_size = Vector2(float(front_walk_size_data[0]), float(front_walk_size_data[1]))
			front_walk_frame_count = int(player_data.get("walk_front_frames", 1))
			front_walk_fps = float(player_data.get("walk_front_fps", front_walk_fps))
	base_scale = visual_size / frame_size
	player = AnimatedSprite2D.new()
	player.name = "Player"
	player.sprite_frames = create_player_frames(texture, frame_size, int(player_data.get("walk_frames", 4)) if has_walk_sprite else 1, float(player_data.get("walk_fps", 6.0)), idle_texture, idle_frame_size, idle_frame_count, idle_fps, idle_frame_offsets, front_walk_texture, front_walk_frame_size, front_walk_frame_count, front_walk_fps)
	player.animation = &"idle"
	player.scale = base_scale
	var normalized_position: Array = player_data.get("position", [0.5, 0.7])
	player.position = get_player_position(normalized_position)
	visual_parent.add_child(player)
	player.play(&"idle")
	return true

func get_sprite_asset_path(property_name: String, fallback := "") -> String:
	var asset_name := str(player_data.get(property_name, fallback))
	var sprite_sheet := str(player_data.get("sprite_sheet", ""))
	if not asset_name.is_empty() and not sprite_sheet.is_empty() and property_name != "asset":
		asset_name = "%s-%s" % [asset_name, sprite_sheet]
	return str(avatar_asset_path_resolver.call(asset_name))

func get_idle_frame_offsets() -> Array:
	var configured_offsets: Array = player_data.get("idle_frame_offsets", [])
	if not configured_offsets.is_empty():
		return configured_offsets
	return GameSettings.get_avatar_idle_frame_offsets(str(player_data.get("sprite_sheet", "")))

func create_player_frames(texture: Texture2D, frame_size: Vector2, frame_count: int, fps: float, idle_texture: Texture2D, idle_frame_size: Vector2, idle_frame_count: int, idle_fps: float, idle_frame_offsets: Array, front_walk_texture: Texture2D, front_walk_frame_size: Vector2, front_walk_frame_count: int, front_walk_fps: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", idle_fps)
	frames.set_animation_loop(&"idle", true)
	for idle_frame_index in idle_frame_count:
		var idle_atlas_texture := AtlasTexture.new()
		idle_atlas_texture.atlas = idle_texture
		var offset_x := float(idle_frame_offsets[idle_frame_index]) if idle_frame_index < idle_frame_offsets.size() else 0.0
		idle_atlas_texture.region = Rect2(Vector2(idle_frame_size.x * idle_frame_index + offset_x, 0.0), idle_frame_size)
		frames.add_frame(&"idle", idle_atlas_texture)
	frames.add_animation(&"walk_right")
	frames.set_animation_speed(&"walk_right", fps)
	frames.set_animation_loop(&"walk_right", true)
	frames.add_animation(&"walk_left")
	frames.set_animation_speed(&"walk_left", fps)
	frames.set_animation_loop(&"walk_left", true)
	frames.add_animation(&"walk_front")
	frames.set_animation_speed(&"walk_front", front_walk_fps)
	frames.set_animation_loop(&"walk_front", true)
	for frame_index in frame_count:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = texture
		atlas_texture.region = Rect2(Vector2(frame_size.x * frame_index, 0.0), frame_size)
		frames.add_frame(&"walk_right", atlas_texture)
		frames.add_frame(&"walk_left", atlas_texture)
	for frame_index in front_walk_frame_count:
		var front_walk_atlas_texture := AtlasTexture.new()
		front_walk_atlas_texture.atlas = front_walk_texture
		front_walk_atlas_texture.region = Rect2(Vector2(front_walk_frame_size.x * frame_index, 0.0), front_walk_frame_size)
		frames.add_frame(&"walk_front", front_walk_atlas_texture)
	return frames

func get_player_position(normalized_position: Array) -> Vector2:
	return Vector2(
		float(normalized_position[0]) * canvas_size.x,
		float(normalized_position[1]) * canvas_size.y - visual_size.y * 0.5 + ground_contact_offset_y
	)

func update_player_walk(progress: float, start_position: Vector2, target_position: Vector2) -> void:
	if is_instance_valid(player):
		player.position = start_position.lerp(target_position, progress)

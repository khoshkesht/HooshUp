extends Node

const SAVE_NAME := "progress.cfg"
const LEGACY_SAVE_PATH := "user://progress.cfg"
const PROGRESS_SECTION := "progress"
const CHECKPOINTS_SECTION := "checkpoints"
const BADGES_SECTION := "badges"
const MISSIONS_PER_STAGE := 5

signal badge_awarded(stage_number: int)

var test_mission := Vector2i.ZERO

func _ready() -> void:
	synchronize_stage_badges()

func begin_test_mission(stage_number: int, mission_number: int) -> void:
	if not is_valid_mission(stage_number, mission_number):
		push_error("Invalid test mission: %d-%d" % [stage_number, mission_number])
		return
	test_mission = Vector2i(stage_number, mission_number)
	var config := load_config()
	set_active_mission_in_config(config, stage_number, mission_number)
	SecureSaveStore.save_config(SAVE_NAME, config)

func is_test_mission(stage_number: int, mission_number: int) -> bool:
	return test_mission == Vector2i(stage_number, mission_number)

func is_test_mode() -> bool:
	return test_mission != Vector2i.ZERO

func consume_test_mission(stage_number: int, mission_number: int) -> void:
	if is_test_mission(stage_number, mission_number):
		test_mission = Vector2i.ZERO

func set_checkpoint(stage_number: int, mission_number: int, checkpoint_number: int) -> void:
	if not is_valid_mission(stage_number, mission_number) or checkpoint_number < 0:
		push_error("Invalid checkpoint: %d-%d-%d" % [stage_number, mission_number, checkpoint_number])
		return
	var config := load_config()
	config.set_value(CHECKPOINTS_SECTION, get_mission_key(stage_number, mission_number), checkpoint_number)
	SecureSaveStore.save_config(SAVE_NAME, config)

func get_checkpoint(stage_number: int, mission_number: int) -> int:
	if not is_valid_mission(stage_number, mission_number):
		return 0
	if is_test_mission(stage_number, mission_number):
		return 0
	var config := load_config()
	var mission_key := get_mission_key(stage_number, mission_number)
	if config.has_section_key(CHECKPOINTS_SECTION, mission_key):
		return int(config.get_value(CHECKPOINTS_SECTION, mission_key, 0))
	# Read the former single-checkpoint format once, without letting it overwrite
	# checkpoints belonging to other missions.
	var legacy_id := str(config.get_value(PROGRESS_SECTION, "Checkpoint", ""))
	var parts := legacy_id.split("-")
	if parts.size() == 3 and int(parts[0]) == stage_number and int(parts[1]) == mission_number:
		return int(parts[2])
	return 0

func complete_mission(stage_number: int, mission_number: int) -> void:
	if not is_valid_mission(stage_number, mission_number):
		push_error("Invalid mission completion: %d-%d" % [stage_number, mission_number])
		return
	var config := load_config()
	config.set_value(PROGRESS_SECTION, get_completion_key(stage_number, mission_number), true)
	if mission_number < MISSIONS_PER_STAGE:
		set_active_mission_in_config(config, stage_number, mission_number + 1)
	elif stage_number < GameContent.STAGES.size():
		award_stage_badge_in_config(config, stage_number)
		var highest_unlocked := int(config.get_value(PROGRESS_SECTION, "highest_unlocked_stage", 1))
		config.set_value(PROGRESS_SECTION, "highest_unlocked_stage", max(highest_unlocked, stage_number + 1))
		set_active_mission_in_config(config, stage_number + 1, 1)
	else:
		award_stage_badge_in_config(config, stage_number)
		set_active_mission_in_config(config, stage_number, mission_number)
	SecureSaveStore.save_config(SAVE_NAME, config)
	ScoreStore.record_mission_pass(stage_number, mission_number)

func is_mission_complete(stage_number: int, mission_number: int) -> bool:
	if not is_valid_mission(stage_number, mission_number):
		return false
	var config := load_config()
	return bool(config.get_value(PROGRESS_SECTION, get_completion_key(stage_number, mission_number), false))

func get_completed_missions(stage_number: int) -> Array[int]:
	var completed: Array[int] = []
	for mission_number in range(1, MISSIONS_PER_STAGE + 1):
		if is_mission_complete(stage_number, mission_number):
			completed.append(mission_number)
	return completed

func get_next_mission(stage_number: int) -> int:
	if stage_number < 1 or stage_number > GameContent.STAGES.size():
		return 0
	return get_next_mission_in_config(load_config(), stage_number)

func get_next_mission_in_config(config: ConfigFile, stage_number: int) -> int:
	var latest_completed_mission := 0
	for mission_number in range(1, MISSIONS_PER_STAGE + 1):
		if bool(config.get_value(PROGRESS_SECTION, get_completion_key(stage_number, mission_number), false)):
			latest_completed_mission = mission_number
	if latest_completed_mission >= MISSIONS_PER_STAGE:
		return 0
	return latest_completed_mission + 1

func set_active_mission(stage_number: int, mission_number: int) -> void:
	if not is_valid_mission(stage_number, mission_number):
		push_error("Invalid active mission: %d-%d" % [stage_number, mission_number])
		return
	var config := load_config()
	set_active_mission_in_config(config, stage_number, mission_number)
	SecureSaveStore.save_config(SAVE_NAME, config)

func get_active_mission() -> Vector2i:
	if is_test_mode():
		return test_mission
	var config := load_config()
	var parts := str(config.get_value(PROGRESS_SECTION, "active_mission", "1-1")).split("-")
	if parts.size() == 2:
		var stage_number := int(parts[0])
		var mission_number := int(parts[1])
		if is_valid_mission(stage_number, mission_number):
			var next_mission := get_next_mission_in_config(config, stage_number)
			if next_mission > mission_number:
				set_active_mission_in_config(config, stage_number, next_mission)
				SecureSaveStore.save_config(SAVE_NAME, config)
				return Vector2i(stage_number, next_mission)
			return Vector2i(stage_number, mission_number)
	return Vector2i(1, 1)

func get_highest_unlocked_stage() -> int:
	var config := load_config()
	return clampi(int(config.get_value(PROGRESS_SECTION, "highest_unlocked_stage", 1)), 1, GameContent.STAGES.size())

func is_stage_unlocked(stage_number: int) -> bool:
	return stage_number >= 1 and stage_number <= get_highest_unlocked_stage()

func has_stage_badge(stage_number: int) -> bool:
	if stage_number < 1 or stage_number > GameContent.STAGES.size():
		return false
	var config := load_config()
	return bool(config.get_value(BADGES_SECTION, get_badge_key(stage_number), false))

func get_mission_key(stage_number: int, mission_number: int) -> String:
	return "%d-%d" % [stage_number, mission_number]

func get_completion_key(stage_number: int, mission_number: int) -> String:
	return "completed_%s" % get_mission_key(stage_number, mission_number)

func is_valid_mission(stage_number: int, mission_number: int) -> bool:
	return stage_number >= 1 and stage_number <= GameContent.STAGES.size() and mission_number >= 1 and mission_number <= MISSIONS_PER_STAGE

func load_config() -> ConfigFile:
	var config := ConfigFile.new()
	return SecureSaveStore.load_config(SAVE_NAME, LEGACY_SAVE_PATH)

func synchronize_stage_badges() -> void:
	var config := load_config()
	var changed := false
	for stage_number in range(1, GameContent.STAGES.size() + 1):
		if is_stage_complete(stage_number) and not bool(config.get_value(BADGES_SECTION, get_badge_key(stage_number), false)):
			award_stage_badge_in_config(config, stage_number)
			changed = true
	if changed:
		SecureSaveStore.save_config(SAVE_NAME, config)

func is_stage_complete(stage_number: int) -> bool:
	if stage_number < 1 or stage_number > GameContent.STAGES.size():
		return false
	for mission_number in range(1, MISSIONS_PER_STAGE + 1):
		if not is_mission_complete(stage_number, mission_number):
			return false
	return true

func award_stage_badge_in_config(config: ConfigFile, stage_number: int) -> void:
	var badge_key := get_badge_key(stage_number)
	if bool(config.get_value(BADGES_SECTION, badge_key, false)):
		return
	config.set_value(BADGES_SECTION, badge_key, true)
	badge_awarded.emit(stage_number)

func get_badge_key(stage_number: int) -> String:
	return "stage_%d" % stage_number

func set_active_mission_in_config(config: ConfigFile, stage_number: int, mission_number: int) -> void:
	config.set_value(PROGRESS_SECTION, "active_mission", get_mission_key(stage_number, mission_number))

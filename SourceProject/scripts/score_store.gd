extends Node

signal scores_changed

const CONFIG_PATH := "res://data/scoring_config.json"
const HINT_CONFIG_PATH := "res://data/mission_hints.json"
const SAVE_PATH := "user://scores.cfg"
const SCORE_SECTION := "scores"
const MISSIONS_PER_STAGE := 5

var scoring_config: Dictionary = {}
var hint_config: Dictionary = {}

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		scoring_config = parsed
		var hint_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HINT_CONFIG_PATH))
		if hint_parsed is Dictionary:
			hint_config = hint_parsed
		else:
			push_error("Hint config is invalid: %s" % HINT_CONFIG_PATH)
		synchronize_completed_missions()
	else:
		push_error("Scoring config is invalid: %s" % CONFIG_PATH)

func synchronize_completed_missions() -> void:
	for stage_value in scoring_config.get("stages", []):
		var stage_data: Dictionary = stage_value as Dictionary
		var stage_number := int(stage_data.get("stage", 0))
		for mission_value in stage_data.get("missions", []):
			var mission_number := int((mission_value as Dictionary).get("mission", 0))
			if ProgressStore.is_mission_complete(stage_number, mission_number):
				record_mission_pass(stage_number, mission_number)

func record_mission_pass(stage_number: int, mission_number: int) -> void:
	var config := load_save()
	var mission_key := get_mission_key(stage_number, mission_number)
	if not bool(config.get_value(SCORE_SECTION, "mission_awarded_%s" % mission_key, false)):
		config.set_value(SCORE_SECTION, "mission_awarded_%s" % mission_key, true)
		config.set_value(SCORE_SECTION, "mission_score_%s" % mission_key, get_mission_pass_score(stage_number, mission_number))
	if is_stage_complete(stage_number) and not bool(config.get_value(SCORE_SECTION, "stage_awarded_%d" % stage_number, false)):
		config.set_value(SCORE_SECTION, "stage_awarded_%d" % stage_number, true)
		config.set_value(SCORE_SECTION, "stage_score_%d" % stage_number, get_stage_completion_score(stage_number))
	config.save(SAVE_PATH)
	scores_changed.emit()

func record_wrong_answer(stage_number: int, mission_number: int) -> void:
	record_penalty(stage_number, mission_number, "wrong_answer", get_rule_value("wrong_answer_penalty"))

func record_hint_used(stage_number: int, mission_number: int) -> void:
	record_penalty(stage_number, mission_number, "hint", get_rule_value("hint_penalty"))

func record_penalty(stage_number: int, mission_number: int, reason: String, amount: int) -> void:
	if amount <= 0:
		return
	var config := load_save()
	var key := "%d-%d-%s" % [stage_number, mission_number, reason]
	var current := int(config.get_value(SCORE_SECTION, "penalty_%s" % key, 0))
	config.set_value(SCORE_SECTION, "penalty_%s" % key, current + amount)
	config.save(SAVE_PATH)
	scores_changed.emit()

func get_total_score() -> int:
	var config := load_save()
	return maxi(0, get_awarded_score(config) - get_total_penalties(config))

func get_stage_score(stage_number: int) -> int:
	var config := load_save()
	return maxi(0, get_stage_awarded_score(config, stage_number) - get_stage_penalties(config, stage_number))

func get_stage_star_count(stage_number: int) -> int:
	if not is_stage_complete(stage_number):
		return 0
	var maximum := get_stage_maximum_score(stage_number)
	if maximum <= 0:
		return 0
	var ratio := float(get_stage_score(stage_number)) / float(maximum)
	var thresholds: Array = get_rules().get("star_thresholds", [])
	for threshold_value in thresholds:
		var threshold: Dictionary = threshold_value as Dictionary
		if ratio >= float(threshold.get("minimum_ratio", 0.0)):
			return int(threshold.get("stars", 0))
	return 0

func get_total_stars() -> int:
	var total := 0
	for stage_data_value in scoring_config.get("stages", []):
		var stage_data: Dictionary = stage_data_value as Dictionary
		total += get_stage_star_count(int(stage_data.get("stage", 0)))
	return total

func get_mission_pass_score(stage_number: int, mission_number: int) -> int:
	for mission_value in get_stage_data(stage_number).get("missions", []):
		var mission_data: Dictionary = mission_value as Dictionary
		if int(mission_data.get("mission", 0)) == mission_number:
			return int(mission_data.get("pass_score", 0))
	return 0

func get_stage_completion_score(stage_number: int) -> int:
	return int(get_stage_data(stage_number).get("completion_score", 0))

func get_stage_maximum_score(stage_number: int) -> int:
	var total := get_stage_completion_score(stage_number)
	for mission_value in get_stage_data(stage_number).get("missions", []):
		total += int((mission_value as Dictionary).get("pass_score", 0))
	return total

func get_stage_data(stage_number: int) -> Dictionary:
	for stage_value in scoring_config.get("stages", []):
		var stage_data: Dictionary = stage_value as Dictionary
		if int(stage_data.get("stage", 0)) == stage_number:
			return stage_data
	return {}

func get_rules() -> Dictionary:
	return scoring_config.get("rules", {})

func get_rule_value(key: String) -> int:
	return int(get_rules().get(key, 0))

func get_mission_hint(stage_number: int, mission_number: int) -> String:
	for stage_value in hint_config.get("stages", []):
		var stage_data: Dictionary = stage_value as Dictionary
		if int(stage_data.get("stage", 0)) != stage_number:
			continue
		for mission_value in stage_data.get("missions", []):
			var mission_data: Dictionary = mission_value as Dictionary
			if int(mission_data.get("mission", 0)) == mission_number:
				return str(mission_data.get("text", ""))
	return ""

func is_stage_complete(stage_number: int) -> bool:
	for mission_number in range(1, MISSIONS_PER_STAGE + 1):
		if not ProgressStore.is_mission_complete(stage_number, mission_number):
			return false
	return true

func load_save() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	return config

func get_mission_key(stage_number: int, mission_number: int) -> String:
	return "%d-%d" % [stage_number, mission_number]

func get_awarded_score(config: ConfigFile) -> int:
	var total := 0
	for stage_data_value in scoring_config.get("stages", []):
		var stage_data: Dictionary = stage_data_value as Dictionary
		var stage_number := int(stage_data.get("stage", 0))
		total += int(config.get_value(SCORE_SECTION, "stage_score_%d" % stage_number, 0))
		for mission_value in stage_data.get("missions", []):
			var mission_number := int((mission_value as Dictionary).get("mission", 0))
			total += int(config.get_value(SCORE_SECTION, "mission_score_%d-%d" % [stage_number, mission_number], 0))
	return total

func get_total_penalties(config: ConfigFile) -> int:
	var total := 0
	for key in config.get_section_keys(SCORE_SECTION):
		if key.begins_with("penalty_"):
			total += int(config.get_value(SCORE_SECTION, key, 0))
	return total

func get_stage_awarded_score(config: ConfigFile, stage_number: int) -> int:
	var total := int(config.get_value(SCORE_SECTION, "stage_score_%d" % stage_number, 0))
	for mission_number in range(1, MISSIONS_PER_STAGE + 1):
		total += int(config.get_value(SCORE_SECTION, "mission_score_%d-%d" % [stage_number, mission_number], 0))
	return total

func get_stage_penalties(config: ConfigFile, stage_number: int) -> int:
	var total := 0
	var prefix := "penalty_%d-" % stage_number
	for key in config.get_section_keys(SCORE_SECTION):
		if key.begins_with(prefix):
			total += int(config.get_value(SCORE_SECTION, key, 0))
	return total

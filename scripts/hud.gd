extends Control

@export var max_health: int = 3

var current_health: int = 3
var score: int = 0

var hearts_label: Label
var score_label: Label


func _ready() -> void:
	add_to_group("game_hud")

	hearts_label = find_child("HeartsLabel", true, false) as Label
	score_label = find_child("ScoreLabel", true, false) as Label

	if hearts_label == null:
		push_error("HUD: Could not find HeartsLabel.")
		return

	if score_label == null:
		push_error("HUD: Could not find ScoreLabel.")
		return

	current_health = max_health

	update_hearts()
	update_score()


func update_hearts() -> void:
	if not is_instance_valid(hearts_label):
		return

	var hearts: String = ""

	for i in range(max_health):
		if i < current_health:
			hearts += "♥ "
		else:
			hearts += "♡ "

	hearts_label.text = hearts.strip_edges()


func update_score() -> void:
	if not is_instance_valid(score_label):
		return

	score_label.text = "SCORE: %06d" % score


func set_health(new_health: int) -> void:
	current_health = clampi(new_health, 0, max_health)
	update_hearts()


func take_damage(amount: int = 1) -> void:
	set_health(current_health - amount)


func add_score(points: int) -> void:
	score += points
	update_score()


func reset_hud() -> void:
	current_health = max_health
	score = 0

	update_hearts()
	update_score()

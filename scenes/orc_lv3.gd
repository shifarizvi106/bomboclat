
extends CharacterBody2D

const FRAME_SIZE := 100
const ORC_TEXTURE: Texture2D = preload("res://assets/Characters/Orc.png")

const ANIMS := {
	"idle": [0, 6, 8.0, true],
	"walk": [1, 8, 10.0, true],
	"attack": [2, 6, 12.0, false],
	"attack2": [3, 6, 12.0, false],
	"hurt": [4, 4, 10.0, false],
	"death": [5, 4, 8.0, false],
}

@export var chase_speed: float = 220.0
@export var attack_range: float = 65.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 0.35
@export var attack_windup: float = 0.22
@export var max_health: int = 3
@export var repath_distance: float = 12.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var player: Node2D = null
var health: int = 3

var alerted := false
var attacking := false
var can_attack := true
var dead := false
var encounter_finished := false

var action_token := 0
var use_second_attack := false
var last_target_position := Vector2.ZERO


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemies")
	health = max_health

	


	sprite.sprite_frames = _build_animations()
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.play("idle")

	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	if not detection_area.body_entered.is_connected(_on_detection_body_entered):
		detection_area.body_entered.connect(_on_detection_body_entered)

	if not detection_area.body_exited.is_connected(_on_detection_body_exited):
		detection_area.body_exited.connect(_on_detection_body_exited)

	detection_area.monitoring = true

	_find_player()

	for body in detection_area.get_overlapping_bodies():
		_on_detection_body_entered(body)


func _build_animations() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	for anim_name in ANIMS:
		var data: Array = ANIMS[anim_name]

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, data[2])
		frames.set_animation_loop(anim_name, data[3])

		for i in range(data[1]):
			var atlas := AtlasTexture.new()
			atlas.atlas = ORC_TEXTURE
			atlas.region = Rect2(
				i * FRAME_SIZE,
				data[0] * FRAME_SIZE,
				FRAME_SIZE,
				FRAME_SIZE
			)
			frames.add_frame(anim_name, atlas)

	return frames


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")

	if not players.is_empty():
		var candidate := players[0] as Node2D

		if is_instance_valid(candidate):
			player = candidate
			alerted = true


func _on_detection_body_entered(body: Node2D) -> void:
	if dead or encounter_finished:
		return

	if body.is_in_group("player"):
		player = body
		alerted = true
		print("ORC: PLAYER DETECTED")


func _on_detection_body_exited(body: Node2D) -> void:
	# Keep pursuing the current target outside the detection area.
	if body == player:
		print("ORC: CONTINUING CHASE")


func _physics_process(_delta: float) -> void:
	if dead or encounter_finished:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(player):
		player = null
		alerted = false
		_find_player()

	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		if not attacking:
			_play("idle")
		return

	alerted = true

	var offset := player.global_position - global_position
	var distance := offset.length()

	if absf(offset.x) > 0.1:
		sprite.flip_h = offset.x < 0.0

	if attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Attack at close range.
	if distance <= attack_range:
		velocity = Vector2.ZERO
		move_and_slide()

		if can_attack:
			_start_attack()
		else:
			_play("idle")
		return

	# Update the path only when Alex has moved enough.
	if last_target_position.distance_to(player.global_position) >= repath_distance:
		last_target_position = player.global_position
		navigation_agent.target_position = last_target_position

	# Follow the calculated path around obstacles.
	if navigation_agent.is_navigation_finished():
		navigation_agent.target_position = player.global_position
		last_target_position = player.global_position

	var next_position := navigation_agent.get_next_path_position()
	var direction := next_position - global_position

	if direction.length_squared() > 4.0:
		velocity = direction.normalized() * chase_speed
		_play("walk")
	else:
		velocity = Vector2.ZERO
		_play("idle")

	move_and_slide()


func _play(anim_name: String) -> void:
	if is_instance_valid(sprite) and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _start_attack() -> void:
	if dead or encounter_finished or attacking or not can_attack:
		return

	attacking = true
	can_attack = false
	action_token += 1

	var token := action_token
	var animation_name := "attack"

	if use_second_attack:
		animation_name = "attack2"

	use_second_attack = not use_second_attack

	sprite.play(animation_name)
	sprite.frame = 0

	_run_attack(token)


func _run_attack(token: int) -> void:
	await get_tree().create_timer(attack_windup).timeout

	if not _action_is_valid(token):
		return

	# Check Alex's position when the swing lands.
	if is_instance_valid(player):
		var distance := global_position.distance_to(player.global_position)

		if distance <= attack_range + 20.0:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
				print("ORC: HIT ALEX")
			else:
				push_warning("Player has no take_damage(amount) function.")

	# Keep the swing visible, then resume pursuit.
	await get_tree().create_timer(0.30).timeout

	if not _action_is_valid(token):
		return

	attacking = false

	await get_tree().create_timer(attack_cooldown).timeout

	if _action_is_valid(token):
		can_attack = true


func _action_is_valid(token: int) -> bool:
	return (
		is_inside_tree()
		and not dead
		and not encounter_finished
		and action_token == token
	)


func stop_encounter() -> void:
	encounter_finished = true
	alerted = false
	player = null
	attacking = false
	can_attack = false
	action_token += 1
	velocity = Vector2.ZERO
	_play("idle")


func take_damage(amount: int) -> void:
	if dead or encounter_finished or amount <= 0:
		return

	health -= amount
	action_token += 1
	velocity = Vector2.ZERO

	if health <= 0:
		dead = true
		attacking = false
		_play("death")
		print("ORC: DEFEATED")
	else:
		attacking = true
		_play("hurt")
		_finish_hurt(action_token)


func _finish_hurt(token: int) -> void:
	await get_tree().create_timer(0.4).timeout

	if not _action_is_valid(token):
		return

	attacking = false
	can_attack = true


func _on_animation_finished() -> void:
	if sprite.animation == "death":
		queue_free()

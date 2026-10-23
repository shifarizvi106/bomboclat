extends CharacterBody2D

const FRAME := 100
# name: [row, frame_count, fps, loop]
const ANIMS := {
	"idle": [0, 6, 8.0, true],
	"walk": [1, 8, 10.0, true],
	"attack": [2, 6, 12.0, false],
	"attack2": [3, 6, 12.0, false],
	"hurt": [4, 4, 10.0, false],
	"death": [5, 4, 8.0, false],
}

@export var chase_speed := 90.0
@export var wander_speed := 40.0
@export var acceleration := 600.0
@export var friction := 800.0
@export var attack_range := 28.0
@export var attack_cooldown := 1.0
@export var attack_damage := 1
@export var max_health := 3
@export var wander_radius := 150.0
@export var use_navigation := false
@export var always_chase := true
@export var bounds := Rect2()
@export var bounds_margin := 16.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var nav := get_node_or_null("NavigationAgent2D") as NavigationAgent2D

var health: int
var player: Node2D = null
var busy := false
var can_attack := true
var hit_done := false
var home_position := Vector2.ZERO
var wander_target := Vector2.ZERO
var wait_timer := 0.0
var wander_timeout := 0.0
var hitbox_offset_x := 20.0

func _ready() -> void:
	health = max_health
	home_position = global_position
	wander_target = global_position
	hitbox_offset_x = abs(hitbox.position.x)
	if bounds.size == Vector2.ZERO:
		bounds = get_viewport_rect()
	sprite.sprite_frames = _build_frames()
	sprite.play("idle")
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	$DetectionArea.body_entered.connect(_on_detect_enter)
	$DetectionArea.body_exited.connect(_on_detect_exit)

func _build_frames() -> SpriteFrames:
	var tex: Texture2D = preload("res://assets/Characters/Orc.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim_name in ANIMS:
		var d = ANIMS[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, d[2])
		sf.set_animation_loop(anim_name, d[3])
		for i in d[1]:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * FRAME, d[0] * FRAME, FRAME, FRAME)
			sf.add_frame(anim_name, atlas)
	return sf

func _on_detect_enter(body: Node) -> void:
	if body.is_in_group("player"):
		player = body

func _on_detect_exit(body: Node) -> void:
	if always_chase:
		return
	if body == player:
		player = null
		wait_timer = 0.0
		wander_target = global_position

func _face(dir_x: float) -> void:
	if abs(dir_x) < 0.05:
		return
	sprite.flip_h = dir_x < 0
	hitbox.position.x = -hitbox_offset_x if sprite.flip_h else hitbox_offset_x

func _direction_to(target: Vector2) -> Vector2:
	if use_navigation and nav != null:
		nav.target_position = target
		if nav.is_navigation_finished():
			return Vector2.ZERO
		return (nav.get_next_path_position() - global_position).normalized()
	return (target - global_position).normalized()

func _clamp_to_bounds() -> void:
	var margin := Vector2(bounds_margin, bounds_margin)
	global_position = global_position.clamp(bounds.position + margin, bounds.end - margin)

func _move(desired: Vector2, delta: float) -> void:
	var rate := acceleration if desired != Vector2.ZERO else friction
	velocity = velocity.move_toward(desired, rate * delta)
	move_and_slide()
	_clamp_to_bounds()

func _physics_process(delta: float) -> void:
	if always_chase and not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if busy:
		_move(Vector2.ZERO, delta)
		return

	if player != null:
		_chase(delta)
	else:
		_wander(delta)

func _chase(delta: float) -> void:
	var to_player := player.global_position - global_position
	_face(to_player.x)
	if to_player.length() <= attack_range:
		_move(Vector2.ZERO, delta)
		if can_attack:
			_start_attack()
		else:
			sprite.play("idle")
	else:
		var dir := _direction_to(player.global_position)
		_move(dir * chase_speed, delta)
		sprite.play("walk")

func _pick_wander_target() -> void:
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(30.0, wander_radius)
	var target := home_position + offset
	var margin := Vector2(bounds_margin, bounds_margin)
	wander_target = target.clamp(bounds.position + margin, bounds.end - margin)
	wander_timeout = 4.0

func _wander(delta: float) -> void:
	if wait_timer > 0.0:
		wait_timer -= delta
		_move(Vector2.ZERO, delta)
		sprite.play("idle")
		return

	wander_timeout -= delta
	var arrived := global_position.distance_to(wander_target) < 6.0
	if arrived or wander_timeout <= 0.0:
		wait_timer = randf_range(1.0, 3.0)
		_pick_wander_target()
		return

	var dir := _direction_to(wander_target)
	_face(dir.x)
	_move(dir * wander_speed, delta)
	sprite.play("walk")

func _start_attack() -> void:
	busy = true
	can_attack = false
	hit_done = false
	sprite.play("attack")
	_start_cooldown()

func _start_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _on_frame_changed() -> void:
	if sprite.animation == "attack" and sprite.frame == 3 and not hit_done:
		hit_done = true
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	busy = true
	if health <= 0:
		sprite.play("death")
	else:
		sprite.play("hurt")

func _on_anim_finished() -> void:
	if sprite.animation == "death":
		queue_free()
	else:
		busy = false


extends Node2D

const FRAME := 100
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
@export var attack_range := 45.0
@export var attack_cooldown := 1.0
@export var attack_damage := 1
@export var max_health := 3
@export var patrol_distance := 200.0
@export var use_navigation := false
@export var always_chase := true
@export var bounds := Rect2()
@export var bounds_margin := 16.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = get_node_or_null("Hitbox") as Area2D
@onready var nav: NavigationAgent2D = get_node_or_null("NavigationAgent2D") as NavigationAgent2D

var velocity := Vector2.ZERO
var health: int
var player: Node2D = null
var busy := false
var dead := false
var can_attack := true
var hit_done := false
var home_position := Vector2.ZERO
var patrol_dir := 1.0
var wait_timer := 0.0
var hitbox_offset_x := 30.0


func _ready() -> void:
	health = max_health
	home_position = global_position

	if hitbox != null:
		hitbox_offset_x = abs(hitbox.position.x)

	if bounds.size == Vector2.ZERO:
		bounds = get_viewport_rect()

	sprite.sprite_frames = _build_frames()
	sprite.play("idle")

	if not sprite.animation_finished.is_connected(_on_anim_finished):
		sprite.animation_finished.connect(_on_anim_finished)

	if not sprite.frame_changed.is_connected(_on_frame_changed):
		sprite.frame_changed.connect(_on_frame_changed)

	var detection_area := get_node_or_null("DetectionArea") as Area2D
	if detection_area != null:
		detection_area.body_entered.connect(_on_detect_enter)
		detection_area.body_exited.connect(_on_detect_exit)


func _build_frames() -> SpriteFrames:
	var tex: Texture2D = preload("res://assets/Characters/Orc.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for anim_name in ANIMS:
		var d: Array = ANIMS[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, d[2])
		sf.set_animation_loop(anim_name, d[3])

		for i in range(d[1]):
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


func _face(dir_x: float) -> void:
	if absf(dir_x) < 0.05:
		return

	sprite.flip_h = dir_x < 0.0

	if hitbox != null:
		hitbox.position.x = -hitbox_offset_x if sprite.flip_h else hitbox_offset_x


func _direction_to(target: Vector2) -> Vector2:
	if use_navigation and nav != null:
		nav.target_position = target

		if nav.is_navigation_finished():
			return Vector2.ZERO

		return (nav.get_next_path_position() - global_position).normalized()

	return (target - global_position).normalized()


func _clamp_to_bounds() -> void:
	if bounds.size == Vector2.ZERO:
		return

	var margin := Vector2(bounds_margin, bounds_margin)
	var low := bounds.position + margin
	var high := bounds.end - margin

	if low.x > high.x:
		low.x = bounds.position.x
		high.x = bounds.end.x
	if low.y > high.y:
		low.y = bounds.position.y
		high.y = bounds.end.y

	global_position = global_position.clamp(low, high)


func _move(desired: Vector2, delta: float) -> void:
	var rate := acceleration if desired.length_squared() > 0.001 else friction
	velocity = velocity.move_toward(desired, rate * delta)
	global_position += velocity * delta
	_clamp_to_bounds()


func _physics_process(delta: float) -> void:
	if dead:
		return

	if always_chase and not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if not is_instance_valid(player):
		player = null

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


func _wander(delta: float) -> void:
	if wait_timer > 0.0:
		wait_timer -= delta
		_move(Vector2.ZERO, delta)
		global_position.y = home_position.y
		sprite.play("idle")
		return

	var distance_from_home := global_position.x - home_position.x

	if distance_from_home >= patrol_distance:
		patrol_dir = -1.0
		wait_timer = randf_range(1.0, 2.0)
		velocity = Vector2.ZERO
		sprite.play("idle")
		return
	elif distance_from_home <= -patrol_distance:
		patrol_dir = 1.0
		wait_timer = randf_range(1.0, 2.0)
		velocity = Vector2.ZERO
		sprite.play("idle")
		return

	_face(patrol_dir)

	global_position.x += patrol_dir * wander_speed * delta
	global_position.y = home_position.y
	velocity = Vector2.ZERO

	_clamp_to_bounds()
	sprite.play("walk")


func _start_attack() -> void:
	if dead or busy or not can_attack:
		return

	busy = true
	can_attack = false
	hit_done = false
	sprite.play("attack")
	_start_cooldown()


func _start_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout

	if not dead:
		can_attack = true


func _on_frame_changed() -> void:
	if dead or sprite.animation != "attack":
		return

	if sprite.frame == 3 and not hit_done:
		hit_done = true

		if not is_instance_valid(player):
			return

		var close_enough := global_position.distance_to(player.global_position) <= attack_range + 16.0
		var in_hitbox := hitbox != null and hitbox.overlaps_body(player)

		if close_enough or in_hitbox:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)


func take_damage(amount: int) -> void:
	if dead or amount <= 0:
		return

	health -= amount

	if health <= 0:
		dead = true
		busy = true
		velocity = Vector2.ZERO
		sprite.play("death")
	else:
		busy = true
		velocity = Vector2.ZERO
		sprite.play("hurt")


func _on_anim_finished() -> void:
	if sprite.animation == "death":
		queue_free()
	elif sprite.animation == "attack" or sprite.animation == "hurt":
		busy = false

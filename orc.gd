extends CharacterBody2D

const FRAME := 100

# Animation: [row, frame_count, fps, loop]
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
@export var attack_range := 40.0
@export var attack_cooldown := 1.0
@export var attack_damage := 1
@export var max_health := 3
@export var wander_radius := 150.0
@export var always_chase := true
@export var debug := true

@export var use_bounds := false
@export var map_left := 0.0
@export var map_top := 0.0
@export var map_right := 1152.0
@export var map_bottom := 648.0
@export var bounds_margin := 16.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = get_node_or_null("Hitbox")
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")

var health: int
var player: Node2D = null
var busy := false
var busy_time := 0.0
var can_attack := true
var hit_done := false
var dead := false

var home_position := Vector2.ZERO
var wander_target := Vector2.ZERO
var wait_timer := 0.0
var wander_timeout := 0.0
var hitbox_offset_x := 20.0
var debug_timer := 0.0


func _ready() -> void:
	# Top-down game: no floor/ceiling logic.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	health = max_health
	home_position = global_position
	wander_target = global_position

	if hitbox:
		hitbox_offset_x = abs(hitbox.position.x)

	sprite.sprite_frames = _build_frames()
	sprite.play("idle")

	sprite.animation_finished.connect(_on_anim_finished)
	sprite.frame_changed.connect(_on_frame_changed)

	if detection_area:
		detection_area.body_entered.connect(_on_detect_enter)
		detection_area.body_exited.connect(_on_detect_exit)

	player = get_tree().get_first_node_in_group("player") as Node2D
	print(name, ": player found = ", player, " always_chase = ", always_chase)


func _build_frames() -> SpriteFrames:
	var texture: Texture2D = preload("res://assets/Characters/Orc.png")
	var frames := SpriteFrames.new()

	if frames.has_animation("default"):
		frames.remove_animation("default")

	for anim_name in ANIMS:
		var data = ANIMS[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, data[2])
		frames.set_animation_loop(anim_name, data[3])

		for i in range(data[1]):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * FRAME, data[0] * FRAME, FRAME, FRAME)
			frames.add_frame(anim_name, atlas)

	return frames


func _on_detect_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_detect_exit(body: Node2D) -> void:
	if body == player and not always_chase:
		player = null
		wait_timer = 0.0
		wander_target = global_position


func _face(dir_x: float) -> void:
	if abs(dir_x) < 0.05:
		return
	sprite.flip_h = dir_x < 0.0
	if hitbox:
		hitbox.position.x = -hitbox_offset_x if sprite.flip_h else hitbox_offset_x


func _clamp_to_bounds() -> void:
	if not use_bounds:
		return
	global_position.x = clamp(global_position.x, map_left + bounds_margin, map_right - bounds_margin)
	global_position.y = clamp(global_position.y, map_top + bounds_margin, map_bottom - bounds_margin)


func _move(desired: Vector2, delta: float) -> void:
	var rate := acceleration if desired != Vector2.ZERO else friction
	velocity = velocity.move_toward(desired, rate * delta)
	move_and_slide()

	# If blocked while trying to move, report what is in the way
	# and try sliding along a single axis to get around it.
	if desired != Vector2.ZERO and get_slide_collision_count() > 0:
		if debug:
			print(name, " blocked by: ", get_slide_collision(0).get_collider())

		if get_real_velocity().length() < 5.0:
			var try_x := Vector2(desired.x, 0.0)
			var try_y := Vector2(0.0, desired.y)
			velocity = try_x if abs(desired.x) >= abs(desired.y) else try_y
			move_and_slide()
			if get_real_velocity().length() < 5.0:
				velocity = try_y if velocity == try_x else try_x
				move_and_slide()

	_clamp_to_bounds()


func _physics_process(delta: float) -> void:
	if dead:
		return

	# Keep looking for the player until found.
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	# Failsafe: never stay busy forever.
	if busy:
		busy_time += delta
		if busy_time > 1.5:
			busy = false
			busy_time = 0.0
	else:
		busy_time = 0.0

	if debug:
		debug_timer += delta
		if debug_timer >= 1.0:
			debug_timer = 0.0
			print(name, " busy=", busy, " player=", player, " pos=", global_position, " vel=", velocity)

	if busy:
		_move(Vector2.ZERO, delta)
		return

	if is_instance_valid(player) and (always_chase or global_position.distance_to(player.global_position) < 300.0):
		_chase(delta)
	else:
		_wander(delta)


func _chase(delta: float) -> void:
	var diff := player.global_position - global_position

	# Close enough on both axes -> attack.
	if abs(diff.x) <= attack_range and abs(diff.y) <= attack_range:
		_move(Vector2.ZERO, delta)
		if can_attack:
			_start_attack()
		else:
			sprite.play("idle")
		return

	var direction := diff.normalized()
	_face(direction.x)
	_move(direction * chase_speed, delta)
	sprite.play("walk")


func _pick_wander_target() -> void:
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(30.0, wander_radius)
	wander_target = home_position + offset
	wander_timeout = 4.0


func _wander(delta: float) -> void:
	if wait_timer > 0.0:
		wait_timer -= delta
		_move(Vector2.ZERO, delta)
		sprite.play("idle")
		return

	wander_timeout -= delta

	if global_position.distance_to(wander_target) < 6.0 or wander_timeout <= 0.0:
		wait_timer = randf_range(1.0, 3.0)
		_pick_wander_target()
		return

	var direction := (wander_target - global_position).normalized()
	_face(direction.x)
	_move(direction * wander_speed, delta)
	sprite.play("walk")


func _start_attack() -> void:
	busy = true
	busy_time = 0.0
	can_attack = false
	hit_done = false

	if is_instance_valid(player):
		_face(player.global_position.x - global_position.x)

	sprite.play("attack")
	_start_cooldown()


func _start_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _on_frame_changed() -> void:
	if sprite.animation != "attack":
		return

	if sprite.frame == 3 and not hit_done:
		hit_done = true

		if not is_instance_valid(player):
			return

		var diff := player.global_position - global_position
		var reach := attack_range + 10.0

		if abs(diff.x) <= reach and abs(diff.y) <= reach:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage)
				print(name, ": hit the player!")


func take_damage(amount: int) -> void:
	if dead:
		return

	health -= amount
	busy = true
	busy_time = 0.0

	if health <= 0:
		dead = true
		velocity = Vector2.ZERO
		sprite.play("death")
	else:
		sprite.play("hurt")


func _on_anim_finished() -> void:
	if sprite.animation == "death":
		queue_free()
	else:
		busy = false
		busy_time = 0.0

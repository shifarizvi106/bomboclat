extends CharacterBody2D

@export var speed: float = 150.0
@export var max_health: int = 3

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "down"
var health: int = 3
var is_dead: bool = false
var damage_flash_active: bool = false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")

	health = max_health
	update_hud_health()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	# Prevent diagonal movement; horizontal input takes priority.
	if direction.x != 0:
		direction.y = 0
	elif direction.y != 0:
		direction.x = 0

	velocity = direction * speed
	move_and_slide()

	# Keep the last facing direction when standing still.
	if direction == Vector2.ZERO:
		return

	if direction.x < 0:
		last_direction = "left"
	elif direction.x > 0:
		last_direction = "right"
	elif direction.y < 0:
		last_direction = "up"
	elif direction.y > 0:
		last_direction = "down"

	match last_direction:
		"left":
			animated_sprite.play("walk_left")
		"right":
			animated_sprite.play("walk_right")
		"up":
			animated_sprite.play("walk_up")
		"down":
			animated_sprite.play("idle_down")


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = maxi(health - amount, 0)

	print("Alex took ", amount, " damage! Health: ", health)

	update_hud_health()

	# Flash Alex red briefly after taking damage.
	if not damage_flash_active:
		damage_flash_active = true
		animated_sprite.modulate = Color.RED

		await get_tree().create_timer(0.15).timeout

		if is_instance_valid(animated_sprite):
			animated_sprite.modulate = Color.WHITE

		damage_flash_active = false

	if health <= 0:
		die()


func update_hud_health() -> void:
	var hud := get_tree().get_first_node_in_group("game_hud")

	if hud != null and hud.has_method("set_health"):
		hud.set_health(health)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	print("Alex died! Game Over.")
	# We'll connect the Game Over screen later.

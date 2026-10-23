extends CharacterBody2D

@export var speed: float = 150.0
@export var max_health: int = 5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "down"
var health: int


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	health = max_health


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# No diagonal movement; horizontal has priority.
	if direction.x != 0:
		direction.y = 0
	elif direction.y != 0:
		direction.x = 0

	velocity = direction * speed
	move_and_slide()

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
	health -= amount
	print("Alex took ", amount, " damage! Health: ", health)

	# Quick red flash
	animated_sprite.modulate = Color.RED
	await get_tree().create_timer(0.15).timeout
	animated_sprite.modulate = Color.WHITE

	if health <= 0:
		print("Alex died!")
		# get_tree().reload_current_scene()

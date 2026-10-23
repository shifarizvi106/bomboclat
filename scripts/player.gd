
extends CharacterBody2D

@export var speed: float = 150.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "down"


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	velocity = direction * speed
	move_and_slide()

	if direction == Vector2.ZERO:
		# Keep facing the last direction when standing still.
		return

	# Choose the sprite based on the direction of movement.
	if abs(direction.x) > abs(direction.y):
		if direction.x < 0:
			last_direction = "left"
		else:
			last_direction = "right"
	else:
		if direction.y < 0:
			last_direction = "up"
		else:
			last_direction = "down"

	# Play the corresponding animation.
	match last_direction:
		"left":
			animated_sprite.play("walk_left")
		"right":
			animated_sprite.play("walk_right")
		"up":
			animated_sprite.play("walk_up")
		"down":
			animated_sprite.play("idle_down")

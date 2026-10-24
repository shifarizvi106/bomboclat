
extends CharacterBody2D

@export var speed: float = 150.0
@export var max_health: int = 3

# Gun settings
@export var bullet_scene: PackedScene
@export var magazine_size: int = 12
@export var reload_time: float = 1.2
@export var fire_rate: float = 0.25

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var gun: Sprite2D = $Gun

var last_direction: String = "down"
var health: int = 3
var is_dead: bool = false
var damage_flash_active: bool = false

var ammo: int = 12
var is_reloading: bool = false
var can_shoot: bool = true


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")

	health = max_health
	ammo = magazine_size

	update_hud_health()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	# Aim and handle gun input even when standing still.
	_update_gun_aim()

	if Input.is_action_just_pressed("shoot"):
		shoot()

	if Input.is_action_just_pressed("reload"):
		reload_gun()

	# Original movement logic preserved.
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


func _update_gun_aim() -> void:
	if not is_instance_valid(gun):
		return

	gun.look_at(get_global_mouse_position())

	# Keep the gun upright when aiming left.
	gun.flip_v = absf(gun.global_rotation) > PI / 2.0


func shoot() -> void:
	if is_dead or is_reloading or not can_shoot:
		return

	if ammo <= 0:
		print("Magazine empty! Press R to reload.")
		return

	if bullet_scene == null:
		push_warning("Assign Bullet.tscn in Alex's Inspector.")
		return

	ammo -= 1
	can_shoot = false

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = gun.global_position
	bullet.global_rotation = gun.global_rotation

	if bullet.has_method("set_direction"):
		bullet.set_direction(
			Vector2.RIGHT.rotated(gun.global_rotation)
		)

	print("Ammo: ", ammo, "/", magazine_size)

	await get_tree().create_timer(fire_rate).timeout

	if is_inside_tree():
		can_shoot = true


func reload_gun() -> void:
	if is_dead or is_reloading or ammo == magazine_size:
		return

	is_reloading = true
	print("Reloading...")

	await get_tree().create_timer(reload_time).timeout

	if not is_inside_tree():
		return

	ammo = magazine_size
	is_reloading = false

	print("Reload complete: ", ammo, "/", magazine_size)


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = maxi(health - amount, 0)

	print("Alex took ", amount, " damage! Health: ", health)

	update_hud_health()

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
	# Connect the Game Over screen later.

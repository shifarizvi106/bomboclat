
extends Node2D

var glitch_mode := false
var rgb_effect_active := false
var coach1_active := true
var transitioning := false

@onready var seat_barrier = $SeatBarrier
@onready var background: Sprite2D = $Background
@onready var glitch_background: Sprite2D = $GlitchBackground
@onready var coach1: Sprite2D = $Coach1
@onready var player: CharacterBody2D = $Player

var glitch_overlay: ColorRect


func _ready() -> void:
	coach1.visible = true
	background.visible = false
	glitch_background.visible = false
	create_glitch_overlay()


func create_glitch_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	glitch_overlay = ColorRect.new()
	glitch_overlay.name = "GlitchFlash"
	glitch_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch_overlay.color = Color(0, 0, 0, 0)
	canvas.add_child(glitch_overlay)


func _process(_delta: float) -> void:
	if transitioning:
		return

	# Coach 1: detect Alex near the left-side door.
	if coach1_active:
		if (
			player.global_position.x <= 120.0
			and player.global_position.y >= 180.0
			and player.global_position.y <= 260.0
		):
			await transition_to_coach2()

		return

	# Coach 2: dimension-shift mechanic.
	if Input.is_action_just_pressed("ui_accept"):
		glitch_mode = not glitch_mode

		background.visible = not glitch_mode
		glitch_background.visible = glitch_mode

		seat_barrier.visible = not glitch_mode
		set_seat_collisions_disabled(glitch_mode)

		play_glitch_effect()
		play_rgb_split()


func transition_to_coach2() -> void:
	if transitioning:
		return

	transitioning = true

	# Fade to black.
	var fade_out := create_tween()
	fade_out.tween_property(
		glitch_overlay,
		"color",
		Color.BLACK,
		0.35
	)
	await fade_out.finished

	# Switch to Coach 2.
	coach1.visible = false
	background.visible = true
	glitch_background.visible = false

	glitch_mode = false
	seat_barrier.visible = true
	set_seat_collisions_disabled(false)

	# Position Alex near Coach 2's left entrance.
	var left_edge := background.global_position.x - (
		background.texture.get_width()
		* background.global_scale.x / 2.0
	)

	player.global_position = Vector2(
		left_edge + 65.0,
		background.global_position.y
	)
	player.velocity = Vector2.ZERO

	# Keep the screen black for one second.
	await get_tree().create_timer(1.0).timeout

	# Fade back in.
	var fade_in := create_tween()
	fade_in.tween_property(
		glitch_overlay,
		"color",
		Color(0, 0, 0, 0),
		0.35
	)
	await fade_in.finished

	coach1_active = false
	transitioning = false


func play_glitch_effect() -> void:
	var tween := create_tween()

	tween.tween_property(
		glitch_overlay,
		"color",
		Color(0.1, 0.9, 1.0, 0.35),
		0.04
	)

	tween.tween_property(
		glitch_overlay,
		"color",
		Color(0.7, 0.1, 1.0, 0.25),
		0.05
	)

	tween.tween_property(
		glitch_overlay,
		"color",
		Color(0.1, 0.9, 1.0, 0.0),
		0.16
	)


func play_rgb_split() -> void:
	if rgb_effect_active:
		return

	rgb_effect_active = true

	var source: Sprite2D
	if glitch_mode:
		source = glitch_background
	else:
		source = background

	var red_ghost := Sprite2D.new()
	red_ghost.texture = source.texture
	red_ghost.centered = source.centered
	red_ghost.offset = source.offset
	red_ghost.region_enabled = source.region_enabled
	red_ghost.region_rect = source.region_rect
	red_ghost.hframes = source.hframes
	red_ghost.vframes = source.vframes
	red_ghost.frame = source.frame
	red_ghost.position = source.position + Vector2(-7, 0)
	red_ghost.scale = source.scale
	red_ghost.modulate = Color(1.0, 0.15, 0.25, 0.65)
	red_ghost.z_index = 5

	var cyan_ghost := Sprite2D.new()
	cyan_ghost.texture = source.texture
	cyan_ghost.centered = source.centered
	cyan_ghost.offset = source.offset
	cyan_ghost.region_enabled = source.region_enabled
	cyan_ghost.region_rect = source.region_rect
	cyan_ghost.hframes = source.hframes
	cyan_ghost.vframes = source.vframes
	cyan_ghost.frame = source.frame
	cyan_ghost.position = source.position + Vector2(7, 0)
	cyan_ghost.scale = source.scale
	cyan_ghost.modulate = Color(0.1, 1.0, 1.0, 0.65)
	cyan_ghost.z_index = 5

	source.get_parent().add_child(red_ghost)
	source.get_parent().add_child(cyan_ghost)

	var original_z := source.z_index
	source.z_index = 4

	await get_tree().create_timer(0.12).timeout

	if is_instance_valid(red_ghost):
		red_ghost.queue_free()

	if is_instance_valid(cyan_ghost):
		cyan_ghost.queue_free()

	if is_instance_valid(source):
		source.z_index = original_z

	rgb_effect_active = false


func set_seat_collisions_disabled(disabled: bool) -> void:
	for child in seat_barrier.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)

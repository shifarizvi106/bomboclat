
extends Node2D

var glitch_mode: bool = false
var rgb_effect_active: bool = false
var coach1_active: bool = true
var transitioning: bool = false

@onready var seat_barrier: StaticBody2D = $SeatBarrier
@onready var coach1_seat_barrier: StaticBody2D = $Coach1SeatBarrier

@onready var background: Sprite2D = $Background
@onready var glitch_background: Sprite2D = $GlitchBackground
@onready var coach1: Sprite2D = $Coach1
@onready var coach1_glitch: Sprite2D = $Coach1Glitch
@onready var player: CharacterBody2D = $Player

@onready var shift_prompt: TextureRect = $TutorialUI/ShiftPrompt

var glitch_overlay: ColorRect


func _ready() -> void:
	coach1.visible = true
	coach1_glitch.visible = false

	background.visible = false
	glitch_background.visible = false

	coach1_seat_barrier.visible = true
	set_coach1_collisions_disabled(false)

	seat_barrier.visible = false
	set_seat_collisions_disabled(true)

	shift_prompt.visible = true

	create_glitch_overlay()


func create_glitch_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GlitchEffects"
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

	# Transition from Level 1 to Level 2 at either exit.
	var at_exit_1: bool = (
		abs(player.global_position.x - (-558.896)) <= 12.0
		and abs(player.global_position.y - 279.88) <= 12.0
	)

	var at_exit_2: bool = (
		abs(player.global_position.x - 254.076) <= 12.0
		and abs(player.global_position.y - 285.076) <= 12.0
	)

	if at_exit_1 or at_exit_2:
		await transition_to_level_2()
		return

	# Coach 1 -> Coach 2.
	if coach1_active:
		if (
			abs(player.global_position.x - (-604.55)) <= 8.0
			and abs(player.global_position.y - 428.284) <= 8.0
		):
			await transition_to_coach2()
			return

	# Coach 2 -> Coach 1.
	else:
		if (
			abs(player.global_position.x - 325.624) <= 30.0
			and abs(player.global_position.y - 417.577) <= 30.0
		):
			await transition_to_coach1()
			return

	# SPACE switches dimensions.
	if Input.is_action_just_pressed("ui_accept"):
		glitch_mode = not glitch_mode

		if coach1_active:
			coach1.visible = not glitch_mode
			coach1_glitch.visible = glitch_mode

			coach1_seat_barrier.visible = not glitch_mode
			set_coach1_collisions_disabled(glitch_mode)
		else:
			background.visible = not glitch_mode
			glitch_background.visible = glitch_mode

			seat_barrier.visible = not glitch_mode
			set_seat_collisions_disabled(glitch_mode)

		play_glitch_effect()
		play_rgb_split()


func transition_to_level_2() -> void:
	if transitioning:
		return

	transitioning = true

	var fade_out := create_tween()
	fade_out.tween_property(
		glitch_overlay,
		"color",
		Color.BLACK,
		0.35
	)
	await fade_out.finished

	get_tree().change_scene_to_file(
		"res://scenes/level2.tscn"
	)


func transition_to_coach2() -> void:
	if transitioning:
		return

	transitioning = true

	var fade_out := create_tween()
	fade_out.tween_property(
		glitch_overlay,
		"color",
		Color.BLACK,
		0.35
	)
	await fade_out.finished

	coach1.visible = false
	coach1_glitch.visible = false

	coach1_seat_barrier.visible = false
	set_coach1_collisions_disabled(true)

	background.visible = true
	glitch_background.visible = false
	glitch_mode = false

	seat_barrier.visible = true
	set_seat_collisions_disabled(false)

	# Hide the tutorial image in Coach 2.
	shift_prompt.visible = false

	player.global_position = Vector2(325.624, 417.577)
	player.velocity = Vector2.ZERO

	await get_tree().create_timer(1.0).timeout

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


func transition_to_coach1() -> void:
	if transitioning:
		return

	transitioning = true

	var fade_out := create_tween()
	fade_out.tween_property(
		glitch_overlay,
		"color",
		Color.BLACK,
		0.35
	)
	await fade_out.finished

	background.visible = false
	glitch_background.visible = false

	seat_barrier.visible = false
	set_seat_collisions_disabled(true)

	coach1.visible = true
	coach1_glitch.visible = false
	glitch_mode = false

	coach1_seat_barrier.visible = true
	set_coach1_collisions_disabled(false)

	# Show the tutorial image again in Coach 1.
	shift_prompt.visible = true

	# Spawn away from the doorway trigger.
	player.global_position = Vector2(-550.0, 400.0)
	player.velocity = Vector2.ZERO

	await get_tree().create_timer(1.0).timeout

	var fade_in := create_tween()
	fade_in.tween_property(
		glitch_overlay,
		"color",
		Color(0, 0, 0, 0),
		0.35
	)
	await fade_in.finished

	coach1_active = true
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

	if coach1_active:
		source = coach1_glitch if glitch_mode else coach1
	else:
		source = glitch_background if glitch_mode else background

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

	var original_z: int = source.z_index
	source.z_index = 4

	await get_tree().create_timer(0.12).timeout

	if is_instance_valid(red_ghost):
		red_ghost.queue_free()

	if is_instance_valid(cyan_ghost):
		cyan_ghost.queue_free()

	if is_instance_valid(source):
		source.z_index = original_z

	rgb_effect_active = false


func set_coach1_collisions_disabled(disabled: bool) -> void:
	for child in coach1_seat_barrier.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)


func set_seat_collisions_disabled(disabled: bool) -> void:
	for child in seat_barrier.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)

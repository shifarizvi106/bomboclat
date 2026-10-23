extends Node2D

var glitch_mode: bool = false
var rgb_effect_active: bool = false
var switching_dimension: bool = false

@onready var background: Sprite2D = $Background
@onready var glitch_background: Sprite2D = $GlitchBackground

var glitch_overlay: ColorRect


func _ready() -> void:
	background.visible = true
	glitch_background.visible = false

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
	if switching_dimension:
		return

	if Input.is_action_just_pressed("ui_accept"):
		switch_dimension()


func switch_dimension() -> void:
	if switching_dimension:
		return

	switching_dimension = true

	# Brief cyan flash.
	var flash := create_tween()
	flash.tween_property(
		glitch_overlay,
		"color",
		Color(0.1, 0.9, 1.0, 0.35),
		0.04
	)

	# Purple glitch flash.
	flash.tween_property(
		glitch_overlay,
		"color",
		Color(0.7, 0.1, 1.0, 0.25),
		0.05
	)

	# Switch the dimension during the effect.
	glitch_mode = not glitch_mode

	background.visible = not glitch_mode
	glitch_background.visible = glitch_mode

	# RGB split effect.
	play_rgb_split()

	# Fade out the overlay.
	flash.tween_property(
		glitch_overlay,
		"color",
		Color(0, 0, 0, 0),
		0.16
	)

	await flash.finished

	switching_dimension = false


func play_rgb_split() -> void:
	if rgb_effect_active:
		return

	rgb_effect_active = true

	var source: Sprite2D

	if glitch_mode:
		source = glitch_background
	else:
		source = background

	# Create the red ghost.
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
	red_ghost.z_index = source.z_index + 1

	# Create the cyan ghost.
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
	cyan_ghost.z_index = source.z_index + 1

	source.get_parent().add_child(red_ghost)
	source.get_parent().add_child(cyan_ghost)

	# Keep the RGB split brief.
	await get_tree().create_timer(0.12).timeout

	if is_instance_valid(red_ghost):
		red_ghost.queue_free()

	if is_instance_valid(cyan_ghost):
		cyan_ghost.queue_free()

	rgb_effect_active = false

extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

var leaving_cutscene: bool = false
var fade_overlay: ColorRect

const VIDEO_PATH: String = "res://assets/cutscenes/opening_cutscene.ogv"
const LEVEL_1_PATH: String = "res://scenes/level_1.tscn"
const FADE_DURATION: float = 0.8


func _ready() -> void:
	# Fill the parent and game window.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true

	# Load the video.
	var video := load(VIDEO_PATH) as VideoStream

	if video == null:
		push_error("Could not load video: " + VIDEO_PATH)
		return

	video_player.stream = video

	# Add a black overlay for smooth transitions.
	fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.z_index = 100
	add_child(fade_overlay)

	video_player.finished.connect(_on_video_finished)
	video_player.play()

	print("Cutscene playing: ", video_player.is_playing())

	# Fade in from black.
	var fade_in := create_tween()
	fade_in.tween_property(fade_overlay, "color:a", 0.0, FADE_DURATION)


func _process(_delta: float) -> void:
	if not leaving_cutscene and Input.is_action_just_pressed("ui_cancel"):
		leave_cutscene()


func _on_video_finished() -> void:
	leave_cutscene()


func leave_cutscene() -> void:
	if leaving_cutscene:
		return

	leaving_cutscene = true
	video_player.stop()

	var fade_out := create_tween()
	fade_out.tween_property(fade_overlay, "color:a", 1.0, FADE_DURATION)

	await fade_out.finished

	var error := get_tree().change_scene_to_file(LEVEL_1_PATH)

	if error != OK:
		push_error("Could not load Level 1. Error: " + str(error))

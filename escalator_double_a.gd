extends Sprite2D

# --- SETTINGS ---
# Drag your escalator PNGs into these array slots in the Inspector!
@export var frames: Array[Texture2D] = []

# How fast the escalator moves (in seconds per frame). 
# 0.1 is fast, 0.5 is slow.
@export var frame_speed: float = 0.2 

var _time_elapsed: float = 0.0
var _current_frame: int = 0

func _ready() -> void:
	# Make sure we start with the first frame if we have any
	if frames.size() > 0:
		texture = frames[0]

func _process(delta: float) -> void:
	# Don't do anything if we don't have frames
	if frames.size() <= 1:
		return
		
	# Count up the time
	_time_elapsed += delta
	
	# If enough time has passed, switch to the next frame
	if _time_elapsed >= frame_speed:
		_time_elapsed = 0.0 # Reset the timer
		
		# Move to the next frame
		_current_frame += 1
		
		# If we reach the end of the list, loop back to the beginning
		if _current_frame >= frames.size():
			_current_frame = 0
			
		# Apply the new image
		texture = frames[_current_frame]

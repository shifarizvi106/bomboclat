extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	#print("start pressed")
		get_tree().change_scene_to_file("res://scenes/level_1.tscn")


func _on_levels_pressed() -> void:
	#print("levels pressed")
	get_tree().change_scene_to_file("res://assets/ui/Levels.tscn")


func _on_changecharacter_pressed() -> void:
	print("changed character pressed")


func _on_exit_pressed() -> void:
	#print("exit pressed")
	get_tree().quit()

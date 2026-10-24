extends Control


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	var error := get_tree().change_scene_to_file(
		"res://scenes/opening_cutscene.tscn"
	)

	if error != OK:
		push_error("Failed to open the cutscene. Error code: " + str(error))


func _on_levels_pressed() -> void:
	get_tree().change_scene_to_file("res://assets/ui/Levels.tscn")


func _on_changecharacter_pressed() -> void:
	print("changed character pressed")


func _on_exit_pressed() -> void:
	get_tree().quit()

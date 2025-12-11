extends Control

func _on_play_button_pressed():
	print("Loading the bad game...")
	get_tree().change_scene_to_file("res://game.tscn")

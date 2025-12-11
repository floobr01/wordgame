extends Node2D

# Load the letter scene so we can copy it
var letter_scene = preload("res://letter.tscn")

func _on_timer_timeout():
	# Create a new instance of the letter
	var new_letter = letter_scene.instantiate()
	
	# Set position (Random X, fixed Y at top)
	# 1152 is default screen width, adjust if needed
	var random_x = randf_range(250, 800) 
	new_letter.position = Vector2(random_x, 50)
	
	# Add it to the game world
	add_child(new_letter)

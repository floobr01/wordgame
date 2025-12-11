extends RigidBody2D

var character = ""
var is_active = true # Turns false when it hits the ground

func _ready():
	# Randomly pick a letter when spawned
	var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	character = alphabet[randi() % alphabet.length()]
	$Label.text = character # Make sure your Label node is named "Label"

func _input_event(viewport, event, shape_idx):
	# Detect mouse click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_active:
			print("Clicked letter: " + character)
			# Add logic here later to add to current word

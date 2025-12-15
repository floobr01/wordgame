# GameOverScreen.gd

extends CanvasLayer

signal restart_requested

func _ready():
	# Define the exact path to your button
	var retry_button = get_node("BackgroundOverlay/RetryButton") 
	
	# Check if the button object was actually found
	if is_instance_valid(retry_button):
		# Connect the button's 'pressed' signal to the function
		#retry_button.pressed.connect(_on_retry_button_pressed)
		#print("SUCCESS: RetryButton signal connected.")
		print("SUCCESS: GameOverScreen initialized.")
	else:
		# If this prints, your node path is definitely wrong.
		print("FATAL ERROR: Could not find RetryButton at path 'BackgroundOverlay/RetryButton'. Check your scene tree names (case-sensitive)!")
		
func _on_retry_button_pressed():
	print("RESTART BUTTON PRESSED! Emitting signal.")
	restart_requested.emit()
	queue_free()

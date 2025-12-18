# ComboExplosion.gd
extends Node2D

@onready var animator = $AnimationPlayer

func start_explosion(combo: int):
	# Calculate the scale factor based on the combo
	# Base scale (1.0) + extra scale (e.g., 0.5 per combo point)
	var scale_factor = 1.0 + (combo * 0.5) 

	# Apply the calculated scale
	scale = Vector2(scale_factor, scale_factor)

	# Position the explosion at the center of the screen
	global_position = get_viewport().get_visible_rect().size / 2

	animator.play("explode")

func _ready():
	# Connect to auto-delete after animation
	animator.animation_finished.connect(func(_name): queue_free())

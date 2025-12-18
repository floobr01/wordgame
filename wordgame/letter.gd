# letter.gd
extends RigidBody2D

# State management variables
var character = ""
var is_active = true
var is_dragging = false # Keeping this variable, but it will never be true now
var points = 0
var original_gravity_scale = 1.0
var collision_shape_node = null

# Signals used by Game.gd
signal letter_ejected(letter_node)
signal right_clicked_for_slot(letter_node)

var is_in_slot = false
var is_newly_spawned = true # Flag to skip game over check initially

var is_mystery_tile: bool = false


func _ready():
    set_process_mode(Node.PROCESS_MODE_ALWAYS)
    
    # CRITICAL: Find the shape node for click detection
    # Assuming CollisionShape2D is a direct child
    collision_shape_node = $CollisionShape2D 
    if not collision_shape_node:
        print("ERROR: CollisionShape2D node is missing or misnamed in the Letter scene.")
        
    # Physics Setup
    original_gravity_scale = gravity_scale


func set_letter_data(char, pts):
    character = char
    points = pts
    
    # Update the UI Label with the character
    if has_node("Label"):
        $Label.text = character
        
    # Update the point Label
    if has_node("PointLabel"): 
        if points > 0:
            $PointLabel.text = str(points)
        else:
            $PointLabel.text = ""
            
    # CRITICAL: If the letter is a blank tile, display it differently
    if character == "_":
        if has_node("Label"):
            $Label.text = "" # Show blank for a blank tile


func _input(event):
    
    # =========================================================================
    # --- LEFT-CLICK DRAGGING LOGIC REMOVED ---
    # The MOUSE_BUTTON_LEFT checks and the InputEventMouseMotion check are deleted.
    # =========================================================================

    # =========================================================================
    # --- RIGHT-CLICK EJECTION / AUTO-SLOTTING ---
    # This logic remains, as it's the intended way to interact now.
    # =========================================================================
    
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        
        # Check if the click occurred on the letter's collision shape
        if collision_shape_node:
            # We use a global rect check for simplicity, though get_global_rect() on Control nodes is cleaner.
            # Assuming the letter is 'Pickable', the click will be detected here.
            var shape_rect = collision_shape_node.shape.get_rect()
            var shape_size = shape_rect.size
            var top_left = global_position - (shape_size / 2.0)
    
    # 2. Create the global rectangle using the correctly calculated top-left corner and full size
            var global_rect = Rect2(top_left, shape_size)
            #var shape_rect = collision_shape_node.shape.get_rect()
            # Rect2 needs global position offset by the shape's local position
            #var global_rect = Rect2(global_position + shape_rect.position, shape_rect.size)
            
            if global_rect.has_point(get_global_mouse_position()):
                
                # We want to eject if the letter is currently placed in a slot
                if is_in_slot:
                    # Emit signal to the Game script to handle removal and re-spawning
                    letter_ejected.emit(self) 
                    
                else:
                    # If it's not in a slot, it's falling (or settled) and we auto-slot it
                    right_clicked_for_slot.emit(self)
                
                # Stop other nodes from processing this click
                get_viewport().set_input_as_handled()
                return
                
func make_mystery():
    is_mystery_tile = true
    character = "?"
    points = 10 # High risk, high reward?
    # Update your Label and visuals here
    $Label.text = "?" 
    # Maybe change the ColorRect color to Purple or Black to look "mysterious"
    #$ColorRect.color = Color.MEDIUM_PURPLE
    #$TileBackground.color = Color.MEDIUM_PURPLE

func trigger_mystery_effect():
    print("??? MYSTERY EFFECT TRIGGERED ???")
    # We'll define the actual effects later, but for now, maybe a little sound?
    # _play_sound(MYSTERY_SFX)

func _on_input_event(_viewport, event, _shape_idx):
    if is_mystery_tile and event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            trigger_mystery_effect()

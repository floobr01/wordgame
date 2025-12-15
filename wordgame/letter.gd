extends RigidBody2D

# State management variables

var character = ""
var is_active = true
var is_dragging = false
var points = 0 # NEW VARIABLE
var original_gravity_scale = 1.0 # To store the falling speed
var collision_shape_node = null

signal right_clicked_for_slot(letter_node)

func _ready():
    # 1. Character Setup
    #var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    #character = alphabet[randi() % alphabet.length()]
    ## Ensure your Label node is named "Label"
    #if has_node("Label"):
        #$Label.text = character
        
    # CRITICAL: Find the shape node for click detection
    collision_shape_node = $CollisionShape2D 
    if not collision_shape_node:
        print("ERROR: CollisionShape2D node is missing or misnamed in the Letter scene.")
    
    # 2. Physics Setup
    original_gravity_scale = gravity_scale
    # Make sure this node is CHECKED for 'Pickable' in the Inspector!

func set_letter_data(char, pts):
    character = char
    points = pts
    
    # Update the UI Label with the character
    if has_node("Label"):
        $Label.text = character
    # Update the point Label (This line needs to find the node correctly)
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
    # --- START/END DRAG (Left Mouse Button Events) ---
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        
        # --- 1. START DRAG (Click DOWN) ---
        # Checks if active (falling) OR frozen (in a slot)
        if event.pressed and (is_active or freeze) and collision_shape_node:
            
            # Calculate the global rectangle of the letter's CollisionShape
            var shape_rect = collision_shape_node.shape.get_rect()
            var global_rect = Rect2(global_position + shape_rect.position, shape_rect.size)
            
            # Check if the click was inside that global area
            if global_rect.has_point(get_global_mouse_position()):
                
                # --- LOGIC TO DRAG LETTER OUT OF A SLOT ---
                if freeze: 
                    # 1. Notify the Game script to clear the slot reference and reset slot color
                    # Parent of the letter is the slot (ColorRect), parent of slot is the Game node
                    #var game_node = get_tree().get_root().find_child("Game", true)
                    var game_node = get_parent().get_parent().get_parent().get_parent()
                    
                    if game_node and game_node.has_method("remove_letter_from_slot"):
                        game_node.remove_letter_from_slot(self)
                        
                        # 2. Reparent the letter back to the main game for dragging
                        var game_root = get_tree().get_root().get_node("Game") 
                        if game_root:
                            var old_global_pos = global_position
                            reparent(game_root)
                            global_position = old_global_pos
                            
                        # The letter is now ready to be manually dragged (freeze/gravity handled below)

                # --- UNIVERSAL DRAG START ---
                is_dragging = true
                
                # Stop physics and allow manual control (kinematic)
                gravity_scale = 0.0
                freeze = true
                freeze_mode = FREEZE_MODE_KINEMATIC
                
                # Restore color for visual clarity during drag
                if has_node("ColorRect"):
                    $ColorRect.modulate = Color.WHITE
                
        # --- 2. END DRAG (Click UP) ---
        elif not event.pressed and is_dragging:
            is_dragging = false
            
            # Get references for the drop check
            var game_node = get_parent()
            var submission_container = game_node.get_node("GameUI/SubmissionSlots")
            
            
            if submission_container and submission_container.get_global_rect().has_point(get_global_mouse_position()):
        # SUCCESS: Game script handles finding the specific slot
                game_node.add_letter_to_word(self)
            else:
        # FAILURE: Resume physics (falls back down)
        
                # 1. Reset Physics
                freeze = false # Turns physics back ON
                gravity_scale = original_gravity_scale # Restores normal falling speed
                
                # 2. **CRITICAL FIX: Reset the letter's block color**
                if has_node("ColorRect"):
                    # Set the color back to a distinct color (e.g., RED) for testing
                    $ColorRect.modulate = Color.WHITE


    # --- DRAG MOTION (Mouse Movement while dragging) ---
    if event is InputEventMouseMotion and is_dragging:
        global_position = get_global_mouse_position()

# IMPORTANT: The Right Click removal logic was deleted to use the Left Click drag-out instead.


    
func _on_input_area_input_event(viewport, event, shape_idx):
    # Check for right-click (mouse button index 2)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        
        # Emit a signal that the Game script can listen for.
        # This sends the letter node itself (self) back to the Game script.
        # You need to define this signal at the top of letter.gd!
        emit_signal("right_clicked_for_slot", self)
        
        # Stop the event from propagating further (optional, but good practice)
        get_viewport().set_input_as_handled()

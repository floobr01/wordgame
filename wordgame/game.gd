extends Node2D


#const LETTER_DISTRIBUTION = {
    #"A": 9, "B": 2, "C": 2, "D": 4, "E": 12, "F": 2, "G": 3, "H": 2,
    #"I": 9, "J": 1, "K": 1, "L": 4, "M": 2, "N": 6, "O": 8, "P": 2,
    #"Q": 1, "R": 6, "S": 4, "T": 6, "U": 4, "V": 2, "W": 2, "X": 1,
    #"Y": 2, "Z": 1, "-": 2 # Blank tile represented by "_"
#}

const LETTER_DISTRIBUTION = {
    "A": 9, "E":10, "S":10, "L":10
}

const LETTER_POINTS = {
    "A": 1, "E": 1, "I": 1, "O": 1, "U": 1, "L": 1, "N": 1, "S": 1, "T": 1, "R": 1,
    "D": 2, "G": 2,
    "B": 3, "C": 3, "M": 3, "P": 3,
    "F": 4, "H": 4, "V": 4, "W": 4, "Y": 4,
    "K": 5,
    "J": 8, "X": 8,
    "Q": 10, "Z": 10,
    "_": 0 # Blank tile has no score
}

# Ensure this path is correct for your letter scene file
var letter_scene = preload("res://letter.tscn") 
var floating_score_scene = preload("res://floating_score.tscn")
# Variable to hold all available characters flattened (used for random selection)
var available_letters = []
# Game State Variables
var current_word_nodes = [] # Holds the list of letter nodes currently in the box
var submission_slots = []   # Array to hold references to the 5 ColorRect nodes
var letter_in_slot = [null, null, null, null, null] # Tracks the actual letter node in each slot (null = empty)
var score = 0
var max_stack_height = 100 # Y-coordinate for game over (e.g., 100 pixels from top)
# Stores all valid words for fast look-up
var dictionary_set = {} 
var current_score = 0
var high_score = 0 # Optional: for tracking high score
const NUM_COLUMNS = 10
const HORIZONTAL_MARGIN = 270 # 20 pixels on the left and right edges
var pause_menu_scene = preload("res://pause_menu.tscn")
var pause_menu_node = null # Variable to hold the instantiated pause menu
# Variable to track the pause state
var is_paused = false
const TRANSPARENT_COLOR = Color(1, 1, 1, 0) # R, G, B = 1 (White base), Alpha = 0 (Fully Invisible)
const MIN_WORD_LENGTH = 1
# The path should reflect the location of your Label node
@onready var error_image: TextureRect = $ErrorMessageContainer/ErrorImage 
@onready var error_animator: AnimationPlayer = $ErrorMessageContainer/ErrorImage/ErrorAnimator

func _populate_available_letters():
    available_letters.clear()
    for char in LETTER_DISTRIBUTION:
        for i in range(LETTER_DISTRIBUTION[char]):
            available_letters.append(char)
    # Shuffle the list for good measure
    available_letters.shuffle()
    print("Available letter pool created with size: ", available_letters.size())

func _load_dictionary():
    var file = FileAccess.open("res://dictionary.txt", FileAccess.READ)
    if file:
        var content = file.get_as_text()
        var words = content.split("\n", false)
        
        # Convert the list of words into a Set (dictionary keys) for O(1) look-up time
        for word in words:
            var uppercase_word = word.strip_edges().to_upper()
            
            if not uppercase_word.is_empty(): # Avoid adding blank entries
                dictionary_set[uppercase_word] = true
            # Ensure words are uppercase and trim whitespace
            #dictionary_set[word.strip_edges().to_upper()] = true 
        
        print("Dictionary loaded with ", dictionary_set.size(), " words.")
    else:
        print("ERROR: Could not open dictionary.txt.")

func _ready():
    # Set up Timer connection and Autostart in the editor
    # Connect the Submit button
    $LetterTimer.start()
    _populate_available_letters()
    _load_dictionary() # <-- NEW: Load the dictionary here!
    # CRITICAL: Start the timer to begin spawning letters
    if has_node("LetterTimer"): # Ensure your timer node is named "LetterTimer"
        $LetterTimer.start()
    var submit_button = get_node("GameUI/SubmitButton")
    # CRITICAL: Populate the submission_slots array
    var slots_container = get_node("GameUI/SubmissionSlots")
    for i in range(1, 6):
        submission_slots.append(slots_container.get_node("Slot" + str(i)))
    
    submit_button.pressed.connect(_on_submit_button_pressed)
    
    _update_score_display()
    
    # Instantiate the pause menu and add it to the game tree
    pause_menu_node = pause_menu_scene.instantiate()
    get_node("/root").add_child(pause_menu_node) # Add it to the root of the scene tree
    
    # Hide the menu immediately
    pause_menu_node.hide() 
    
    # Connect the buttons (you will define these functions later)
    # Assuming your buttons are named "ResumeButton" and "QuitButton" in pause_menu.tscn
    pause_menu_node.get_node("PauseMenu/ResumeButton").pressed.connect(_on_resume_button_pressed)
    pause_menu_node.get_node("PauseMenu/QuitButton").pressed.connect(_on_quit_button_pressed)

# --- LETTER SPAWNING ---
func _on_letter_timer_timeout():
    # 1. Create a new instance of the letter, using ONE variable name
    var new_letter_node = letter_scene.instantiate()
    
    # Check if the pool is empty
    if available_letters.size() > 0:
        var rand_index = randi() % available_letters.size()
        # Take the character out of the pool
        var selected_char = available_letters.pop_at(rand_index)    
        
        # 2. Pass the selected character AND its point value to the letter node
        var points = LETTER_POINTS.get(selected_char, 0)
        
        # Set the letter data on the node we are about to spawn!
        new_letter_node.set_letter_data(selected_char, points)    
    else:
        # Stop spawning if the pool is empty
        $LetterTimer.stop()
        print("Letter pool empty! Game over or reshuffle needed.")
        return # Stop execution if no letters are available
        
    # 3. Set position (Column-based random X, fixed Y at top)
    var viewport_width = get_viewport_rect().size.x

    # Get the actual width of the tile's visual element for accurate centering
    # Uses a safe default (50.0) if the node isn't found, but should find "TileBackground"
    var tile_width = 50.0 
    if new_letter_node.has_node("TileBackground"):
        tile_width = new_letter_node.get_node("TileBackground").size.x

    # --- START COLUMN LOGIC INTEGRATION (with Margins) ---

    # A. Calculate the usable width (Viewport width minus margins)
    var usable_width = viewport_width - (2 * HORIZONTAL_MARGIN)

    # B. Calculate the width of each column (usable space / number of columns)
    var column_width = usable_width / NUM_COLUMNS

    # C. Pick a random column index (0 to 9)
    var random_column_index = randi() % NUM_COLUMNS

    # D. Calculate the **starting X** of the column
    # This is where the left edge of the tile should align
    var column_start_x = HORIZONTAL_MARGIN + (random_column_index * column_width)

    # E. Calculate the final X position (Center of the tile)
    # Center position = Column Start X + (Half the tile width)
    var center_x_position = column_start_x + (tile_width / 2.0)

    # F. Apply the calculated position 
    # Y is always -50 to start the tile just above the screen
    new_letter_node.position = Vector2(center_x_position, -50)

    # --- END COLUMN LOGIC INTEGRATION ---
    
    # 4. Connect the new right-click signal to the auto-slot function
    # This is required for the right-click feature added in the last step.
    new_letter_node.right_clicked_for_slot.connect(_auto_slot_letter)
    
    # 5. Add the letter instance with the correct data to the game world
    add_child(new_letter_node)
    
func _auto_slot_letter(letter_node):
    # Find the index of the first available (null) slot
    var available_index = -1
    for i in letter_in_slot.size():
        if letter_in_slot[i] == null:
            available_index = i
            break
            
    # If no slots are available, just return
    if available_index == -1:
        print("All slots full, cannot auto-slot.")
        return

    # Call your existing logic to place the letter at the found index
    # We pass the letter node and the target slot index.
    _place_letter_at_slot(letter_node, available_index)
    
func _place_letter_at_slot(letter_node, index):
    # 1. Freeze the letter so physics stops affecting it
    letter_node.freeze = true 
    letter_node.modulate = Color.WHITE
    
    # 2. Get the target slot node
    var target_slot = get_node("GameUI/SubmissionSlots").get_children()[index]
    
    # 3. REPARENT the letter to the slot
    # This moves the letter from the root scene INTO the UI slot.
    # This ensures it draws ON TOP of the slot and moves with it.
    letter_node.reparent(target_slot)
    
    # 4. Center the letter LOCALLY inside the slot
    # Since it is now a child of the slot, (0,0) is the top-left corner of the slot.
    var tile_width = letter_node.get_node("TileBackground").size.x
    var tile_height = letter_node.get_node("TileBackground").size.y
    
    var center_x = (target_slot.size.x / 2.0) - (tile_width / 2.0)
    var center_y = (target_slot.size.y / 2.0) - (tile_height / 2.0)
    
    # Set the LOCAL position (relative to the parent slot)
    letter_node.position = Vector2(center_x, center_y)
    
    # 5. Reset Rotation
    # Physics objects rotate as they fall. We want it straight in the slot.
    letter_node.rotation = 0

    # 6. Visual feedback (Darken the tile)
    #if letter_node.has_node("TileBackground"):
        #letter_node.get_node("TileBackground").modulate = Color.BLACK 
    
    # 7. Update logic arrays
    letter_in_slot[index] = letter_node
    
    # Update the UI text
    _arrange_letters()

      

# In game.gd: Replace the entire func _spawn_floating_score
func _input(event):
    # Check if the Escape key (or 'ui_cancel' action) was just pressed
    if event.is_action_pressed("ui_cancel"):
        if is_paused:
            _unpause_game()
        else:
            _pause_game()
            
func _show_message(): # Note: We remove the 'text' argument since it's an image
    
    # Ensure the image is visible (the animation controls the alpha fade)
    error_image.show() 
    
    # Check if the animation exists before playing
    if error_animator.has_animation("error_float"):
        error_animator.play("error_float")
    else:
        # Fallback if the animation is missing
        print("Error: 'error_float' animation not found in ErrorAnimator.")

# Function to handle pausing the game
func _pause_game():
    is_paused = true
    get_tree().paused = true
    
    # Show the pause menu
    pause_menu_node.show() 
    
    # IMPORTANT: Ensure the pause menu and its children are NOT affected by the game pause
    # Set the pause mode to PROCESS or IGNORE for the CanvasLayer root of the menu
    pause_menu_node.set_process_mode(Node.PROCESS_MODE_ALWAYS) # Or PROCESS_MODE_DISABLED if you prefer

    # Optional: Stop the letter timer immediately
    if has_node("LetterTimer"):
        $LetterTimer.stop()
    print("Game Paused.")

# Function to handle unpausing the game
func _unpause_game():
    is_paused = false
    get_tree().paused = false
    
    # Hide the pause menu
    pause_menu_node.hide()
    
    # Restart the letter timer
    if has_node("LetterTimer"):
        $LetterTimer.start()
    print("Game Resumed.")
    
# Button connection handlers
func _on_resume_button_pressed():
    _unpause_game()

func _on_quit_button_pressed():
    get_tree().quit() # Quits the application

func _spawn_floating_score(points_gained):
    # Instantiate the scene
    var floating_score_node = floating_score_scene.instantiate()
    
    # Get critical nodes (We know these names are correct now)
    var score_label = floating_score_node.get_node("ScoreLabel")
    var animator = floating_score_node.get_node("Animator")

    # Set the text
    score_label.text = "+" + str(points_gained)
    
    # Get the GameUI node and add the child
    var game_ui = get_node("GameUI") 
    game_ui.add_child(floating_score_node) 
    
    # Set position (using global_position to place it correctly inside the UI parent)
    var slots_container = get_node("GameUI/SubmissionSlots")
    var container_center = slots_container.global_position + (slots_container.size / 2.0)
    floating_score_node.global_position = container_center
    
    print("DEBUG: Spawning Score at: ", container_center)
    
    # --- CRITICAL FIX: Ensure the node is ready before playing the animation ---
    
    # Wait for one frame (This ensures the node is fully processed and ready)
    await get_tree().process_frame
    
    # Explicitly play the animation
    animator.play("float_away") 
    
    # Connect cleanup signal
    #animator.animation_finished.connect(floating_score_node.queue_free)
    animator.animation_finished.connect(func(_anim_name): floating_score_node.queue_free())
    
# --- WORD COLLECTION ---

func add_letter_to_word(letter_node):
    # Loop through all 5 slots
    for i in range(submission_slots.size()):
        var slot_node = submission_slots[i]
        
        # Find the size of the letter block (assuming 50x50 from previous context)
        var letter_size = letter_node.get_node("TileBackground").size

        # Check if the letter was dropped onto this specific slot AND the slot is empty
        if slot_node.get_global_rect().has_point(letter_node.global_position) and letter_in_slot[i] == null:
            
            # --- VISUAL FEEDBACK ADDED HERE ---
            # Temporarily change the slot's color to show it's filled
            #slot_node.color = Color._from_html("#33CC33") # Bright Green (Success!)     
            slot_node.color = Color(0.2, 0.8, 0.2) # R=33, G=CC, B=33       
            # 1. Slot is filled: Store the letter node reference
            # 1. CRITICAL: Change the letter's color to show it's locked/placed
            if letter_node.has_node("TileBackground"): # Updated node check
    # Change to a dark color, e.g., Black (0, 0, 0)
                letter_node.get_node("TileBackground").modulate = Color.BLACK # Updated node path
            letter_in_slot[i] = letter_node
            
            # ... (slot filling and freezing code remains the same) ...

            # 3. Attach the letter to the slot and center it
            letter_node.reparent(slot_node)
            
            # 💥 FIX 1: Set the letter's position to the center of the slot.
            # The letter's origin must be offset by half its size to center the block.
            # Slot size / 2  -  Letter Size / 2  = Center difference (This may need adjustment)
            var center_x = (slot_node.size.x / 2.0) - (letter_size.x / 2.0)
            var center_y = (slot_node.size.y / 2.0) - (letter_size.y / 2.0)
            
            letter_node.position = Vector2(center_x, center_y) 

            # 4. REMOVE THIS LINE (It was an older attempt at fixing it)
            # letter_node.get_node("ColorRect").position = -letter_node.get_node("ColorRect").size / 2

            _arrange_letters() 
            return

    # If the function reaches here, the letter was dropped on a full slot or outside the area.
    # The letter's drag-and-drop logic will resume physics and let it fall.

    # If the function reaches here, the letter was dropped on a full slot or outside the area.
    # The letter's drag-and-drop logic will resume physics and let it fall.

# In game.gd:
# In game.gd:
# In game.gd:
func remove_letter_from_slot(letter_node):
    var empty_color = Color(0.314, 0.314, 0.314) # Replace with your actual color
    
    for i in range(letter_in_slot.size()):
        if letter_in_slot[i] == letter_node:
            
            print("--- REMOVAL DEBUG ---")
            print("Before Array: ", letter_in_slot)
            print("Clearing index: ", i)
            
            # 1. Reset the slot color
            submission_slots[i].color = empty_color 
            
            # 2. CRITICAL: Clear the reference (This should fix both word and slot lock)
            letter_in_slot[i] = null 
            
            print("After Array: ", letter_in_slot)
            
            # 3. Update the word display
            _arrange_letters() 
            return
            
func _arrange_letters():
    # Build the word string by reading the array
    var current_word_string = ""
    for node in letter_in_slot:
        if node != null:
            # If a letter node is present, use its character
            current_word_string += node.character
        else:
            # If the entry is null, use a placeholder
            current_word_string += "_" 
        
    var word_display = get_node("GameUI/ScoreContainer/WordLabel")
    word_display.text = "WORD: " + current_word_string


func _clear_current_word():
    # 1. Delete the letter nodes from the game
    for node in letter_in_slot:
        if node != null:
            node.queue_free()
    
    # 2. Reset the tracking array
    letter_in_slot = [null, null, null, null, null]
    
    # 3. Restore the slot colors back to the default transparent state
    # Replace the old 'var empty_color = Color()' with the constant:
    for slot_node in submission_slots:
        # Check if the node is a ColorRect (uses .color) or a TextureRect (uses .modulate)
        # Since you want both to be invisible, setting modulate is safest as it works on all Control nodes.
        slot_node.self_modulate = TRANSPARENT_COLOR
        slot_node.modulate = Color.WHITE
        
        # If the slot was a ColorRect, you can reset the color property too, just in case:
        if slot_node is ColorRect:
            slot_node.color = TRANSPARENT_COLOR
        
    _arrange_letters()

#
#func _update_score_display():
    #var score_display = get_node("GameUI/ScoreContainer/ScoreLabel")
    #score_display.text = "SCORE: " + str(score)

# --- GAME OVER LOGIC ---

func _process(delta: float):
    # We check the height of the highest-stacked letter every frame.
    #_check_game_over()
    pass
    
# In game.gd: Modify or create this function
#func _process_submission():
func _on_submit_button_pressed():
    var current_word_string = ""
    var total_points = 0
    var is_word_valid = false # Flag for dictionary check
    var current_word_length = 0 # Track how many slots are filled consecutively

    # 1. Build the word string by reading CONSECUTIVE filled slots
    for letter_node in letter_in_slot:
        if letter_node != null:
            # If the slot has a letter, add its data and continue
            current_word_string += letter_node.character
            total_points += letter_node.points
            current_word_length += 1
        else:
            # The first empty slot encountered stops the word construction
            break 
            
    # ADDED DEBUG PRINT
    print("--- DEBUG: Built Word:", current_word_string, ", Length:", current_word_length)

    # 2. Validation Check
    if current_word_length < MIN_WORD_LENGTH:
        print("Submission failed: Word must be at least ", MIN_WORD_LENGTH, " letters long.")
        return # Exit if the word is too short
        
    var submitted_word_for_check = current_word_string.to_upper() 
    
    if dictionary_set.has(submitted_word_for_check):
        
        # --- SUCCESS: VALID WORD ---
        print("VALID WORD: ", submitted_word_for_check, " (+", total_points, " points)") 
        _spawn_floating_score(total_points)
        
        current_score += total_points
        is_word_valid = true # Mark it as valid so we clear it
        
        _update_score_display()
        
    else:
        # --- FAILURE: INVALID WORD ---
        print("INVALID WORD (Failed Dictionary Lookup): ", submitted_word_for_check)
        _show_message() # Call without argument
        # NOTE: Since the word is invalid, we DO NOT clear the word.
        # The user must remove letters and try a different word.
        return # Exit the function, leaving the letters in the slots

    # 3. Clear the slots ONLY IF the word was valid
    if is_word_valid:
        _clear_current_word()
# NEW: Function to display the score (needs a Label in your GameUI scene)
func _update_score_display():
    var score_label = get_node("GameUI/ScoreContainer/ScoreLabel") # Adjust path as needed
    score_label.text = "SCORE: " + str(current_score)

func _check_game_over():
    var highest_y = get_viewport_rect().size.y # Start at the bottom of the screen
    var is_game_over = false
    
    # Iterate through all physics children (our letter nodes)
    for node in get_children():
        if node is RigidBody2D: # Check if the node is one of our letters
            if node.global_position.y < highest_y:
                highest_y = node.global_position.y
            
            # Check if the highest point of the stack is above the game over line
            if highest_y < max_stack_height:
                is_game_over = true
                break
                
    if is_game_over:
        get_tree().paused = true
        print("GAME OVER! Highest stack reached Y=" + str(highest_y))
        # TODO: Add a Game Over UI screen and restart/quit option

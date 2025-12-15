extends Node2D


const LETTER_DISTRIBUTION = {
    "A": 90, "B": 20, "C": 20, "D": 40, "E": 120, "F": 20, "G": 30, "H": 20,
    "I": 90, "J": 10, "K": 10, "L": 40, "M": 20, "N": 60, "O": 80, "P": 20,
    "Q": 10, "R": 60, "S": 40, "T": 60, "U": 40, "V": 20, "W": 20, "X": 10,
    "Y": 20, "Z": 10, "-": 0 # Blank tile represented by "_"
}

#const LETTER_DISTRIBUTION = {
    #"A": 90, "E":100, "S":100, "L":100
#}

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
const NUM_COLUMNS = 6
const HORIZONTAL_MARGIN = 380 # 20 pixels on the left and right edges
var pause_menu_scene = preload("res://pause_menu.tscn")
var pause_menu_node = null # Variable to hold the instantiated pause menu
# Variable to track the pause state
var is_paused = false
const TRANSPARENT_COLOR = Color(1, 1, 1, 0) # R, G, B = 1 (White base), Alpha = 0 (Fully Invisible)
const MIN_WORD_LENGTH = 1
# The path should reflect the location of your Label node
@onready var error_image: TextureRect = $ErrorMessageContainer/ErrorImage 
@onready var error_animator: AnimationPlayer = $ErrorMessageContainer/ErrorImage/ErrorAnimator
const WORD_FLASH_SCENE = preload("res://word_flash.tscn")

@onready var word_display_list = $GameUI/WordListPanel/WordScrollContainer/WordDisplayList
var used_words = []

#END GAME STUFF
# Define the number of columns and the max visual height
var column_height_track = []
const GAME_OVER_Y_LIMIT = 100 # This is the Y-coordinate limit (e.g., 100 pixels from the top)
const GAME_OVER_SCREEN_SCENE = preload("res://GameOverScreen.tscn")
const VALID_WORD_SOUND = preload("res://punch.mp3")

func _populate_available_letters():
    available_letters.clear()
    for char in LETTER_DISTRIBUTION:
        for i in range(LETTER_DISTRIBUTION[char]):
            available_letters.append(char)
    # Shuffle the list for good measure
    available_letters.shuffle()
    print("Available letter pool created with size: ", available_letters.size())

func _show_flash_word(word: String):
    var flash_instance = WORD_FLASH_SCENE.instantiate()

    # Add to the GameUI (or a high-level canvas layer) so it draws on top
    # Assuming you have a node named "GameUI" or similar CanvasLayer
    var ui_layer = get_node("GameUI") 
    ui_layer.add_child(flash_instance)

    # Call the setup function we wrote
    flash_instance.display_word(word)
    
func _add_word_to_list(word: String, points: int):
    # 1. Create a new Label node
    var word_label = Label.new()
    
    # 2. Format the text (e.g., "WORD (XX pts)")
    word_label.text = "%s (%d pts)" % [word, points]
    
    # 3. Apply styling (optional, but makes it look nice)
    # You might want to use a specific font/style from your main theme
    word_label.add_theme_color_override("font_color", Color.BLACK)
    
    # 4. Add the Label to the VBoxContainer
    word_display_list.add_child(word_label)
    
    # 5. Crucial: Scroll to the bottom to show the newest word
    # This must be done after adding the child
    await get_tree().process_frame # Wait one frame for layout to update
    word_display_list.get_parent().scroll_vertical = word_display_list.size.y
    
# Function to play a one-shot sound effect
func _play_sound_effect(sound_stream: AudioStream):
    # 1. Create a temporary AudioStreamPlayer
    var audio_player = AudioStreamPlayer.new()
    
    # 2. Assign the sound stream
    audio_player.stream = sound_stream
    
    # 3. Add it to the scene tree
    add_child(audio_player)
    
    # 4. Connect a signal to delete the player after the sound finishes
    # This prevents the scene tree from getting cluttered with finished audio players.
    audio_player.finished.connect(audio_player.queue_free)
    
    # 5. Play the sound
    audio_player.play()

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
    _setup_game_over_line()
    $LetterTimer.start()
    _populate_available_letters()
    _load_dictionary() # <-- NEW: Load the dictionary here!
    # CRITICAL: Start the timer to begin spawning letters
    if has_node("LetterTimer"): # Ensure your timer node is named "LetterTimer"
        $LetterTimer.start()
    var viewport_height = get_viewport_rect().size.y
    for i in range(NUM_COLUMNS):
    # Initialize each column's highest point to the bottom of the screen
        column_height_track.append(viewport_height)
    
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
    
    # 1. Create a new instance of the letter
    var new_letter_node = letter_scene.instantiate()
    
    # Check if the pool is empty
    if available_letters.size() > 0:
        var rand_index = randi() % available_letters.size()
        # Take the character out of the pool
        var selected_char = available_letters.pop_at(rand_index)    
        
        # 2. Pass the selected character AND its point value to the letter node
        var points = LETTER_POINTS.get(selected_char, 0)
        new_letter_node.set_letter_data(selected_char, points)    
    else:
        # Stop spawning if the pool is empty
        $LetterTimer.stop()
        print("Letter pool empty! Game over or reshuffle needed.")
        return # Stop execution if no letters are available
        
    # 3. Set position (Column-based random X, fixed Y at top)
    var viewport_width = get_viewport_rect().size.x

    # Uses a safe default (50.0) if the node isn't found
    var tile_width = 50.0 
    if new_letter_node.has_node("TileBackground"):
        tile_width = new_letter_node.get_node("TileBackground").size.x

    var usable_width = viewport_width - (2 * HORIZONTAL_MARGIN)
    var column_width = usable_width / NUM_COLUMNS
    var random_column_index = randi() % NUM_COLUMNS
    var column_start_x = HORIZONTAL_MARGIN + (random_column_index * column_width)
    var center_x_position = column_start_x + (tile_width / 2.0)

    # Y is always -50 to start the tile just above the screen
    new_letter_node.position = Vector2(center_x_position, -50)

    # --- NEW: ADD GRACE PERIOD TIMER TO PREVENT IMMEDIATE GAME OVER ---
    var grace_timer = Timer.new()
    grace_timer.wait_time = 10.5 # 0.5 second grace period
    grace_timer.autostart = true
    grace_timer.one_shot = true

    # When the timer runs out, set the letter's flag to allow height checking
    grace_timer.timeout.connect(func():
        new_letter_node.is_newly_spawned = false
        grace_timer.queue_free()
    )

    new_letter_node.add_child(grace_timer) # Add the timer as a child of the letter
    # ------------------------------------------------------------------
    
    # 4. Connect the new right-click signal to the auto-slot function
    new_letter_node.right_clicked_for_slot.connect(_auto_slot_letter)
    
    # 5. Add the letter instance with the correct data to the game world
    add_child(new_letter_node)


func _on_letter_ejected(letter_node_to_eject):
    
    # 1. Find the index of the slot holding the ejected letter
    var slot_index = -1
    for i in range(letter_in_slot.size()):
        if letter_in_slot[i] == letter_node_to_eject:
            slot_index = i
            break
            
    if slot_index == -1:
        print("Error: Ejected letter not found in any slot. Cannot proceed.")
        return
        
    # 2. Call the function that performs the action
    _eject_letter_from_slot(slot_index)
    
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
    # Set the flag to true for input differentiation
    letter_node.is_in_slot = true
    
    # Connect the new ejection signal to the handler function
    # NOTE: You must disconnect the old right_clicked_for_slot signal 
    # if you want to save processing time, but this is the critical connection:
    #if not letter_node.letter_ejected.is_connected(_on_letter_ejected):
        #letter_node.letter_ejected.connect(_on_letter_ejected)
    if not letter_node.letter_ejected.is_connected(Callable(self, "_on_letter_ejected")):
    # Connect using Callable(object, "function_name")
        letter_node.letter_ejected.connect(Callable(self, "_on_letter_ejected"))
        
    # Update the UI text
    _arrange_letters()

func _setup_game_over_line():
    
    # 1. Get the Line2D node reference
    var line = $GameOverLine 
    
    if line == null:
        # This will help debug if the node wasn't added correctly
        print("ERROR: GameOverLine node not found. Did you add it to the Game scene?")
        return
        
    # 2. Get viewport dimensions (Needed for line width)
    var viewport_rect = get_viewport_rect()
    var viewport_width = viewport_rect.size.x
    
    # 3. Define line properties
    line.default_color = Color.BLACK
    line.width = 3.0 # Set the line thickness to 3 pixels
    line.z_index = 10 # Ensure the line is drawn on top of the falling letters

    # 4. Calculate the start and end points
    # The line is placed at the GAME_OVER_Y_LIMIT, 
    # but only across the area where letters fall (between the margins).
    
    # Start Point (Left side of the playable area)
    var start_x = HORIZONTAL_MARGIN
    var start_y = GAME_OVER_Y_LIMIT
    
    # End Point (Right side of the playable area)
    # Total width of the screen - the right margin
    var end_x = viewport_width - HORIZONTAL_MARGIN
    var end_y = GAME_OVER_Y_LIMIT
    
    # 5. Set the points array for the Line2D node
    # Line2D points are relative to the Line2D node's position (which we assume is 0,0)
    line.points = PackedVector2Array([
        Vector2(start_x, start_y), 
        Vector2(end_x, end_y)
    ])
      

# In game.gd: Replace the entire func _spawn_floating_score
func _input(event):
    # Check if the Escape key (or 'ui_cancel' action) was just pressed
    if event.is_action_pressed("ui_cancel"):
        if is_paused:
            _unpause_game()
        else:
            _pause_game()
    # --- NEW: Check for Right-Click to Eject Letter ---
    if event.is_action_pressed("mouse_right_click"): # Assuming you defined "mouse_right_click"
        var mouse_pos = get_viewport().get_mouse_position()
        
        # Loop through all submission slots
        for i in range(submission_slots.size()):
            var slot_node = submission_slots[i]
            
            # Check if the mouse is over the slot
            if slot_node.get_global_rect().has_point(mouse_pos):
                
                # Check if the slot has a letter in it
                if letter_in_slot[i] != null:
                    
                    # Call the new ejection function
                    _eject_letter_from_slot(i)
                    get_tree().set_input_as_handled()
                    return # Exit after handling the click

          
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
    
# --- HANDLER FOR LETTER EJECTION SIGNAL (STEP 1) ---
# This function is called by the placed letter when the player right-clicks it.
func _eject_letter_from_slot(slot_index: int):
    
    # 1. Get the letter node being ejected and its data
    var letter_node_to_eject = letter_in_slot[slot_index]
    if letter_node_to_eject == null:
        return 
    
    var letter_char = letter_node_to_eject.character
    var letter_points = letter_node_to_eject.points
    
    # 2. Get the slot's position for the new letter's drop point
    var slot_node = submission_slots[slot_index]
    var slot_center_global = slot_node.global_position + (slot_node.size / 2.0)
    
    # 3. Clear the slot's tracking and visual state
    # Reset the slot color to the desired TRANSPARENT state (using your constant)
    if slot_node is ColorRect:
        slot_node.color = TRANSPARENT_COLOR 
    
    letter_in_slot[slot_index] = null # Clear tracking array
    _arrange_letters() # Update the word display

    # 4. REMOVE the old letter node from the game
    letter_node_to_eject.queue_free()
    
    # 5. Instantiate a NEW letter node
    var new_letter_node = letter_scene.instantiate()
    
    # 6. Initialize the new letter data
    new_letter_node.set_letter_data(letter_char, letter_points)
    
    # 7. Set the starting position high above the viewport
    var drop_x = slot_center_global.x 
    var drop_y = -100 
    new_letter_node.global_position = Vector2(drop_x, drop_y) 

    # --- NEW: ADD GRACE PERIOD TIMER TO PREVENT IMMEDIATE GAME OVER ---
    var grace_timer = Timer.new()
    grace_timer.wait_time = 10.5 # 0.5 second grace period
    grace_timer.autostart = true
    grace_timer.one_shot = true

    grace_timer.timeout.connect(func():
        new_letter_node.is_newly_spawned = false
        grace_timer.queue_free()
    )

    new_letter_node.add_child(grace_timer) # Add the timer as a child of the letter
    # ------------------------------------------------------------------
    
    # 8. Re-connect the necessary signals for the new falling letter
    new_letter_node.right_clicked_for_slot.connect(_auto_slot_letter) 
    #new_letter_node.letter_ejected.connect(_on_letter_ejected)
    new_letter_node.letter_ejected.connect(Callable(self, "_on_letter_ejected"))
    
    
    # 9. Add the new letter to the root of the game scene to start falling
    add_child(new_letter_node)
    
    print("Ejected and re-spawned letter: ", letter_char, " from slot ", slot_index)


# --- CORE EJECTION AND RE-SPAWNING LOGIC (STEP 2) ---
# This function does the heavy lifting of clearing the old node and launching the new one.
#func _eject_letter_from_slot(slot_index: int):
    #
    ## 1. Get the letter node being ejected and its data
    #var letter_node_to_eject = letter_in_slot[slot_index]
    #if letter_node_to_eject == null:
        #return 
    #
    #var letter_char = letter_node_to_eject.character
    #var letter_points = letter_node_to_eject.points
    #
    ## 2. Get the slot's position for the new letter's drop point
    #var slot_node = submission_slots[slot_index]
    #var slot_center_global = slot_node.global_position + (slot_node.size / 2.0)
    #
    ## 3. Clear the slot's tracking and visual state
    #var empty_color = Color(0.314, 0.314, 0.314,0) # Use your actual empty color
    ## Reset the slot color (Assuming slots are ColorRects)
    #if slot_node is ColorRect:
        #slot_node.color = empty_color 
    #
    #letter_in_slot[slot_index] = null # Clear tracking array
    #_arrange_letters() # Update the word display
#
    ## 4. REMOVE the old letter node from the game
    #letter_node_to_eject.queue_free()
    #
    ## 5. Instantiate a NEW letter node
    #var new_letter_node = letter_scene.instantiate()
    #
    ## 6. Initialize the new letter data
    #new_letter_node.set_letter_data(letter_char, letter_points)
    #
    ## 7. Set the starting position high above the viewport
    #var drop_x = slot_center_global.x 
    #var drop_y = -100 
    #new_letter_node.global_position = Vector2(drop_x, drop_y) 
    #
    ## 8. Re-connect the necessary signals for the new falling letter
    #
    ## Connection for placing it via right-click (when falling)
    ## The new instance needs this connection just like the initial spawned letters
    #new_letter_node.right_clicked_for_slot.connect(_auto_slot_letter) 
    #
    ## Connection for ejecting it via right-click (when placed)
    ## This ensures the new node can be ejected later if placed again
    #new_letter_node.letter_ejected.connect(_on_letter_ejected)
    #
    ## 9. Add the new letter to the root of the game scene to start falling
    #add_child(new_letter_node)
    #
    #print("Ejected and re-spawned letter: ", letter_char, " from slot ", slot_index)

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
    _check_game_over()
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
    if used_words.has(submitted_word_for_check):
        print("ERROR: Word already submitted!")
        # Optional: Play an error sound/flash a message
        # _play_sound_effect(ERROR_SOUND) # If you create one
        _show_flash_word("USED") # Use your existing flash function for feedback
        #_clear_submission_slots()
        return
        
    if dictionary_set.has(submitted_word_for_check):
        used_words.append(submitted_word_for_check)
        # --- SUCCESS: VALID WORD ---
        print("VALID WORD: ", submitted_word_for_check, " (+", total_points, " points)") 
        _spawn_floating_score(total_points)
        
        current_score += total_points
        is_word_valid = true # Mark it as valid so we clear it
        _play_sound_effect(VALID_WORD_SOUND)
        _show_flash_word(submitted_word_for_check)
        _update_score_display()
        _add_word_to_list(submitted_word_for_check, total_points)
        current_score += total_points
        
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

#func _check_game_over():
    #var highest_y = get_viewport_rect().size.y # Start at the bottom of the screen
    #var is_game_over = false
    #
    ## Iterate through all physics children (our letter nodes)
    #for node in get_children():
        #if node is RigidBody2D: # Check if the node is one of our letters
            #if node.global_position.y < highest_y:
                #highest_y = node.global_position.y
            #
            ## Check if the highest point of the stack is above the game over line
            #if highest_y < max_stack_height:
                #is_game_over = true
                #break
                #
    #if is_game_over:
        #get_tree().paused = true
        #print("GAME OVER! Highest stack reached Y=" + str(highest_y))
        ## TODO: Add a Game Over UI screen and restart/quit option
func _check_game_over():
    
    # 1. Reset tracking array for this frame's check
    var viewport_height = get_viewport_rect().size.y
    for i in range(NUM_COLUMNS):
        # Reset to bottom of the screen (lowest danger)
        column_height_track[i] = viewport_height 
        
    var is_game_over = false
    
    # 2. Define column geometry
    var viewport_width = get_viewport_rect().size.x
    var usable_width = viewport_width - (2 * HORIZONTAL_MARGIN)
    var column_width = usable_width / NUM_COLUMNS
    
    # 3. Iterate through all letters
    for node in get_children():
        
        # We only check physics objects (letters) that are NOT in the slot
        if node is RigidBody2D and not node.freeze:
            if node.is_newly_spawned:
                continue # Skip to the next node in the loop
            # CRITICAL CHECK: Ignore blocks that are actively falling (linear_velocity.y > 5.0)
            if abs(node.linear_velocity.y) < 5.0: # Check only blocks that have settled
                
                # --- Get Letter Dimensions Safely ---
                var letter_height = 50.0 # Default safe value
                if node.has_node("ColorRect"):
                     letter_height = node.get_node("ColorRect").size.y
                
                # Get the node's central global X position
                var letter_center_x = node.global_position.x
                
                # Calculate the TOP EDGE of the letter
                var letter_top_y = node.global_position.y - (letter_height / 2.0) 

                # Calculate which column the center of the letter falls into
                var column_x_offset = letter_center_x - HORIZONTAL_MARGIN
                var column_index = int(column_x_offset / column_width)
                
                # Ensure the index is valid
                if column_index >= 0 and column_index < NUM_COLUMNS:
                    
                    # 4. Update the highest Y-position for this column
                    if letter_top_y < column_height_track[column_index]:
                        column_height_track[column_index] = letter_top_y
                        
                        # 5. Check Game Over Condition
                        if letter_top_y < GAME_OVER_Y_LIMIT:
                            is_game_over = true
                            break # Found a column that exceeds the height, stop checking
                        
    # 6. Trigger Game Over State
    if is_game_over:
        get_tree().paused = true
        $LetterTimer.stop()
        print("GAME OVER! A column stack exceeded the Y limit (Y=", GAME_OVER_Y_LIMIT, ")")
        # TODO: Implement a visible Game Over screen UI here.
        _show_game_over_screen()


func _show_game_over_screen():
    # 1. Instantiate the screen
    var game_over_screen = GAME_OVER_SCREEN_SCENE.instantiate()
    game_over_screen.process_mode = Node.PROCESS_MODE_ALWAYS
    # 2. Connect the restart signal to the handler function
    # NOTE: Using Callable is the safest method to connect signals.
    game_over_screen.restart_requested.connect(Callable(self, "_on_restart_requested"))
    
    # 3. Add it to the scene tree
    add_child(game_over_screen)

func _on_restart_requested():
    # 1. Unpause the game is CRITICAL (since the game was paused on game over)
    get_tree().paused = false 
    
    # 2. Get the path of the current scene.
    # We must save this to a variable first because change_scene_to_file 
    # will clear the current scene reference.
    var current_scene_path = get_tree().current_scene.scene_file_path
    
    # 3. Reload the scene. This restarts the game from scratch.
    var error = get_tree().change_scene_to_file(current_scene_path)
    
    if error != OK:
        print("ERROR: Could not restart scene at path: ", current_scene_path)

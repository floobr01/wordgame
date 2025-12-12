extends Node2D


const LETTER_DISTRIBUTION = {
    "A": 9, "B": 2, "C": 2, "D": 4, "E": 12, "F": 2, "G": 3, "H": 2,
    "I": 9, "J": 1, "K": 1, "L": 4, "M": 2, "N": 6, "O": 8, "P": 2,
    "Q": 1, "R": 6, "S": 4, "T": 6, "U": 4, "V": 2, "W": 2, "X": 1,
    "Y": 2, "Z": 1, "_": 2 # Blank tile represented by "_"
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
# Variable to hold all available characters flattened (used for random selection)
var available_letters = []
# Game State Variables
var current_word_nodes = [] # Holds the list of letter nodes currently in the box
var submission_slots = []   # Array to hold references to the 5 ColorRect nodes
var letter_in_slot = [null, null, null, null, null] # Tracks the actual letter node in each slot (null = empty)
var score = 0
var max_stack_height = 100 # Y-coordinate for game over (e.g., 100 pixels from top)

func _populate_available_letters():
    available_letters.clear()
    for char in LETTER_DISTRIBUTION:
        for i in range(LETTER_DISTRIBUTION[char]):
            available_letters.append(char)
    # Shuffle the list for good measure
    available_letters.shuffle()
    print("Available letter pool created with size: ", available_letters.size())

func _ready():
    # Set up Timer connection and Autostart in the editor
    # Connect the Submit button
    $LetterTimer.start()
    _populate_available_letters()
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
        
    # 3. Set position (Random X, fixed Y at top)
    var viewport_width = get_viewport_rect().size.x
    var random_x = randf_range(50, viewport_width - 50) 
    new_letter_node.position = Vector2(random_x, -50)
    
    # 4. Add the letter instance with the correct data to the game world
    add_child(new_letter_node)
# --- WORD COLLECTION ---

func add_letter_to_word(letter_node):
    # Loop through all 5 slots
    for i in range(submission_slots.size()):
        var slot_node = submission_slots[i]
        
        # Find the size of the letter block (assuming 50x50 from previous context)
        var letter_size = letter_node.get_node("ColorRect").size 

        # Check if the letter was dropped onto this specific slot AND the slot is empty
        if slot_node.get_global_rect().has_point(letter_node.global_position) and letter_in_slot[i] == null:
            
            # --- VISUAL FEEDBACK ADDED HERE ---
            # Temporarily change the slot's color to show it's filled
            #slot_node.color = Color._from_html("#33CC33") # Bright Green (Success!)     
            slot_node.color = Color(0.2, 0.8, 0.2) # R=33, G=CC, B=33       
            # 1. Slot is filled: Store the letter node reference
            # 1. CRITICAL: Change the letter's color to show it's locked/placed
            if letter_node.has_node("ColorRect"):
                 # Change to a dark color, e.g., Black (0, 0, 0)
                 letter_node.get_node("ColorRect").modulate = Color.BLACK
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


# --- WORD SUBMISSION AND SCORING ---

func _on_submit_button_pressed():
    var word_to_check = ""
    for node in letter_in_slot:
        if node == null:
            # If any slot is empty, the word is not complete
            print("Submission failed: Word is not 5 letters long.")
            return # Exit the submission process
            
        word_to_check += node.character
        
    # Word is exactly 5 letters long!
    print("Attempting to submit word: " + word_to_check)
        
    # --- PLACEHOLDER WORD CHECK ---
    # Example scoring for a 5-letter word:
    if word_to_check.length() == 5 and word_to_check.begins_with("A"):
        _word_is_valid(word_to_check)
    else:
        _word_is_invalid()


func _word_is_valid(word):
    print("VALID WORD: " + word)
    var points = word.length() * 10 
    score += points
    _update_score_display()
    _clear_current_word()


func _word_is_invalid():
    print("INVALID WORD!")
    # In a real game, you might show an error message instead of clearing instantly.
    _clear_current_word()

func _clear_current_word():
    # 1. Delete the letter nodes from the game
    for node in letter_in_slot:
        if node != null:
            node.queue_free()
    
    # 2. Reset the tracking array
    letter_in_slot = [null, null, null, null, null]
    
    # 3. Restore the slot colors back to the default empty color
    var empty_color = Color()    
    for slot_node in submission_slots:
        slot_node.color = empty_color
    
    _arrange_letters()


func _update_score_display():
    var score_display = get_node("GameUI/ScoreContainer/ScoreLabel")
    score_display.text = "SCORE: " + str(score)

# --- GAME OVER LOGIC ---

func _process(delta: float):
    # We check the height of the highest-stacked letter every frame.
    #_check_game_over()
    pass

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

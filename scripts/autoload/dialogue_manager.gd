extends Node

# Current state (minimal)
var is_message_showing: bool = false
var message_queue: Array[Dictionary] = []

# ADD THIS: Prevent rapid-fire messages
var input_cooldown: float = 0.0
var cooldown_duration: float = 0.2  # 200ms cooldown between messages

# Signals
signal message_received(speaker: String, message: String, duration: float)
signal message_dismissed()

func _ready():
	message_dismissed.connect(_on_message_dismissed)
	print("[DialogueManager] Initialized")

# ADD THIS
func _process(delta):
	if input_cooldown > 0:
		input_cooldown -= delta

# Public API - the only way to show dialogue
func show_message(speaker: String, message: String, duration: float = -1.0):
	"""
	Show a message in the communicator.
	speaker: "Lucy", "Chad", "ScanBoy"
	message: The text to display
	duration: Optional override for display time (default: 4.0s)
	"""
	
	# ADD THIS: Prevent rapid-fire
	if input_cooldown > 0:
		print("[DialogueManager] Message rejected (cooldown active)")
		return
	
	print("[DialogueManager] show_message called: %s says '%s'" % [speaker, message])
	
	if is_message_showing:
		# Queue it
		print("[DialogueManager] Message queued (another message active)")
		message_queue.append({
			"speaker": speaker,
			"message": message,
			"duration": duration
		})
		return
	
	_display_message(speaker, message, duration)

func _display_message(speaker: String, message: String, duration: float):
	is_message_showing = true
	input_cooldown = cooldown_duration  # ADD THIS
	print("[DialogueManager] Displaying message from %s" % speaker)
	message_received.emit(speaker, message, duration)

func _on_message_dismissed():
	print("[DialogueManager] Message dismissed")
	is_message_showing = false
	
	# MODIFY THIS: Add a tiny delay before processing next message
	# This ensures the UI has fully reset
	await get_tree().create_timer(0.1).timeout
	
	# Show next queued message if any
	if message_queue.size() > 0:
		print("[DialogueManager] Processing queued message (%d remaining)" % message_queue.size())
		var next_msg = message_queue.pop_front()
		_display_message(next_msg.speaker, next_msg.message, next_msg.duration)

# Debug helper
func _input(event):
	if not OS.is_debug_build():
		return
	
	if event.is_action_pressed("ui_page_up"):  # Page Up key for testing
		show_message("Lucy", "Debug test message from Lucy!")
		print("[DialogueManager] Debug message triggered (Page Up)")
	
	if event.is_action_pressed("ui_page_down"):  # Page Down key for testing
		show_message("Chad", "Debug test message from Chad!")
		print("[DialogueManager] Debug message triggered (Page Down)")
		
	# In dialogue_manager.gd _input(), add:
	if event.is_action_pressed("ui_home"):  # Home key
		var lucy_line = LucyDialogue.get_line("greeting")
		show_message("Lucy", lucy_line)
		print("[DialogueManager] Lucy greeting: %s" % lucy_line)

	if event.is_action_pressed("ui_end"):  # End key
		var chad_line = ChadDialogue.get_line("observation")
		show_message("Chad", chad_line)
		print("[DialogueManager] Chad observation: %s" % chad_line)

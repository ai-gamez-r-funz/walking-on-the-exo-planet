extends Control

@onready var panel: PanelContainer = $CommunicatorPanel
@onready var portrait: TextureRect = $CommunicatorPanel/Content/Portrait
@onready var speaker_name: Label = $CommunicatorPanel/Content/VBox/SpeakerName
@onready var message_text: Label = $CommunicatorPanel/Content/VBox/MessageText

# Speaker portraits (we'll add these later)
var portraits: Dictionary = {
	"Lucy": preload("res://assets/icons/lucy_icon.png"),
	"Chad": preload("res://assets/icons/chad_icon.png"), 
	"ScanBoy": preload("res://assets/icons/scanner_icon.png"),
}

# Display timing
var message_duration: float = 4.0  # Auto-dismiss after 4 seconds
var fade_duration: float = 0.3
var dismiss_timer: float = 0.0
var is_showing: bool = false
var can_manual_dismiss: bool = false

func _ready():
	# Validate node references
	assert(panel != null, "CommunicatorPanel not found!")
	assert(portrait != null, "Portrait not found!")
	assert(speaker_name != null, "SpeakerName not found!")
	assert(message_text != null, "MessageText not found!")
	
	# Connect to dialogue manager (will add this next)
	DialogueManager.message_received.connect(_on_message_received)
	DialogueManager.message_dismissed.connect(_on_message_dismissed)
	
	# Start hidden
	panel.modulate.a = 0.0
	panel.visible = false
	
	print("[CommunicatorDisplay] Ready and initialized")
	

func _process(delta):
	if not is_showing:
		return
	
	dismiss_timer += delta
	
	# Allow manual dismiss after 0.5s (prevents accidental skip)
	if dismiss_timer >= 0.5:
		can_manual_dismiss = true
	
	# Auto-dismiss after duration
	if dismiss_timer >= message_duration:
		_dismiss_message()

func _input(event):
	if not is_showing or not can_manual_dismiss:
		return
	
	# Press E or Space to dismiss
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_dismiss_message()
		get_viewport().set_input_as_handled()

# Called by DialogueManager via signal
func _on_message_received(speaker: String, message: String, duration_override: float = -1.0):
	print("[CommunicatorDisplay] Message received from %s: %s" % [speaker, message])
	
	# Set content
	speaker_name.text = speaker.to_upper()
	message_text.text = message
	
	# Set portrait (if available)
	if portraits.has(speaker) and portraits[speaker] != null:
		portrait.texture = portraits[speaker]
		portrait.visible = true
	else:
		portrait.visible = false  # Hide if no portrait
	
	# Override duration if specified
	if duration_override > 0:
		message_duration = duration_override
	else:
		message_duration = 4.0
	
	# Show with fade-in
	is_showing = true
	can_manual_dismiss = false
	dismiss_timer = 0.0
	panel.visible = true
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, fade_duration)

func _dismiss_message():
	if not is_showing:
		return
	
	print("[CommunicatorDisplay] Dismissing message (starting fade-out)")
	
	is_showing = false
	can_manual_dismiss = false
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func(): 
		panel.visible = false
		print("[CommunicatorDisplay] Fade-out complete, notifying DialogueManager")
		# Only notify AFTER fade-out is complete
		if DialogueManager:
			DialogueManager.message_dismissed.emit()
	)

func _on_message_dismissed():
	# Message dismissed notification received
	pass

# Debug function - test the UI
func test_message(speaker: String = "Lucy", message: String = "This is a test message!"):
	_on_message_received(speaker, message, 4.0)

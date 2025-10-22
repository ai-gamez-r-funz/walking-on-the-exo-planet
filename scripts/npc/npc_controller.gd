extends Node3D
class_name NPCController

# ============================================================================
# CONFIGURATION
# ============================================================================

@export_group("NPC Identity")
@export_enum("Lucy", "Chad") var npc_name: String = "Lucy"
@export var dialogue_script: Script  # Assign LucyDialogue or ChadDialogue

@export_group("Animation Setup")
@export var idle_anim: String = "Idle"
@export var talk_anims: Array[String] = ["Talk1", "Talk2", "Talk3"]
@export var react_anims: Array[String] = ["Mood1", "Mood2"]
@export var dance_anim: String = "Dance"

@export_group("Idle Behavior")
@export var enable_idle_behavior: bool = true
@export var idle_behavior_interval: float = 20.0  # Check every 20 seconds
@export var idle_behavior_chance: float = 0.3  # 30% chance to do something

# ============================================================================
# REFERENCES
# ============================================================================

@onready var interaction_area: Area3D = $InteractionArea
@onready var animation_player: AnimationPlayer = $model/AnimationPlayer

# Optional: Scene-level animator for movement (Lucy dance, Chad wandering)
@onready var movement_animator: AnimationPlayer = get_node_or_null("MovementAnimator")

# ============================================================================
# STATE
# ============================================================================

var interaction_count: int = 0
var player_nearby: bool = false
var pending_milestone: String = ""

var last_talk_anim_index: int = -1  # For cycling through talk animations
var idle_behavior_timer: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Validate required nodes
	if not dialogue_script:
		push_error("[%s] No dialogue script assigned!" % npc_name)
		return
	
	if not interaction_area:
		push_error("[%s] No InteractionArea found!" % npc_name)
		return
	
	if not animation_player:
		push_error("[%s] No AnimationPlayer found!" % npc_name)
		return
	
	# Connect interaction area
	interaction_area.body_entered.connect(_on_player_entered)
	interaction_area.body_exited.connect(_on_player_exited)
	
	# Connect to dialogue events
	DialogueManager.message_received.connect(_on_message_received)
	DialogueManager.message_dismissed.connect(_on_message_dismissed)
	
	# Connect to discovery milestones (Lucy only)
	if npc_name == "Lucy":
		DiscoveryManager.scan_recorded.connect(_on_scan_recorded)
		DiscoveryManager.threshold_reached.connect(_on_threshold_reached)
	
	# Start in idle
	play_idle()
	
	print("[%s] NPC Controller initialized" % npc_name)

# ============================================================================
# PROCESS
# ============================================================================

func _process(delta):
	if not enable_idle_behavior:
		return
	
	# Only do idle behaviors when actually idle (not talking)
	if not DialogueManager.is_message_showing:
		_process_idle_behavior(delta)

func _process_idle_behavior(delta):
	idle_behavior_timer += delta
	
	if idle_behavior_timer >= idle_behavior_interval:
		idle_behavior_timer = 0.0
		
		if randf() < idle_behavior_chance:
			_trigger_idle_behavior()

# ============================================================================
# INTERACTION
# ============================================================================

func _on_player_entered(body):
	if not body.is_in_group("player"):
		return
	
	player_nearby = true
	print("[%s] Player entered interaction range" % npc_name)

func _on_player_exited(body):
	if not body.is_in_group("player"):
		return
	
	player_nearby = false
	print("[%s] Player left interaction range" % npc_name)

func _input(event):
	if not player_nearby:
		return
	
	if event.is_action_pressed("interact"):
		_on_interact()
		get_viewport().set_input_as_handled()

func _on_interact():
	# Don't interrupt active message
	if DialogueManager.is_message_showing:
		print("[%s] Interaction blocked (message already showing)" % npc_name)
		return
	
	print("[%s] Player interacted" % npc_name)
	
	# Determine what to say
	var context = _get_dialogue_context()
	var message = dialogue_script.get_line(context)
	
	# Send message
	DialogueManager.show_message(npc_name, message)
	interaction_count += 1

# ============================================================================
# DIALOGUE CONTEXT
# ============================================================================

func _get_dialogue_context() -> String:
	# Priority 1: Pending milestone (most important)
	if pending_milestone != "":
		var milestone = pending_milestone
		pending_milestone = ""  # Clear it
		print("[%s] Using milestone context: %s" % [npc_name, milestone])
		return milestone
	
	# Priority 2: First interaction is greeting
	if interaction_count == 0:
		print("[%s] First interaction - greeting" % npc_name)
		return "greeting"
	
	# Priority 3: NPC-specific logic
	if npc_name == "Lucy":
		return _get_lucy_context()
	elif npc_name == "Chad":
		return _get_chad_context()
	
	return "greeting"

func _get_lucy_context() -> String:
	# Give scan encouragement based on progress
	var scan_count = DiscoveryManager.total_scans
	
	var tier = 0
	if scan_count > 30:
		tier = 3
	elif scan_count > 15:
		tier = 2
	elif scan_count > 5:
		tier = 1
	
	print("[%s] Lucy context: scans_%d (total scans: %d)" % [npc_name, tier, scan_count])
	return "scans_%d" % tier

func _get_chad_context() -> String:
	# Random observations
	print("[%s] Chad context: observation" % npc_name)
	return "observation"

# ============================================================================
# MILESTONE HANDLING
# ============================================================================

func _on_threshold_reached(threshold_name: String):
	# Store milestone for next interaction
	if npc_name == "Lucy":
		pending_milestone = threshold_name
		print("[%s] Milestone reached: %s (stored for next interaction)" % [npc_name, threshold_name])
		
		# Optional: Auto-announce critical milestones
		# Uncomment these lines if you want certain milestones to announce immediately
		# if threshold_name in ["animal_unlock", "new_biome"]:
		#     _announce_milestone()

func _announce_milestone():
	# Immediately send the milestone message
	if pending_milestone != "":
		var message = dialogue_script.get_line(pending_milestone)
		DialogueManager.show_message(npc_name, message)
		pending_milestone = ""
		print("[%s] Auto-announced milestone" % npc_name)

func _on_scan_recorded(item_uid: String, is_new: bool):
	# Lucy doesn't comment here - handled by ambient system
	pass

# ============================================================================
# ANIMATION CONTROL
# ============================================================================

func play_idle():
	if animation_player and idle_anim != "":
		animation_player.play(idle_anim)
		print("[%s] Playing idle animation" % npc_name)

func play_talk():
	if not animation_player or talk_anims.size() == 0:
		return
	
	# Cycle through talk animations to avoid repetition
	last_talk_anim_index = (last_talk_anim_index + 1) % talk_anims.size()
	var anim = talk_anims[last_talk_anim_index]
	
	animation_player.play(anim)
	print("[%s] Playing talk animation: %s" % [npc_name, anim])

func play_react(intensity: int = 0):
	if not animation_player or react_anims.size() == 0:
		return
	
	var index = clampi(intensity, 0, react_anims.size() - 1)
	var anim = react_anims[index]
	
	animation_player.play(anim)
	print("[%s] Playing react animation: %s" % [npc_name, anim])

func play_dance():
	if not animation_player or dance_anim == "":
		return
	
	animation_player.play(dance_anim)
	print("[%s] Playing dance animation" % npc_name)
	
	# If we have a movement animator, trigger it too
	if movement_animator:
		movement_animator.play("dance_movement")
		print("[%s] Playing movement animation" % npc_name)

# ============================================================================
# DIALOGUE EVENTS
# ============================================================================

func _on_message_received(speaker: String, message: String, duration: float):
	# Play talk animation if this NPC is speaking
	if speaker != npc_name:
		return
	
	play_talk()

func _on_message_dismissed():
	# Return to idle after message dismissed
	# Small delay to avoid animation pop
	await get_tree().create_timer(0.1).timeout
	play_idle()

# ============================================================================
# IDLE BEHAVIOR
# ============================================================================

func _trigger_idle_behavior():
	# NPC-specific idle behaviors
	if npc_name == "Lucy":
		_lucy_idle_behavior()
	elif npc_name == "Chad":
		_chad_idle_behavior()

func _lucy_idle_behavior():
	# Lucy occasionally checks her tablet or looks around
	# For now, just trigger a react animation
	if react_anims.size() > 0:
		play_react(0)  # Subtle reaction
		print("[%s] Idle behavior: checking tablet" % npc_name)
		
		# Return to idle after animation
		if animation_player:
			await animation_player.animation_finished
			play_idle()

func _chad_idle_behavior():
	# Chad wanders around (his "dance")
	play_dance()
	print("[%s] Idle behavior: wandering around" % npc_name)
	
	# Return to idle after animation
	if animation_player:
		await animation_player.animation_finished
		play_idle()

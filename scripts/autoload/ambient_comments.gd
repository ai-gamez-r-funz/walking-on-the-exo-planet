extends Node

# ============================================================================
# CONFIGURATION
# ============================================================================

# Cooldown to prevent spam
var comment_cooldown: float = 15.0
var time_since_comment: float = 0.0
var can_comment: bool = true

# Comment chances (adjust based on location)
var hub_comment_chance: float = 0.2  # 20% in hub (less intrusive)
var world_comment_chance: float = 0.4  # 40% in world (more responsive)

# ============================================================================
# COMMENT POOLS
# ============================================================================

# Lucy's comments are more scientific/encouraging
var lucy_scan_comments: Array[String] = [
	"Nice find!",
	"Logged. Good work!",
	"Interesting specimen.",
	"Adding that to the database.",
	"Excellent discovery!",
	"Ooh, that's a new one!",
	"Great eye!",
	"Perfect scan quality.",
	"The data looks good on this one.",
	"I'm seeing some interesting readings here.",
]

# Chad's comments are more casual/goofy
var chad_scan_comments: Array[String] = [
	"Whoa, you scanned something!",
	"Nice! What'd you find?",
	"Cool beans!",
	"Another one for the collection, nice!",
	"Sick!",
	"That's rad!",
	"You're like a scanning machine!",
	"Is that a rock? No wait, it's... something else.",
	"Dude! Science!",
	"I have no idea what that is but it looks cool!",
]

# Location-specific comments (only trigger in world)
var lucy_exploration_comments: Array[String] = [
	"Be careful out there!",
	"Interesting terrain in this area.",
	"I'm tracking your position from here.",
	"The atmospheric readings are stable.",
	"You're doing great!",
	"That biome looks fascinating from here!",
]

var chad_exploration_comments: Array[String] = [
	"Don't get lost!",
	"This place is weird, right?",
	"You're pretty far out there!",
	"I'm just chilling at base.",
	"Wish I could come with you but... nah.",
	"Try not to step on anything important!",
]

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Connect to scan events
	DiscoveryManager.scan_recorded.connect(_on_scan_recorded)
	
	# Connect to biome changes (useful for context)
	WorldState.biome_changed.connect(_on_biome_changed)
	
	print("[AmbientComments] Initialized")

func _process(delta):
	if not can_comment:
		time_since_comment += delta
		if time_since_comment >= comment_cooldown:
			can_comment = true
			time_since_comment = 0.0

# ============================================================================
# LOCATION DETECTION
# ============================================================================

func is_in_world() -> bool:
	"""
	Check if player is in the procedural world
	Method: Check current scene name
	"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return false
	
	var scene_name = current_scene.name.to_lower()
	
	# If scene name contains "world", we're in the procedural world
	if "world" in scene_name:
		return true
	
	# Alternative: If scene name contains "hub", we're NOT in world
	if "hub" in scene_name:
		return false
	
	# Fallback: Check if we have an active biome (implies world)
	# Biome should only be relevant in world, not hub
	return WorldState.current_biome != ""

func is_in_hub() -> bool:
	return not is_in_world()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_scan_recorded(item_uid: String, is_new: bool):
	# Only comment on new discoveries
	if not can_comment or not is_new:
		return
	
	# Different chances based on location
	var comment_chance = _get_comment_chance()
	
	if randf() > comment_chance:
		return
	
	# Pick speaker (Lucy more likely in hub, 50/50 in world)
	var speaker = _pick_speaker()
	var comment = _get_scan_comment(speaker)
	
	# Send via communicator
	DialogueManager.show_message(speaker, comment, 3.0)  # Shorter duration for ambient
	
	# Start cooldown
	can_comment = false
	time_since_comment = 0.0
	
	var location = "WORLD" if is_in_world() else "HUB"
	print("[AmbientComments] Triggered in %s: %s said '%s'" % [location, speaker, comment])

func _on_biome_changed(new_biome: String):
	print("[AmbientComments] Biome changed to: %s" % new_biome)
	# Could trigger special biome-entry comments here (Phase 4)

# ============================================================================
# COMMENT SELECTION
# ============================================================================

func _get_comment_chance() -> float:
	if is_in_hub():
		return hub_comment_chance  # 20% in hub
	else:
		return world_comment_chance  # 40% in world

func _pick_speaker() -> String:
	# In hub: 70% Lucy, 30% Chad
	# In world: 50% Lucy, 50% Chad
	if is_in_hub():
		return "Lucy" if randf() < 0.7 else "Chad"
	else:
		return "Lucy" if randf() < 0.5 else "Chad"

func _get_scan_comment(speaker: String) -> String:
	if speaker == "Lucy":
		return lucy_scan_comments.pick_random()
	else:
		return chad_scan_comments.pick_random()

# ============================================================================
# EXPLORATION COMMENTS (Future Feature)
# ============================================================================

# These can be triggered by world events, distance milestones, etc.

func trigger_exploration_comment():
	"""
	Call this from world events (biome entry, distance milestones, etc.)
	Example: WorldState.biome_changed triggers this
	"""
	if not can_comment or not is_in_world():
		return
	
	var speaker = _pick_speaker()
	var comment = _get_exploration_comment(speaker)
	
	DialogueManager.show_message(speaker, comment, 3.5)
	
	can_comment = false
	time_since_comment = 0.0
	
	print("[AmbientComments] Exploration comment: %s said '%s'" % [speaker, comment])

func _get_exploration_comment(speaker: String) -> String:
	if speaker == "Lucy":
		return lucy_exploration_comments.pick_random()
	else:
		return chad_exploration_comments.pick_random()

# ============================================================================
# BIOME-SPECIFIC COMMENTS (Phase 4 Enhancement)
# ============================================================================

# You can add biome-specific comment pools later:
# var temperate_biome_comments = [...]
# var lush_biome_comments = [...]
# 
# Then in _get_scan_comment(), check WorldState.current_biome
# and pull from appropriate pool

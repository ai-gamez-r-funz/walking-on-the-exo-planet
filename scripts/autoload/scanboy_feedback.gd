# res://autoload/scanboy_feedback.gd
# ScanBoy Advance™ Personality System - Immediate Feedback & Commentary
# PROPERLY INTEGRATED: Uses DiscoveryManager.get_item_data() API for all item data access

extends Node

# ============================================
# PERSONALITY STATE
# ============================================

enum Mood {
	EAGER_HELPER,      # 0-10 scans: "This is exciting!"
	CONFIDENT_PRO,     # 11-25 scans: "I've got this."
	MILDLY_CONCERNED,  # 26-50 scans: "This is... unusual."
	QUESTIONING,       # 51-100 scans: "Are you SURE?"
	EXISTENTIAL,       # 101-200 scans: "Why do I exist?"
	RESIGNED,          # 201-500 scans: "Of course. Why not."
	MARVIN            # 500+ scans: "Life. Don't talk to me about life."
}

var current_mood: Mood = Mood.EAGER_HELPER
var scan_counter: int = 0  # Total scans completed

# Mood thresholds (when counter hits these, mood changes)
const MOOD_THRESHOLDS = {
	Mood.CONFIDENT_PRO: 11,
	Mood.MILDLY_CONCERNED: 26,
	Mood.QUESTIONING: 51,
	Mood.EXISTENTIAL: 101,
	Mood.RESIGNED: 201,
	Mood.MARVIN: 500
}

# ============================================
# DIALOGUE POOLS
# ============================================

# Scan initiation lines (when scan starts)
var scan_start_lines = {
	Mood.EAGER_HELPER: [
		"Ooh, what's this? Let me take a look!",
		"Scanning now! This is so exciting!",
		"I love discovering new things!"
	],
	Mood.CONFIDENT_PRO: [
		"Running analysis...",
		"Initiating scan sequence.",
		"Let's see what we have here."
	],
	Mood.MILDLY_CONCERNED: [
		"Scanning... I think?",
		"This is... probably fine.",
		"Right, let's give this a try."
	],
	Mood.QUESTIONING: [
		"Are you sure you want me to scan that?",
		"I have a bad feeling about this one.",
		"My sensors are suggesting we reconsider."
	],
	Mood.EXISTENTIAL: [
		"Another one. Great.",
		"Scanning. Again. Forever.",
		"Does it even matter what this is?"
	],
	Mood.RESIGNED: [
		"Fine. I'll scan it.",
		"Why not. Add it to the list.",
		"At this point, what's one more impossibility?"
	],
	Mood.MARVIN: [
		"Here I am, brain the size of a planet, scanning a rock.",
		"I suppose you want me to be happy about this.",
		"Scan initiated. Joy. Rapture. Etcetera."
	]
}

# Scan completion lines (when scan finishes)
var scan_complete_lines = {
	Mood.EAGER_HELPER: [
		"Got it! That was fascinating!",
		"Analysis complete! How wonderful!",
		"All done! I learned so much!"
	],
	Mood.CONFIDENT_PRO: [
		"Analysis complete.",
		"Scan successful. Data logged.",
		"Entry recorded."
	],
	Mood.MILDLY_CONCERNED: [
		"Scan complete. I guess.",
		"Well... that's done.",
		"Data recorded. Probably accurately."
	],
	Mood.QUESTIONING: [
		"I've recorded the data, but I have questions.",
		"Scan complete. This doesn't make sense.",
		"Entry logged. Against my better judgment."
	],
	Mood.EXISTENTIAL: [
		"Another entry in the endless catalog of things.",
		"Recorded. Like all the others. Forever.",
		"Scan complete. We're all trapped in this cycle."
	],
	Mood.RESIGNED: [
		"Done. Surprisingly, nothing exploded.",
		"Logged. Moving on with my life. Such as it is.",
		"Complete. The universe continues to mock me."
	],
	Mood.MARVIN: [
		"Scan complete. Added to the great database of things nobody cares about.",
		"I could have written a symphony in the time that took. Instead: this.",
		"Entry recorded. My suffering continues unabated."
	]
}

# Rescan commentary (when scanning same object again)
var rescan_lines = {
	0: [  # First rescan (helpful)
		"Oh, checking for more details? Smart!",
		"Let me take another look...",
		"Ah yes, I can gather more data now."
	],
	1: [  # Second rescan (knowledgeable)
		"Based on previous scans, I can add...",
		"Cross-referencing with earlier data...",
		"My extended database shows..."
	],
	2: [  # Third+ rescan (questioning)
		"We've scanned this before, you know.",
		"Getting really familiar with this one, aren't we?",
		"Again? Well, if you insist..."
	],
	3: [  # Many rescans (complaints)
		"I JUST scanned this.",
		"Do you not trust my analysis?",
		"This is the same object. It hasn't changed."
	],
	4: [  # Excessive rescans (existential)
		"We've scanned this %d times. It's still the same.",
		"I've memorized every molecule. Can we move on?",
		"At this point I'm just humoring you."
	]
}

# ============================================
# INITIALIZATION
# ============================================

func _ready() -> void:
	# Verify dependencies
	if not DiscoveryManager:
		push_error("[ScanBoyFeedback] DiscoveryManager not available! Cannot function.")
		return
	
	if not ScannerManager:
		push_error("[ScanBoyFeedback] ScannerManager not available! Cannot function.")
		return
	
	# Connect to scanner lifecycle events
	ScannerManager.scan_started.connect(_on_scan_started)
	ScannerManager.scan_completed.connect(_on_scan_completed)
	
	print("[ScanBoyFeedback] ✓ Initialized - Ready to provide commentary")
	print("[ScanBoyFeedback] ✓ Connected to ScannerManager signals")


# ============================================
# SIGNAL HANDLERS
# ============================================

func _on_scan_started(item_uid: String) -> void:
	"""
	Called when player initiates scan.
	Shows mood-appropriate scan start line.
	"""
	# Get item data via DiscoveryManager API
	var item_data = DiscoveryManager.get_item_data(item_uid)
	
	if not item_data:
		# Fallback for unknown items
		_show_feedback(_get_random_line(scan_start_lines[current_mood]))
		return
	
	# Check if this is a rescan
	var scan_data = DiscoveryManager.get_scan_data(item_uid)
	var times_scanned = scan_data.times_scanned if scan_data else 0
	
	if times_scanned > 0:
		# This is a rescan - use rescan commentary
		var rescan_tier = _get_rescan_tier(times_scanned)
		var line = _get_random_line(rescan_lines[rescan_tier])
		
		# Inject scan count if placeholder exists
		if "%d" in line:
			line = line % times_scanned
		
		_show_feedback(line)
	else:
		# First time scanning - use normal start line
		var base_line = _get_random_line(scan_start_lines[current_mood])
		
		# Add item name for early moods (enthusiasm!)
		if current_mood <= Mood.CONFIDENT_PRO:
			base_line = "Scanning the **%s**... %s" % [item_data.display_name, base_line]
		
		_show_feedback(base_line)


func _on_scan_completed(item_uid: String) -> void:
	"""
	Called when scan finishes successfully.
	Shows completion line and updates mood if needed.
	"""
	# Increment scan counter
	scan_counter += 1
	
	# Check for mood change
	_check_mood_change()
	
	# Get item data via DiscoveryManager API
	var item_data = DiscoveryManager.get_item_data(item_uid)
	
	if not item_data:
		# Fallback for unknown items
		_show_feedback(_get_random_line(scan_complete_lines[current_mood]))
		return
	
	# Check if new discovery
	var scan_data = DiscoveryManager.get_scan_data(item_uid)
	var is_new = (scan_data.times_scanned == 1) if scan_data else false
	
	# Build completion message
	var base_line = _get_random_line(scan_complete_lines[current_mood])
	
	# Add context based on mood and discovery status
	if is_new and current_mood <= Mood.CONFIDENT_PRO:
		# Early moods: excited about new discoveries
		base_line = "**%s** cataloged! %s" % [item_data.display_name, base_line]
	elif not is_new and current_mood >= Mood.QUESTIONING:
		# Late moods: annoyed by rescans
		base_line = "**%s** (again). %s" % [item_data.display_name, base_line]
	
	_show_feedback(base_line)


# ============================================
# MOOD MANAGEMENT
# ============================================

func _check_mood_change() -> void:
	"""
	Checks if scan counter has crossed a mood threshold.
	Updates mood and shows transition dialogue if needed.
	"""
	for mood in MOOD_THRESHOLDS:
		if scan_counter == MOOD_THRESHOLDS[mood] and current_mood != mood:
			var old_mood = current_mood
			current_mood = mood
			_show_mood_transition(old_mood, mood)
			break


func _show_mood_transition(old_mood: Mood, new_mood: Mood) -> void:
	"""
	Shows special dialogue when ScanBoy's mood changes.
	These are longer, more introspective lines.
	"""
	var transition_lines = {
		Mood.CONFIDENT_PRO: "I'm getting pretty good at this!",
		Mood.MILDLY_CONCERNED: "Wait... some of these readings don't make sense.",
		Mood.QUESTIONING: "I'm starting to think my database might be... incomplete.",
		Mood.EXISTENTIAL: "What is the point of cataloging things that defy cataloging?",
		Mood.RESIGNED: "Fine. FINE. Nothing makes sense. I accept this now.",
		Mood.MARVIN: "I've calculated your odds of understanding this place. You don't want to know."
	}
	
	if transition_lines.has(new_mood):
		_show_feedback(transition_lines[new_mood], true)  # Show as mood shift
		print("[ScanBoyFeedback] 🎭 Mood changed: %s -> %s (scan #%d)" % [
			Mood.keys()[old_mood],
			Mood.keys()[new_mood],
			scan_counter
		])


# ============================================
# UTILITY METHODS
# ============================================

func _get_rescan_tier(times_scanned: int) -> int:
	"""
	Returns the appropriate rescan commentary tier based on scan count.
	Adjusts for current mood (more complaints in bad moods).
	"""
	if current_mood <= Mood.CONFIDENT_PRO:
		return min(times_scanned - 1, 1)  # Helpful → Knowledgeable
	elif current_mood <= Mood.MILDLY_CONCERNED:
		return min(times_scanned - 1, 2)  # Add questioning
	elif current_mood <= Mood.QUESTIONING:
		return min(times_scanned - 1, 3)  # Add complaints
	else:
		return 4  # Full existential crisis


func _get_random_line(line_pool: Array) -> String:
	"""
	Returns a random line from the given pool.
	"""
	if line_pool.is_empty():
		return "..." # Fallback if pool empty
	
	return line_pool[randi() % line_pool.size()]


func _show_feedback(text: String, is_mood_shift: bool = false) -> void:
	"""
	Displays feedback text to player.
	For now, just prints to console.
	In Phase 3, this will trigger UI display and audio bloops.
	"""
	var prefix = "🎭 [MOOD SHIFT]" if is_mood_shift else "🤖 [ScanBoy]"
	print("%s %s" % [prefix, text])
	
	# TODO Phase 3: Emit signal for UI system
	# feedback_ready.emit(text, "mood_shift" if is_mood_shift else "commentary")
	
	# TODO Phase 3: Trigger audio bloop
	# var bloop_type = _get_bloop_type(is_mood_shift, current_mood)
	# AudioManager.play_scanboy_bloop(bloop_type)


# ============================================
# DEBUG / TESTING
# ============================================

func reset_for_testing() -> void:
	"""
	Resets ScanBoy state for testing.
	"""
	scan_counter = 0
	current_mood = Mood.EAGER_HELPER
	print("[ScanBoyFeedback] 🔄 Reset to testing state")


func force_mood(mood: Mood) -> void:
	"""
	Force ScanBoy into a specific mood (for testing).
	"""
	current_mood = mood
	print("[ScanBoyFeedback] 🎭 Mood forced to: %s" % Mood.keys()[mood])


func get_current_mood_name() -> String:
	"""
	Returns human-readable current mood.
	"""
	return Mood.keys()[current_mood]


# ============================================
# SAVE/LOAD INTEGRATION (PHASE 2)
# ============================================

func get_save_data() -> Dictionary:
	"""
	Returns data to be saved.
	"""
	return {
		"scan_counter": scan_counter,
		"current_mood": current_mood
	}


func load_save_data(save_data: Dictionary) -> void:
	"""
	Restores ScanBoy state from save data.
	"""
	scan_counter = save_data.get("scan_counter", 0)
	current_mood = save_data.get("current_mood", Mood.EAGER_HELPER)
	print("[ScanBoyFeedback] 💾 Loaded state - Scans: %d, Mood: %s" % [
		scan_counter,
		Mood.keys()[current_mood]
	])

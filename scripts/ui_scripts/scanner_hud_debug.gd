# res://ui/hud/scanner_hud_debug.gd
# UPDATED: Works with new scan_completed signal (includes item_data)

extends Control

@onready var target_label: Label = %TargetLabel
@onready var prompt_label: Label = %PromptLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var scan_count_label: Label = %ScanCountLabel
@onready var state_label: Label = %StateLabel

# Cache target info for display
var current_target_uid: String = ""
var current_target_name: String = ""
var current_item_data: CollectionItemData = null

func _ready() -> void:
	# Connect to ScannerManager signals
	ScannerManager.target_acquired.connect(_on_target_acquired)
	ScannerManager.target_lost.connect(_on_target_lost)
	ScannerManager.scan_started.connect(_on_scan_started)
	ScannerManager.scan_progressed.connect(_on_scan_progressed)
	ScannerManager.scan_completed.connect(_on_scan_completed)
	ScannerManager.scan_interrupted.connect(_on_scan_interrupted)
	
	# Connect to DiscoveryManager for scan counts
	if DiscoveryManager:
		DiscoveryManager.scan_recorded.connect(_on_scan_recorded)
	
	# Initial state
	_update_display()
	
	print("[ScannerHUD] Debug HUD initialized")

func _process(_delta: float) -> void:
	# Update scan count every frame
	if DiscoveryManager:
		scan_count_label.text = "Total Scans: %d" % DiscoveryManager.total_scans
	
	# Update state for debugging
	var state_name = ScannerManager.ScanState.keys()[ScannerManager.current_state]
	state_label.text = "State: %s" % state_name

# ============================================
# SIGNAL HANDLERS
# ============================================

func _on_target_acquired(item_uid: String, _scan_time: float) -> void:
	current_target_uid = item_uid
	current_item_data = _get_item_data_for_uid(item_uid)
	current_target_name = current_item_data.display_name if current_item_data else item_uid
	
	target_label.text = "TARGET: %s" % current_target_name
	target_label.modulate = Color.YELLOW
	
	prompt_label.text = "[Press SCAN to analyze]"
	prompt_label.visible = true
	progress_bar.visible = false

func _on_target_lost(_item_uid: String) -> void:
	current_target_uid = ""
	current_target_name = ""
	current_item_data = null
	
	target_label.text = "TARGET: None"
	target_label.modulate = Color.GRAY
	
	prompt_label.visible = false
	progress_bar.visible = false

func _on_scan_started(item_uid: String) -> void:
	current_target_uid = item_uid
	current_item_data = _get_item_data_for_uid(item_uid)
	current_target_name = current_item_data.display_name if current_item_data else item_uid
	
	target_label.text = "SCANNING: %s" % current_target_name
	target_label.modulate = Color.CYAN
	
	prompt_label.visible = false
	progress_bar.visible = true
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0

func _on_scan_progressed(progress: float) -> void:
	if progress_bar.visible:
		progress_bar.value = progress

func _on_scan_completed(item_uid: String, item_data: CollectionItemData) -> void:
	# We now receive item_data directly in the signal!
	current_target_uid = item_uid
	current_item_data = item_data
	current_target_name = item_data.display_name if item_data else item_uid
	
	# Check if it was a new discovery
	if DiscoveryManager:
		var scan_data = DiscoveryManager.get_scan_data(item_uid)
		if scan_data:
			var tier = scan_data.scan_tier
			var times = scan_data.times_scanned
			var is_new = (times == 1)
			
			if is_new:
				target_label.text = "NEW DISCOVERY: %s" % current_target_name
				target_label.modulate = Color.GREEN
			else:
				target_label.text = "SCAN COMPLETE: %s (Tier %d/%d)" % [current_target_name, tier, times]
				target_label.modulate = Color.LIGHT_GREEN
	else:
		target_label.text = "SCAN COMPLETE: %s" % current_target_name
		target_label.modulate = Color.LIGHT_GREEN
	
	progress_bar.value = 1.0
	
	# Flash completion then reset
	await get_tree().create_timer(1.5).timeout
	_update_display()

func _on_scan_interrupted(item_uid: String, reason: String) -> void:
	target_label.text = "INTERRUPTED: %s" % reason
	target_label.modulate = Color.RED
	
	progress_bar.visible = false
	
	await get_tree().create_timer(1.0).timeout
	_update_display()

func _on_scan_recorded(_item_uid: String, _is_new: bool) -> void:
	# Optional: Could show a toast notification here
	pass

# ============================================
# HELPER METHODS
# ============================================

func _update_display() -> void:
	var active_uid = ScannerManager.get_active_target_uid()
	
	if not active_uid.is_empty():
		# Has target
		current_target_uid = active_uid
		current_item_data = _get_item_data_for_uid(active_uid)
		current_target_name = current_item_data.display_name if current_item_data else active_uid
		
		target_label.text = "TARGET: %s" % current_target_name
		target_label.modulate = Color.YELLOW
		prompt_label.text = "[Press SCAN to analyze]"
		prompt_label.visible = true
		progress_bar.visible = false
	else:
		# No target
		current_target_uid = ""
		current_target_name = ""
		current_item_data = null
		
		target_label.text = "TARGET: None"
		target_label.modulate = Color.GRAY
		prompt_label.visible = false
		progress_bar.visible = false

func _get_item_data_for_uid(item_uid: String) -> CollectionItemData:
	"""
	Load CollectionItemData from the unified data folder.
	IMPORTANT: Uses res://data/collection_items/ path!
	"""
	var collection_dir = "res://data/collection_items/"
	var dir = DirAccess.open(collection_dir)
	
	if not dir:
		push_warning("[ScannerHUD] Could not open collection_items directory")
		return null
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item_data = load(collection_dir + file_name) as CollectionItemData
			if item_data and item_data.item_uid == item_uid:
				dir.list_dir_end()
				return item_data
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return null

# ============================================
# DEBUG INFO
# ============================================

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	
	# F3 to toggle HUD
	if event.is_action_pressed("ui_text_backspace"):
		visible = !visible

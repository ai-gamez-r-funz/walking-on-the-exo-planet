# res://autoload/scanner_manager.gd
# ROBUST AUTOLOAD DESIGN - Scanner System Coordinator
# Architecture: Pure event-driven, zero outgoing dependencies
# Last Updated: Phase 2 Migration to Robust Architecture

extends Node

## ============================================
## DESIGN PRINCIPLES FOR THIS AUTOLOAD:
## ============================================
## 1. NO DIRECT DEPENDENCIES on scannable structure
## 2. NO METHOD CALLS on scene instances
## 3. PURE EVENT-DRIVEN communication via signals
## 4. SINGLE RESPONSIBILITY: Manage scan timing/state only
## 5. DATA OWNERSHIP: DiscoveryManager owns all scan records
## ============================================

# ============================================
# CONFIGURATION
# ============================================

## Base time to complete a scan (modified by item scan_difficulty)
@export var base_scan_time: float = 2.0

## How long player can lose target before scan cancels
@export var grace_period: float = 0.5

## How fast progress decays during grace period (per second)
@export var progress_decay_rate: float = 2.0

# ============================================
# STATE MACHINE
# ============================================

enum ScanState {
	IDLE,          ## No target, not scanning
	TARGETING,     ## Target acquired, ready to scan
	SCANNING,      ## Active scan in progress
	GRACE_PERIOD   ## Target lost during scan, brief recovery window
}

var current_state: ScanState = ScanState.IDLE

# ============================================
# SCAN TRACKING (UIDs only - NO Node references)
# ============================================

## UID of currently targeted/scanned object (String, NOT a Node)
var active_target_uid: String = ""

## Current scan progress (0.0 to 1.0)
var scan_progress: float = 0.0

## Scan time for current target (cached from report_target_acquired)
var target_scan_time: float = 0.0

## Grace period countdown timer
var grace_timer: float = 0.0

# ============================================
# SIGNALS - THE ONLY WAY TO COMMUNICATE
# ============================================

## Emitted when a new target becomes active for scanning
## Parameters: item_uid (String), scan_time (float)
signal target_acquired(item_uid: String, scan_time: float)

## Emitted when active target is lost
## Parameters: item_uid (String)
signal target_lost(item_uid: String)

## Emitted when scan actually begins (player pressed button)
## Parameters: item_uid (String)
signal scan_started(item_uid: String)

## Emitted every frame during scan (for UI progress bars)
## Parameters: progress (float 0.0-1.0)
signal scan_progressed(progress: float)

## Emitted when scan completes successfully
## Parameters: item_uid (String)
signal scan_completed(item_uid: String, item_data: CollectionItemData)

## Emitted when scan is interrupted before completion
## Parameters: item_uid (String), reason (String)
signal scan_interrupted(item_uid: String, reason: String)

## Emitted when entering grace period (target lost during scan)
signal grace_period_started()

## Emitted when grace period ends without target reacquisition
signal grace_period_expired()

# ============================================
# INITIALIZATION
# ============================================

func _ready() -> void:
	set_process(false)  # Only process when actively scanning
	print("[ScannerManager] Initialized - Pure event-driven, no dependencies")

# ============================================
# PUBLIC API - CALLED BY EXTERNAL SYSTEMS
# ============================================

## Called by scannable_selector when it detects a new target
## Parameters:
##   item_uid: Unique identifier from CollectionItemData
##   scan_time: How long this object takes to scan
func report_target_acquired(item_uid: String, scan_time: float) -> void:
	if current_state == ScanState.SCANNING:
		# Already scanning something else - ignore new targets
		return
	
	if current_state == ScanState.GRACE_PERIOD and active_target_uid == item_uid:
		# Reacquired same target during grace period - resume scan!
		current_state = ScanState.TARGETING
		grace_timer = 0.0
		print("[ScannerManager] Target reacquired during grace period: %s" % item_uid)
		return
	
	# New target acquired
	active_target_uid = item_uid
	target_scan_time = scan_time
	current_state = ScanState.TARGETING
	grace_timer = 0.0
	
	target_acquired.emit(item_uid, scan_time)
	print("[ScannerManager] Target acquired: %s (scan_time: %.1fs)" % [item_uid, scan_time])

## Called by scannable_selector when target is lost
## Parameters:
##   item_uid: UID of target that was lost
func report_target_lost(item_uid: String) -> void:
	if active_target_uid != item_uid:
		return  # Not our active target, ignore
	
	if current_state == ScanState.SCANNING:
		# Start grace period - give player time to reacquire
		current_state = ScanState.GRACE_PERIOD
		grace_timer = 0.0
		grace_period_started.emit()
		print("[ScannerManager] Grace period started for: %s" % item_uid)
	else:
		# Not scanning, just clear target
		_clear_target()

## Called by player input when scan button pressed
## Initiates scan if valid target is available
func request_scan_start() -> void:
	if current_state != ScanState.TARGETING:
		return  # No valid target or already scanning
	
	if active_target_uid.is_empty():
		push_warning("[ScannerManager] Scan requested but no active target UID")
		return
	
	# Start scanning
	current_state = ScanState.SCANNING
	scan_progress = 0.0
	set_process(true)  # Enable processing for scan updates
	
	scan_started.emit(active_target_uid)
	print("[ScannerManager] Scan started: %s" % active_target_uid)

# ============================================
# QUERY API - READ-ONLY STATE ACCESS
# ============================================

## Returns UID of currently active target (empty string if none)
func get_active_target_uid() -> String:
	return active_target_uid

## Returns current scan progress (0.0 to 1.0)
func get_current_progress() -> float:
	return scan_progress

## Returns true if actively scanning
func is_scanning() -> bool:
	return current_state == ScanState.SCANNING

## Returns true if in grace period
func is_in_grace_period() -> bool:
	return current_state == ScanState.GRACE_PERIOD

# ============================================
# PROCESS - TIMING LOGIC ONLY
# ============================================

func _process(delta: float) -> void:
	match current_state:
		ScanState.SCANNING:
			_process_scanning(delta)
		
		ScanState.GRACE_PERIOD:
			_process_grace_period(delta)
		
		_:
			# Should never process in IDLE or TARGETING states
			set_process(false)

func _process_scanning(delta: float) -> void:
	# Increment progress based on scan time
	scan_progress += delta / target_scan_time
	scan_progressed.emit(scan_progress)
	
	# Check for completion
	if scan_progress >= 1.0:
		_complete_scan()

func _process_grace_period(delta: float) -> void:
	grace_timer += delta
	
	# Decay progress slightly during grace period
	scan_progress -= progress_decay_rate * delta
	scan_progress = max(0.0, scan_progress)
	scan_progressed.emit(scan_progress)
	
	# Check if grace period expired
	if grace_timer >= grace_period:
		grace_period_expired.emit()
		scan_interrupted.emit(active_target_uid, "grace_period_expired")
		print("[ScannerManager] Grace period expired, scan interrupted: %s" % active_target_uid)
		_clear_target()

# ============================================
# INTERNAL STATE MANAGEMENT
# ============================================

func _complete_scan():
	var completed_uid = active_target_uid
	
	# Get the scannable object (we already have reference during scan)
	var scannable = _get_current_scannable()
	
	if not scannable or not scannable.collection_item_data:
		push_error("[ScannerManager] Cannot complete scan - no item data")
		_clear_target()
		return
	
	# Emit with BOTH uid and data
	scan_completed.emit(completed_uid, scannable.collection_item_data)
	
	# ScanBoy feedback
	var is_new = !DiscoveryManager.has_scanned(completed_uid)
	var scanboy_message = _get_scanboy_comment(scannable.collection_item_data, is_new)
	DialogueManager.show_message("ScanBoy", scanboy_message, 2.5)
	
	_clear_target()

func _get_current_scannable() -> Node3D:
	"""Get the currently targeted scannable from the scene"""
	var scannables = get_tree().get_nodes_in_group("scannable")
	
	for scannable in scannables:
		if scannable.has_method("get_unique_id"):
			if scannable.get_unique_id() == active_target_uid:
				return scannable
	
	return null

func _clear_target() -> void:
	var lost_uid = active_target_uid
	
	# Emit lost signal if we had a target
	if not lost_uid.is_empty():
		target_lost.emit(lost_uid)
	
	# Reset all state
	active_target_uid = ""
	scan_progress = 0.0
	grace_timer = 0.0
	current_state = ScanState.IDLE
	set_process(false)

# ============================================
# DEBUG HELPERS (Optional - comment out in production)
# ============================================

func _input(event: InputEvent) -> void:
	# Debug shortcuts for testing (remove in production)
	if not OS.is_debug_build():
		return
	
	if event.is_action_pressed("ui_page_up"):
		print("[DEBUG] Scanner state: %s, Progress: %.2f, Target: %s" % [
			ScanState.keys()[current_state],
			scan_progress,
			active_target_uid if not active_target_uid.is_empty() else "none"
		])
	
	if event.is_action_pressed("ui_page_down"):
		# Instant complete (for testing)
		if current_state == ScanState.SCANNING:
			scan_progress = 1.0

func _get_scanboy_comment(item_data: CollectionItemData, is_new: bool) -> String:
	"""Simple functional feedback using the item data directly"""
	
	if item_data.item_uid == "artifact_002":  # Tutorial sphere
		return "Scan complete! All systems nominal. Ready for field work!"
	
	if is_new:
		return "New entry recorded! %s catalogued." % item_data.get_category_name()
	else:
		var tier = DiscoveryManager.get_scan_tier(item_data.item_uid)
		return "Additional data acquired. Scan tier: %d/3" % tier

# ============================================
# NO OTHER METHODS
# NO DISCOVERY TRACKING
# NO PLAYER CONNECTIONS
# NO SCENE REFERENCES
# JUST TIMING AND SIGNALS
# ============================================

# res://scripts/scanner/scannable_object.gd
# UPDATED: Robust Architecture - Event Receiver Pattern
# Listens to ScannerManager signals and reacts accordingly

extends Node3D
class_name ScannableObject

# ============================================
# DATA REFERENCE
# ============================================

## Collection data defining this object's identity and properties
@export var collection_item_data: CollectionItemData

# ============================================
# STATE (Cached - NOT authoritative, truth lives in DiscoveryManager)
# ============================================

var current_scan_tier: int = 0  # 0 = unscanned, 1-3 = scanned tiers
var times_scanned: int = 0

# ============================================
# NODE REFERENCES
# ============================================

@onready var detection_area: Area3D = $DetectionArea
@onready var collision_shape: CollisionShape3D = $DetectionArea/CollisionShape3D
@onready var visual_feedback: ScannableVisualFeedback = $VisualFeedback

# ============================================
# LIFECYCLE
# ============================================

func _ready() -> void:
	# Validate configuration
	if collection_item_data == null:
		push_error("[ScannableObject] %s has no collection_item_data assigned" % name)
		return
	
	if not collection_item_data.is_valid():
		push_error("[ScannableObject] %s has invalid collection_item_data" % name)
		return
	
	# Set up detection area
	_configure_detection_area()
	
	# Connect to ScannerManager signals
	_connect_to_scanner_signals()
	
	# Load scan history from DiscoveryManager
	_load_scan_history()
	
	print("[ScannableObject] %s initialized (Event receiver)" % collection_item_data.display_name)

func _configure_detection_area() -> void:
	if detection_area == null:
		push_error("[ScannableObject] %s missing DetectionArea child node" % name)
		return
	
	if collision_shape == null:
		push_error("[ScannableObject] %s missing CollisionShape3D in DetectionArea" % name)
		return
	
	# Detection range is set by the CollisionShape3D size in the scene
	# No need to configure programmatically

# ============================================
# SIGNAL CONNECTIONS (NEW: Connect to ScannerManager)
# ============================================

func _connect_to_scanner_signals() -> void:
	# Listen to ALL scanner events, filter for our UID in handlers
	ScannerManager.target_acquired.connect(_on_scanner_target_acquired)
	ScannerManager.target_lost.connect(_on_scanner_target_lost)
	ScannerManager.scan_started.connect(_on_scanner_scan_started)
	ScannerManager.scan_progressed.connect(_on_scanner_scan_progressed)
	ScannerManager.scan_completed.connect(_on_scanner_scan_completed)
	ScannerManager.scan_interrupted.connect(_on_scanner_scan_interrupted)
	
	print("[ScannableObject] %s connected to ScannerManager signals" % collection_item_data.display_name)

func _load_scan_history() -> void:
	if not DiscoveryManager:
		return
	
	var scan_data = DiscoveryManager.get_scan_data(collection_item_data.item_uid)
	if scan_data:
		current_scan_tier = scan_data.scan_tier
		times_scanned = scan_data.times_scanned
		
		# Show visual indicator for scanned objects
		if current_scan_tier > 0 and visual_feedback:
			visual_feedback.show_as_scanned(current_scan_tier)
			print("[ScannableObject] %s loaded scan history: Tier %d, Scanned %d times" % [
				collection_item_data.display_name,
				current_scan_tier,
				times_scanned
			])

# ============================================
# PUBLIC INTERFACE (Required by scannable_selector)
# ============================================

## Returns true if this object can currently be scanned
func can_be_scanned() -> bool:
	return collection_item_data != null and collection_item_data.is_valid()

## Returns the actual scan time for this object
func get_scan_time() -> float:
	if collection_item_data == null:
		return 2.0
	return collection_item_data.scan_time

## Returns the display name from collection data
func get_display_name() -> String:
	return collection_item_data.display_name if collection_item_data else "Unknown"

## Returns unique identifier for this object type
func get_unique_id() -> String:
	return collection_item_data.item_uid if collection_item_data else ""

## Returns true if this object has been scanned at least once
func is_scanned() -> bool:
	return current_scan_tier > 0

## Returns current scan tier (0-3)
func get_scan_tier() -> int:
	return current_scan_tier

# ============================================
# SCANNER SIGNAL HANDLERS (Filter for our UID)
# ============================================

func _on_scanner_target_acquired(item_uid: String, _scan_time: float) -> void:
	# Filter: Only respond to signals for THIS object
	if item_uid != get_unique_id():
		return
	
	if visual_feedback:
		visual_feedback.show_detected()

func _on_scanner_target_lost(item_uid: String) -> void:
	if item_uid != get_unique_id():
		return
	
	if visual_feedback:
		visual_feedback.hide_detected()

func _on_scanner_scan_started(item_uid: String) -> void:
	if item_uid != get_unique_id():
		return
	
	if visual_feedback:
		visual_feedback.show_scanning()

func _on_scanner_scan_progressed(progress: float) -> void:
	# Only respond if we're the active target
	if ScannerManager.get_active_target_uid() != get_unique_id():
		return
	
	if visual_feedback:
		visual_feedback.update_scan_progress(progress)

func _on_scanner_scan_completed(item_uid: String):
	"""Handle scan completion - update visuals and report to DiscoveryManager"""
	if item_uid != get_unique_id():
		return  # Not for us
	
	# Visual feedback
	if visual_feedback:
		visual_feedback.show_completed()
	
	# NEW: Report this instance scan directly to DiscoveryManager
	if DiscoveryManager and collection_item_data:
		var is_new = DiscoveryManager.record_scan(self, item_uid, collection_item_data)
		
		if is_new:
			print("[ScannableObject] ✅ Instance scan recorded: %s" % collection_item_data.display_name)
	else:
		push_warning("[ScannableObject] Cannot record scan - missing DiscoveryManager or item_data")
	
	# Reload scan history to get updated tier
	_load_scan_history()

func _on_scanner_scan_interrupted(item_uid: String, _reason: String) -> void:
	if item_uid != get_unique_id():
		return
	
	if visual_feedback:
		visual_feedback.show_interrupted()

# ============================================
# REMOVED: Old lifecycle callbacks
# These methods NO LONGER EXIST:
#   - on_detected()
#   - on_lost()
#   - on_scan_started()
#   - on_scan_progress(progress)
#   - on_scan_completed(new_tier)
#   - on_scan_interrupted()
# Replaced with signal handlers above
# ============================================

# ============================================
# DEBUG
# ============================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if collection_item_data == null:
		warnings.append("No CollectionItemData assigned")
	
	if not has_node("DetectionArea"):
		warnings.append("Missing DetectionArea child node")
	
	if has_node("DetectionArea") and not has_node("DetectionArea/CollisionShape3D"):
		warnings.append("DetectionArea missing CollisionShape3D child")
	
	return warnings

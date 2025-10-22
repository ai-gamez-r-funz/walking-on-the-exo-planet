# res://scripts/scanner/scannable_selector.gd
# UPDATED: Robust Architecture - Adapter Pattern
# Detects targets and reports to ScannerManager via API calls

extends Node3D
class_name ScannableSelector

# ============================================
# DETECTION CONFIGURATION
# ============================================

## How often to check for scannables (in seconds, not every frame for performance)
@export_range(0.05, 0.5, 0.05) var detection_frequency: float = 0.1

## Dot product threshold for camera view alignment (1.0 = perfect center, 0.0 = 180° away)
@export_range(0.5, 1.0, 0.05) var center_alignment_tolerance: float = 0.7

## Reference to camera for view-based prioritization
@export var camera: Camera3D

# ============================================
# STATE (UPDATED: Uses UIDs and WeakRef)
# ============================================

var current_target_uid: String = ""  # UID of active target (NOT Node reference)
var current_target_node: WeakRef = null  # Weak reference to avoid memory leaks
var nearby_scannables: Array[Dictionary] = []  # [{uid: String, node_ref: WeakRef}]
var detection_timer: float = 0.0

# ============================================
# NODE REFERENCES
# ============================================

@onready var detection_area: Area3D = $DetectionArea

# ============================================
# LIFECYCLE
# ============================================

func _ready() -> void:
	_configure_detection_area()
	
	# Auto-find camera if not set
	if camera == null:
		camera = get_viewport().get_camera_3d()
		if camera:
			print("[ScannableSelector] Auto-found camera: %s" % camera.name)
	
	print("[ScannableSelector] Initialized (Adapter pattern - reports to ScannerManager)")

func _configure_detection_area() -> void:
	if detection_area == null:
		push_error("[ScannableSelector] Missing DetectionArea child node")
		return
	
	detection_area.area_entered.connect(_on_area_entered)
	detection_area.area_exited.connect(_on_area_exited)
	detection_area.monitoring = true
	detection_area.monitorable = false

func _process(delta: float) -> void:
	detection_timer += delta
	if detection_timer >= detection_frequency:
		_detect_best_target()
		detection_timer = 0.0

# ============================================
# DETECTION LOGIC (UPDATED)
# ============================================

func _detect_best_target() -> void:
	var best_uid: String = ""
	var best_node: Node3D = null
	var best_score: float = -1.0
	
	if camera == null:
		return
	
	var camera_forward = -camera.global_transform.basis.z
	
	# Evaluate all nearby scannables
	for entry in nearby_scannables:
		var node = entry.node_ref.get_ref() as Node3D
		if node == null or not is_instance_valid(node):
			continue
		
		# Must have required interface methods
		if not node.has_method("get_unique_id") or not node.has_method("get_scan_time"):
			continue
		
		if not node.has_method("can_be_scanned") or not node.can_be_scanned():
			continue
		
		# Calculate priority score
		var distance = global_position.distance_to(node.global_position)
		var direction = (node.global_position - global_position).normalized()
		var alignment = camera_forward.dot(direction)
		
		# Skip if behind camera or too far off-center
		if alignment < center_alignment_tolerance:
			continue
		
		# Line of sight check (always required)
		if not _has_line_of_sight(node):
			continue
		
		# Priority score: closer + more in view = better
		var score = (1.0 / max(distance, 0.1)) * alignment
		
		if score > best_score:
			best_score = score
			best_uid = entry.uid
			best_node = node
	
	# Update target if changed
	if best_uid != current_target_uid:
		_update_target(best_uid, best_node)

func _has_line_of_sight(target: Node3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		target.global_position
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	
	# Check if we hit the target or one of its children
	var hit = result.collider
	return hit == target or hit.is_ancestor_of(target) or target.is_ancestor_of(hit)

# ============================================
# TARGET MANAGEMENT (UPDATED: Reports to ScannerManager)
# ============================================

func _update_target(new_uid: String, new_node: Node3D) -> void:
	# Report to ScannerManager when target lost
	if not current_target_uid.is_empty():
		ScannerManager.report_target_lost(current_target_uid)
	
	# Update local tracking
	current_target_uid = new_uid
	current_target_node = weakref(new_node) if new_node else null
	
	# Report to ScannerManager when target acquired
	if not new_uid.is_empty() and new_node:
		var scan_time = new_node.get_scan_time() if new_node.has_method("get_scan_time") else 2.0
		ScannerManager.report_target_acquired(new_uid, scan_time)

# ============================================
# AREA DETECTION CALLBACKS (UPDATED: Dictionary format)
# ============================================

func _on_area_entered(area: Area3D) -> void:
	var scannable = _get_scannable_from_area(area)
	if scannable == null:
		return
	
	if not scannable.has_method("get_unique_id"):
		return
	
	var uid = scannable.get_unique_id()
	
	# Check if already tracked
	for entry in nearby_scannables:
		if entry.uid == uid:
			return  # Already tracking this one
	
	# Add to tracking list
	nearby_scannables.append({
		"uid": uid,
		"node_ref": weakref(scannable)
	})

func _on_area_exited(area: Area3D) -> void:
	var scannable = _get_scannable_from_area(area)
	if scannable == null:
		return
	
	if not scannable.has_method("get_unique_id"):
		return
	
	var uid = scannable.get_unique_id()
	
	# Remove from tracking
	nearby_scannables = nearby_scannables.filter(func(e): return e.uid != uid)
	
	# If this was our active target, report lost
	if uid == current_target_uid:
		_update_target("", null)

func _get_scannable_from_area(area: Area3D) -> Node3D:
	# Check if area's parent is a ScannableObject
	var parent = area.get_parent()
	while parent != null:
		if parent.has_method("get_unique_id") and parent.has_method("can_be_scanned"):
			return parent
		parent = parent.get_parent()
	return null

# ============================================
# PUBLIC INTERFACE (Query methods)
# ============================================

## Returns UID of currently targeted scannable (empty string if none)
func get_current_target_uid() -> String:
	return current_target_uid

## Returns the Node reference if still valid (or null)
func get_current_target_node() -> Node3D:
	if current_target_node:
		return current_target_node.get_ref() as Node3D
	return null

## Returns true if a valid target is currently detected
func has_target() -> bool:
	return not current_target_uid.is_empty()

## Returns all nearby scannable UIDs (for debugging)
func get_nearby_scannable_uids() -> Array[String]:
	var uids: Array[String] = []
	for entry in nearby_scannables:
		uids.append(entry.uid)
	return uids

## Forces a target update check (useful after teleports, etc.)
func force_update() -> void:
	detection_timer = detection_frequency

# ============================================
# DEBUG
# ============================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if not has_node("DetectionArea"):
		warnings.append("Missing DetectionArea child node")
	
	if camera == null:
		warnings.append("No Camera3D reference set (will auto-find at runtime)")
	
	return warnings

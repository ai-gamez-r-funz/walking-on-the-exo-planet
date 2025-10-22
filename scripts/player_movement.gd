extends CharacterBody3D
class_name Player
## Main player character controller for Snaut.
##
## Handles basic movement, jumping, and scanner input.
## Currently configured for hub navigation (indoor movement).
## Lunar physics and modifiers will be added for outdoor exploration.

# ============================================
# SIGNALS
# ============================================

## Emitted when player moves (provides velocity for ambient systems)
signal player_moved(velocity_vector: Vector3)

# ============================================
# MOVEMENT PARAMETERS - HUB CONFIGURATION
# ============================================

@export_group("Hub Movement")
## Base walking speed in hub areas
@export var walk_speed: float = 5.0

## Acceleration when starting to move
@export var acceleration: float = 10.0

## Deceleration when stopping
@export var friction: float = 12.0

## Jump velocity (small jump for navigation assistance)
@export var jump_velocity: float = 4.0

## Gravity multiplier (standard Earth-like gravity for hub)
@export var gravity_multiplier: float = 1.0

# ============================================
# INPUT CONFIGURATION
# ============================================

@export_group("Input")
## Key/button to initiate scanning
@export var scan_button: String = "scan"

## Movement input actions
@export var move_forward: String = "move_forward"
@export var move_back: String = "move_back"
@export var move_left: String = "move_left"
@export var move_right: String = "move_right"
@export var jump_action: String = "jump"

# ============================================
# STATE
# ============================================

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_moving: bool = false
var camera_basis: Basis = Basis()

var input_enabled: bool = true
# ============================================
# NODE REFERENCES
# ============================================

@onready var camera_controller: Node3D = $CameraController
@onready var mesh_root: Node3D = $meshy_snaut

# ============================================
# INITIALIZATION
# ============================================

func _ready() -> void:
	# Validate camera controller
	if camera_controller == null:
		push_error("Player: CameraController not found!")
		return
	
	# Connect to camera rotation updates
	if camera_controller.has_signal("camera_rotated"):
		camera_controller.camera_rotated.connect(_on_camera_rotated)
	else:
		push_error("Player: CameraController missing 'camera_rotated' signal!")
	
	# Validate mesh
	if mesh_root == null:
		push_warning("Player: Snaut mesh node not found - character won't rotate visually")
	
	print("Player initialized at position: ", global_position)

# ============================================
# PHYSICS PROCESS
# ============================================

func _physics_process(delta: float) -> void:
	_handle_gravity(delta)
	_handle_input()
	_handle_movement(delta)
	
	move_and_slide()
	
	# Emit movement signal
	if velocity.length() > 0.1:
		if not is_moving:
			is_moving = true
		player_moved.emit(velocity)
	else:
		if is_moving:
			is_moving = false

# ============================================
# GRAVITY
# ============================================

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * gravity_multiplier * delta

# ============================================
# INPUT HANDLING
# ============================================

func _handle_input() -> void:
	if not input_enabled:
		return
	# Scanning
	if Input.is_action_just_pressed(scan_button):
		ScannerManager.request_scan_start()
	
	# Jump
	if Input.is_action_just_pressed(jump_action) and is_on_floor():
		velocity.y = jump_velocity

func set_input_enabled(enabled: bool):
	input_enabled = enabled

# ============================================
# MOVEMENT
# ============================================

func _handle_movement(delta: float) -> void:
	# Get input
	var input_dir := Input.get_vector(move_left, move_right, move_forward, move_back)
	
	# Calculate direction relative to camera
	var direction := (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction.length() > 0:
		# Accelerate
		velocity.x = move_toward(velocity.x, direction.x * walk_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * walk_speed, acceleration * delta)
		
		# Rotate mesh to face movement
		_rotate_mesh_to_direction(direction, delta)
	else:
		# Friction
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)

# ============================================
# ROTATION
# ============================================

func _rotate_mesh_to_direction(direction: Vector3, delta: float) -> void:
	if mesh_root == null or direction.length() < 0.1:
		return
	
	var target_rotation := atan2(direction.x, direction.z)
	var current_rotation := mesh_root.rotation.y
	mesh_root.rotation.y = lerp_angle(current_rotation, target_rotation, 10.0 * delta)

# ============================================
# CAMERA CALLBACK
# ============================================

func _on_camera_rotated(new_camera_basis: Basis) -> void:
	camera_basis = new_camera_basis

# ============================================
# PUBLIC INTERFACE
# ============================================

func get_scanner_position() -> Vector3:
	var scanner_point = get_node_or_null("Snaut/Skeleton3D/BoneAttachment3D/ScannerAttachmentPoint")
	if scanner_point != null:
		return scanner_point.global_position
	return global_position + Vector3(0.5, 1.5, 0)

func get_scanner_direction() -> Vector3:
	return -camera_basis.z

func is_grounded() -> bool:
	return is_on_floor()

# ============================================
# DEBUG
# ============================================

func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		print("=== PLAYER DEBUG ===")
		print("Position: ", global_position)
		print("Velocity: ", velocity)
		print("Grounded: ", is_on_floor())
		print("Scanner Pos: ", get_scanner_position())
		print("Scanner Dir: ", get_scanner_direction())
		
	# ADDED: Debug controls (only in debug builds)
	if OS.is_debug_build():
		# DEBUG: Return to hub (F5)
		if event.is_action_pressed("debug_return_hub"):
			print("[Player] DEBUG: Returning to hub")
			SceneManager.transition_to_hub()
		
		# DEBUG: Cycle biome and reload world (F6)
		if event.is_action_pressed("debug_cycle_biome"):
			print("[Player] DEBUG: Cycling biome")
			WorldState.cycle_biome_for_debug()
			# Reload current scene to respawn with new biome
			await get_tree().create_timer(0.1).timeout
			get_tree().reload_current_scene()
		
		# DEBUG: Save game manually (F7)
		if event.is_action_pressed("debug_save"):
			print("[Player] DEBUG: Manual save")
			SaveManager.save_game()
		
		# DEBUG: Load game manually (F8)
		if event.is_action_pressed("debug_load"):
			print("[Player] DEBUG: Manual load")
			SaveManager.load_game()
		
		# DEBUG: Reset all discoveries (F9)
		if event.is_action_pressed("debug_reset_discoveries"):
			print("[Player] DEBUG: Resetting all discoveries")
			DiscoveryManager.reset_all_discoveries()
			get_tree().reload_current_scene()

# res://scripts/scanner/scannable_visual_feedback.gd
extends Node3D
class_name ScannableVisualFeedback
## Handles all visual feedback for a scannable object.
## Manages outline shader, particles, and animations.
## Attach this as a child of any ScannableObject.

# ============================================
# CONFIGURATION
# ============================================

## Color when object is detected (targeted)
@export var detected_color: Color = Color(0.0, 1.0, 1.0, 1.0)  # Cyan

## Color during active scan
@export var scanning_color: Color = Color(0.0, 1.0, 0.5, 1.0)  # Green

## Color for scanned objects
@export var scanned_color: Color = Color(0.5, 0.5, 0.5, 0.3)  # Dim gray

## Outline width
@export_range(0.0, 0.1) var outline_width: float = 0.015

# ============================================
# NODE REFERENCES
# ============================================

@onready var outline_mesh: MeshInstance3D = $OutlineMesh
@onready var scan_particles: GPUParticles3D = $ScanParticles

var outline_material: ShaderMaterial
var parent_scannable: ScannableObject

# ============================================
# LIFECYCLE
# ============================================

func _ready() -> void:
	# Get parent scannable
	parent_scannable = get_parent() as ScannableObject
	if parent_scannable == null:
		push_error("[ScannableVisualFeedback] Must be child of ScannableObject")
		return
	
	_setup_outline()
	_setup_particles()
	
	# Start hidden
	set_outline_visible(false)

func _setup_outline() -> void:
	if outline_mesh == null:
		push_warning("[ScannableVisualFeedback] No OutlineMesh - outline disabled")
		return
	
	# Duplicate parent's mesh for outline
	var parent_mesh_instance = _find_mesh_instance(parent_scannable)
	if parent_mesh_instance:
		outline_mesh.mesh = parent_mesh_instance.mesh
		
		# Create shader material
		var shader = load("res://shaders/scannable_outline.gdshader")
		outline_material = ShaderMaterial.new()
		outline_material.shader = shader
		outline_material.set_shader_parameter("outline_color", detected_color)
		outline_material.set_shader_parameter("outline_width", outline_width)
		outline_material.set_shader_parameter("show_outline", false)
		
		outline_mesh.material_override = outline_material
	else:
		push_warning("[ScannableVisualFeedback] No mesh found on parent")

func _setup_particles() -> void:
	if scan_particles == null:
		return
	
	scan_particles.emitting = false

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	# Search for MeshInstance3D in parent's children
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null

# ============================================
# PUBLIC INTERFACE (Called by ScannableObject)
# ============================================

func show_detected() -> void:
	if outline_material:
		outline_material.set_shader_parameter("outline_color", detected_color)
		outline_material.set_shader_parameter("show_outline", true)
		outline_material.set_shader_parameter("scan_progress", 0.0)

func hide_detected() -> void:
	set_outline_visible(false)
	if scan_particles:
		scan_particles.emitting = false

func show_scanning() -> void:
	if outline_material:
		outline_material.set_shader_parameter("outline_color", scanning_color)
		outline_material.set_shader_parameter("show_outline", true)
	
	if scan_particles:
		scan_particles.emitting = true

func update_scan_progress(progress: float) -> void:
	if outline_material:
		outline_material.set_shader_parameter("scan_progress", progress)

func show_completed() -> void:
	if scan_particles:
		scan_particles.emitting = false
	
	# Flash effect
	if outline_material:
		outline_material.set_shader_parameter("outline_color", Color.GREEN)
		outline_material.set_shader_parameter("outline_intensity", 2.0)
	
	await get_tree().create_timer(0.3).timeout
	
	# Fade to scanned state
	if outline_material:
		outline_material.set_shader_parameter("outline_color", scanned_color)
		outline_material.set_shader_parameter("outline_intensity", 0.5)

func show_interrupted() -> void:
	if scan_particles:
		scan_particles.emitting = false
	
	# Brief red flash
	if outline_material:
		outline_material.set_shader_parameter("outline_color", Color.RED)
	
	await get_tree().create_timer(0.2).timeout
	set_outline_visible(false)

func set_outline_visible(visible: bool) -> void:
	if outline_material:
		outline_material.set_shader_parameter("show_outline", visible)

# ============================================
# SCANNED STATE INDICATOR
# ============================================

func show_as_scanned(tier: int) -> void:
	# Show subtle outline for already-scanned objects
	if outline_material:
		var alpha = 0.3 - (tier * 0.05)  # Fade more with each tier
		var color = scanned_color
		color.a = alpha
		outline_material.set_shader_parameter("outline_color", color)
		outline_material.set_shader_parameter("show_outline", true)

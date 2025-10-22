extends Node3D

@export_group("Camera Settings")
@export var sensitivity: float = 0.002
@export var camera_limit_degrees: float = 85.0
@export var camera_distance: float = 5.0
@export var camera_height: float = 2.0
@export var camera_offset: Vector3 = Vector3(0, 0, 0)

@export_group("Zoom Settings")
@export var zoom_speed: float = 0.5
@export var min_zoom: float = 2.0
@export var max_zoom: float = 10.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var camera_rotation: Vector3 = Vector3.ZERO
var current_zoom: float

signal camera_rotated(camera_basis: Basis)

func _ready() -> void:
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	current_zoom = camera_distance
	
	spring_arm.spring_length = current_zoom
	spring_arm.position.y = camera_height
	spring_arm.position += camera_offset
	
	spring_arm.add_excluded_object(get_parent())
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.5

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		camera_rotation.x -= event.relative.y * sensitivity
		camera_rotation.y -= event.relative.x * sensitivity
		
		camera_rotation.x = clamp(
			camera_rotation.x, 
			deg_to_rad(-camera_limit_degrees), 
			deg_to_rad(camera_limit_degrees)
		)
		
		transform.basis = Basis()
		transform.basis = transform.basis.rotated(Vector3.UP, camera_rotation.y)
		spring_arm.transform.basis = Basis()
		spring_arm.transform.basis = spring_arm.transform.basis.rotated(Vector3.RIGHT, camera_rotation.x)
		
		emit_signal("camera_rotated", camera.global_transform.basis)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		adjust_zoom(-zoom_speed)
	elif event.is_action_pressed("zoom_out"):
		adjust_zoom(zoom_speed)

func adjust_zoom(zoom_adjustment: float) -> void:
	current_zoom = clamp(current_zoom + zoom_adjustment, min_zoom, max_zoom)
	spring_arm.spring_length = current_zoom

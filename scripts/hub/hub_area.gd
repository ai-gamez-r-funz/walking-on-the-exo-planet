# res://scenes/hub/hub_area.gd
extends Node3D

# Node references
@onready var tutorial_sphere: Node3D = $TutorialSphere
@onready var teleport_pad: Node3D = $TeleportPad
@onready var teleport_cylinder: MeshInstance3D = $TeleportPad/TeleportCylinder
@onready var glow_particles: GPUParticles3D = $TeleportPad/GlowParticles

# State
var tutorial_completed: bool = false
var transition_unlocked: bool = false

func _ready():
	# Load save state
	_load_tutorial_state()
	
	# Connect to discovery system
	DiscoveryManager.scan_recorded.connect(_on_scan_recorded)
	
	# Setup teleport pad
	_setup_teleport_pad()
	
	# Wait for player to spawn, then start tutorial
	await get_tree().create_timer(1.5).timeout
	
	if not tutorial_completed:
		_start_tutorial()
	else:
		_unlock_world_transition()  # Already done tutorial

func _load_tutorial_state():
	"""Check if tutorial was already completed"""
	tutorial_completed = DiscoveryManager.has_scanned("tutorial_sphere_001")
	print("[HubArea] Tutorial completed: %s" % tutorial_completed)

func _start_tutorial():
	"""Lucy's intro dialogue"""
	DialogueManager.show_message(
		"Lucy",
		"Snaut! Thank goodness you're here. I'm getting some very strange readings from outside the base."
	)
	
	await get_tree().create_timer(4.5).timeout
	
	DialogueManager.show_message(
		"Lucy",
		"I can't leave the lab right now, but I need you to check something for me."
	)
	
	await get_tree().create_timer(4.5).timeout
	
	DialogueManager.show_message(
		"Lucy",
		"See that calibration sphere? Try scanning it with your ScanBoy Advance™ to make sure everything's working."
	)
	
	await get_tree().create_timer(4.5).timeout
	
	DialogueManager.show_message(
		"Lucy",
		"Just hold the scan button while aiming at it. Should only take a second."
	)

func _on_scan_recorded(item_uid: String, is_new: bool):
	"""Handle tutorial sphere scan completion"""
	if item_uid == "artifact_001" and not transition_unlocked:
		_complete_tutorial()

func _complete_tutorial():
	"""Tutorial scan done - unlock world"""
	transition_unlocked = true
	
	# Lucy's completion dialogue
	await get_tree().create_timer(1.0).timeout
	
	DialogueManager.show_message(
		"Lucy",
		"Perfect! The scanner's working correctly."
	)
	
	await get_tree().create_timer(4.0).timeout
	
	DialogueManager.show_message(
		"Lucy",
		"Now... those readings I mentioned. They're coming from just outside the base perimeter."
	)
	
	await get_tree().create_timer(4.5).timeout
	
	DialogueManager.show_message(
		"Lucy",
		"I've unlocked the transition zone. Head out there and see what you can find."
	)
	
	await get_tree().create_timer(4.5).timeout
	
	DialogueManager.show_message(
		"Lucy",
		"Oh, and... Chad mentioned he might have left some things lying around. *sigh* Typical."
	)
	
	# Activate teleport pad
	await get_tree().create_timer(2.0).timeout
	_unlock_world_transition()
	
	# Optional: Chad's humorous comment
	await get_tree().create_timer(5.0).timeout
	DialogueManager.show_message(
		"Chad",
		"Hey Snaut! If you see any of my stuff out there... maybe don't mention it to Lucy?"
	)

func _unlock_world_transition():
	"""Activate the teleport pad"""
	teleport_pad.visible = true
	
	# Enable collision for player detection
	var area = teleport_pad.get_node("TransitionArea") as Area3D
	if area:
		area.monitoring = true
		area.body_entered.connect(_on_player_entered_teleport)
	
	# Visual feedback - glow effect
	glow_particles.emitting = true

func _on_player_entered_teleport(body: Node3D):
	"""Player stepped on teleport pad"""
	if not body.is_in_group("player"):
		return
	
	print("[HubArea] Teleport triggered!")
	_play_teleport_effect()

func _play_teleport_effect():
	"""Star Trek / Futurama teleport animation with proper 3D tweening"""
	
	# Disable player control
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
	
	# Get cylinder mesh and material
	var cyl_mesh = teleport_cylinder as MeshInstance3D
	var cyl_material = cyl_mesh.get_active_material(0) as StandardMaterial3D
	
	# Setup cylinder initial state
	teleport_cylinder.visible = true
	teleport_cylinder.position.y = 0.0
	teleport_cylinder.scale = Vector3(0.8, 0.1, 0.8)  # Start squashed
	
	if cyl_material:
		cyl_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cyl_material.albedo_color.a = 0.0
	
	# PHASE 1: Cylinder materializes and rises
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Cylinder rises
	tween.tween_property(teleport_cylinder, "position:y", 3.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Cylinder scales to full size
	tween.tween_property(teleport_cylinder, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Cylinder fades in
	if cyl_material:
		tween.tween_property(cyl_material, "albedo_color:a", 0.8, 0.3)
	
	# Wait a moment before starting player disappear
	await get_tree().create_timer(0.4).timeout
	
	# PHASE 2: Player disappears (shrinks and fades)
	var player_tween = create_tween()
	player_tween.set_parallel(true)
	
	# Player shrinks down
	player_tween.tween_property(player, "scale", Vector3(0.1, 0.1, 0.1), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Player spins slightly for extra effect
	var current_rotation = player.rotation.y
	player_tween.tween_property(player, "rotation:y", current_rotation + TAU, 0.8)
	
	# Optional: If player has a mesh with material, fade that too
	var player_mesh = player.get_node_or_null("MeshInstance3D")
	if player_mesh:
		var player_material = player_mesh.get_active_material(0)
		if player_material and player_material is StandardMaterial3D:
			player_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			player_tween.tween_property(player_material, "albedo_color:a", 0.0, 0.8)
	
	await player_tween.finished
	
	# PHASE 3: Cylinder descends into ground
	var tween2 = create_tween()
	tween2.set_parallel(true)
	
	# Cylinder sinks
	tween2.tween_property(teleport_cylinder, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Cylinder squashes as it descends
	tween2.tween_property(teleport_cylinder, "scale", Vector3(1.0, 0.1, 1.0), 0.6)
	
	# Cylinder fades out
	if cyl_material:
		tween2.tween_property(cyl_material, "albedo_color:a", 0.0, 0.6)
	
	await tween2.finished
	
	# Hide cylinder
	teleport_cylinder.visible = false
	
	# Reset player scale/rotation (in case transition keeps the player object)
	player.scale = Vector3.ONE
	player.rotation.y = 0.0
	
	# Transition to world
	print("[HubArea] Teleporting to world...")
	SceneManager._transition_to_scene("res://scenes/world/world.tscn")

func _setup_teleport_pad():
	"""Initial teleport pad configuration"""
	teleport_pad.visible = false if not tutorial_completed else true
	teleport_cylinder.visible = false
	
	# Ensure TransitionArea exists
	var area = teleport_pad.get_node_or_null("TransitionArea")
	if area:
		area.monitoring = tutorial_completed

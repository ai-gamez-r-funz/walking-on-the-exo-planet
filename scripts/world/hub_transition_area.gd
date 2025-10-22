# hub_transition_area.gd
# Handles transition from hub to world when player enters area
# Attach to Area3D node in hub scene
# Path: res://scripts/hub_transition_area.gd

extends Area3D

@export var transition_label: String = "Enter Exploration Zone"
@export var show_ui_prompt: bool = true  # For Phase 6 UI implementation

var player_in_area: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("[HubTransition] Ready - Press E to enter world")

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_in_area = true
		print("[HubTransition] Player entered area - Press E to transition to world")
		# TODO Phase 6: Show UI prompt with transition_label

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_in_area = false
		print("[HubTransition] Player left area")
		# TODO Phase 6: Hide UI prompt

func _input(event):
	if player_in_area and event.is_action_pressed("interact"):
		print("[HubTransition] Transitioning to world...")
		SceneManager.transition_to_world()

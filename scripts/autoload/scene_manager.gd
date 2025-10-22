# res://autoload/scene_manager.gd
extends Node

const HUB_SCENE_PATH = "res://scenes/hub_area.tscn"
const WORLD_SCENE_PATH = "res://scenes/world.tscn"

var current_scene_path: String = ""
var is_transitioning: bool = false

signal transition_started(to_scene: String)
signal transition_completed(scene_name: String)

func _ready():
	print("[SceneManager] Initialized")

func transition_to_hub():
	if is_transitioning:
		return
	_transition_to_scene(HUB_SCENE_PATH)

func transition_to_world():
	if is_transitioning:
		return
	_transition_to_scene(WORLD_SCENE_PATH)

func _transition_to_scene(scene_path: String):
	is_transitioning = true
	transition_started.emit(scene_path)
	
	# Auto-save before transition
	SaveManager.save_game()
	
	print("[SceneManager] Transitioning to: %s" % scene_path)
	
	# Simple immediate transition (add fade later)
	get_tree().change_scene_to_file(scene_path)
	current_scene_path = scene_path
	
	is_transitioning = false
	transition_completed.emit(scene_path.get_file().get_basename())

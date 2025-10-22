# res://scripts/world/scannable_pool_manager.gd
# FIXED: Removed scene_path hallucination
# Manages which scannable objects can spawn and where

class_name ScannablePoolManager
extends Node

# Pool of available scannable scenes organized by category
var flora_pool: Array[PackedScene] = []
var mineral_pool: Array[PackedScene] = []
var artifact_pool: Array[PackedScene] = []

# Biome-specific spawn weights (for future Phase 4)
var biome_preferences: Dictionary = {}
var current_biome: String = "starter"

func _ready():
	# Connect to biome changes if WorldState exists
	if has_node("/root/WorldState"):
		var world_state = get_node("/root/WorldState")
		if world_state.has_signal("biome_changed"):
			world_state.biome_changed.connect(_on_biome_changed)
		current_biome = world_state.get("current_biome") if "current_biome" in world_state else "starter"
	
	_initialize_pools()
	print("[ScannablePoolManager] Initialized with biome: %s" % current_biome)

func _on_biome_changed(new_biome: String):
	current_biome = new_biome
	print("[ScannablePoolManager] Biome changed to: %s - reinitializing pools" % new_biome)
	_initialize_pools()

func _initialize_pools():
	flora_pool.clear()
	mineral_pool.clear()
	artifact_pool.clear()
	
	# FIXED: Load scenes directly from resources/scannables directory
	# The scenes themselves have CollectionItemData attached
	_load_scenes_from_directory("res://scenes/scannables/flora/", flora_pool)
	_load_scenes_from_directory("res://scenes/scannables/minerals/", mineral_pool)
	_load_scenes_from_directory("res://scenes/scannables/artifacts/", artifact_pool)
	
	print("[ScannablePoolManager] Biome '%s' pools initialized: Flora=%d, Mineral=%d, Artifact=%d" % [
		current_biome,
		flora_pool.size(),
		mineral_pool.size(),
		artifact_pool.size()
	])

func _load_scenes_from_directory(path: String, target_pool: Array[PackedScene]) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("[ScannablePoolManager] Could not open directory: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Load scenes by item_key naming (e.g., basic_plant.tscn)
		if file_name.ends_with(".tscn"):
			var scene_path = path + file_name
			var scene = load(scene_path)
			if scene:
				target_pool.append(scene)
			else:
				push_warning("[ScannablePoolManager] Failed to load scene: %s" % scene_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

# ADD: Helper to get item_key from scene for debugging
func _get_item_key_from_scene(scene: PackedScene) -> String:
	"""Extract item_key from scene path (e.g., 'basic_plant.tscn' -> 'basic_plant')"""
	if not scene:
		return ""
	
	var scene_path = scene.resource_path
	var file_name = scene_path.get_file()  # Gets "basic_plant.tscn"
	return file_name.get_basename()  # Gets "basic_plant"

# Get a random scannable object appropriate for the given location
# For Phase 1: Just random selection
# For Phase 4: Will use biome data and terrain height
func get_scannable_for_location(world_pos: Vector3, terrain_height: float) -> PackedScene:
	# Phase 1: Simple random selection with weighted categories
	var category_roll := randf()
	
	# 60% flora, 30% minerals, 10% artifacts
	if category_roll < 0.6:
		return _get_random_from_pool(flora_pool)
	elif category_roll < 0.9:
		return _get_random_from_pool(mineral_pool)
	else:
		return _get_random_from_pool(artifact_pool)

# Get random scene from a pool
func _get_random_from_pool(pool: Array[PackedScene]) -> PackedScene:
	if pool.is_empty():
		push_error("[ScannablePoolManager] Attempted to spawn from empty pool!")
		return null
	
	return pool[randi() % pool.size()]

# Future Phase 4 method: Get scannable based on biome preferences
func get_scannable_for_biome(biome_name: String, world_pos: Vector3, terrain_height: float) -> PackedScene:
	# To be implemented in Phase 4 when biome system is added
	# For now, just use location-based spawning
	return get_scannable_for_location(world_pos, terrain_height)

# Check if a scannable type should spawn based on discovery progression
# Phase 1: Always return true
# Phase 3+: Check against discovery_manager unlock thresholds
func is_scannable_unlocked(scannable_scene: PackedScene) -> bool:
	# Phase 1: All scannables are available from start
	# Phase 3: Will check unlock thresholds
	return true

# Get spawn density for current progression level
func get_spawn_density() -> Dictionary:
	# Phase 1: Return default config
	# Phase 4: Modify based on world evolution
	return {
		"per_chunk": {
			"min": 2,
			"max": 5
		},
		"min_spacing": 15.0,
		"height_offset": 0.5
	}

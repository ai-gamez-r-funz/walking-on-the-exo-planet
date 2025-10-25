# res://scripts/world/scannable_pool_manager.gd
# UPDATED: Added get_scene_for_item() method for loot table integration
# Manages which scannable objects can spawn and where

class_name ScannablePoolManager
extends Node

# Pool of available scannable scenes organized by category
var flora_pool: Array[PackedScene] = []
var mineral_pool: Array[PackedScene] = []
var artifact_pool: Array[PackedScene] = []

# Mapping from item_uid to scene path
var uid_to_scene_map: Dictionary = {}

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
	_build_uid_to_scene_map()
	print("[ScannablePoolManager] Initialized with biome: %s" % current_biome)

func _on_biome_changed(new_biome: String):
	current_biome = new_biome
	print("[ScannablePoolManager] Biome changed to: %s - reinitializing pools" % new_biome)
	_initialize_pools()
	_build_uid_to_scene_map()

func _initialize_pools():
	flora_pool.clear()
	mineral_pool.clear()
	artifact_pool.clear()
	
	# Load scenes directly from resources/scannables directory
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

# NEW METHOD: Build mapping from item_uid to scene path
func _build_uid_to_scene_map():
	"""Build a lookup table from item_uid to PackedScene"""
	uid_to_scene_map.clear()
	
	# Scan all pools and extract item_uid from each scene
	var all_scenes: Array[PackedScene] = []
	all_scenes.append_array(flora_pool)
	all_scenes.append_array(mineral_pool)
	all_scenes.append_array(artifact_pool)
	
	for scene in all_scenes:
		# Instantiate temporarily to read the CollectionItemData
		var temp_instance = scene.instantiate()
		
		# Check if it has the collection_item_data property
		if "collection_item_data" in temp_instance:
			var item_data = temp_instance.collection_item_data as CollectionItemData
			if item_data and item_data.item_uid != "":
				uid_to_scene_map[item_data.item_uid] = scene
		
		# Clean up temporary instance
		temp_instance.queue_free()
	
	print("[ScannablePoolManager] Built UID map with %d entries" % uid_to_scene_map.size())

# NEW METHOD: Get scene for a specific CollectionItemData
func get_scene_for_item(item_data: CollectionItemData) -> PackedScene:
	"""
	Get the PackedScene for a specific CollectionItemData.
	Used by BiomeSpawnManager loot table system.
	"""
	if not item_data:
		push_error("[ScannablePoolManager] get_scene_for_item called with null item_data")
		return null
	
	var item_uid = item_data.item_uid
	
	if uid_to_scene_map.has(item_uid):
		return uid_to_scene_map[item_uid]
	else:
		push_error("[ScannablePoolManager] No scene found for item_uid: %s (%s)" % [
			item_uid,
			item_data.display_name
		])
		return null

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

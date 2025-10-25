# res://autoload/biome_spawn_manager.gd
# Autoload singleton that manages loot table spawning for biomes
# Implements point-based budget system with rarity weights and pity mechanics

extends Node

# ============================================
# CONFIGURATION
# ============================================

## Enable testing mode with generous spawn rates for debugging
@export var use_testing_rates: bool = true

## Testing mode: High legendary chance for easy verification
@export_range(0.0, 1.0) var testing_legendary_chance: float = 0.50

## Testing mode: More items per chunk
@export_range(1, 20) var testing_items_per_chunk: int = 12

## Production mode: Balanced legendary chance
const PRODUCTION_LEGENDARY_CHANCE: float = 0.05

## Production mode: Balanced items per chunk
const PRODUCTION_MIN_ITEMS: int = 4
const PRODUCTION_MAX_ITEMS: int = 7

## Pity mechanic: Increment per failed legendary roll
const PITY_INCREMENT: float = 0.05

## Pity cap: Maximum pity bonus
const PITY_CAP: float = 1.0

# ============================================
# RARITY POINT COSTS
# ============================================

const POINT_COSTS = {
	0: 1,  # Common = 1 point
	1: 2,  # Uncommon = 2 points
	2: 3,  # Rare = 3 points
	3: 5   # Legendary = 5 points
}

# ============================================
# STATE
# ============================================

## All loaded collection items, organized by biome
var items_by_biome: Dictionary = {}  # Key: biome_name, Value: Array[CollectionItemData]

## Legendary pity counter (0.0 to 1.0)
var legendary_pity_counter: float = 0.0

## Total items loaded
var total_items_loaded: int = 0

# ============================================
# SIGNALS
# ============================================

signal legendary_spawned(item_name: String)
signal pity_updated(current_pity: float)

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	_load_all_collection_items()
	print("[BiomeSpawnManager] Initialized with %d collection items" % total_items_loaded)
	print("[BiomeSpawnManager] Testing mode: %s" % ("ENABLED" if use_testing_rates else "DISABLED"))
	if use_testing_rates:
		print("[BiomeSpawnManager] - Legendary chance: %.1f%%" % (testing_legendary_chance * 100))
		print("[BiomeSpawnManager] - Items per chunk: %d" % testing_items_per_chunk)

func _load_all_collection_items():
	"""Load all CollectionItemData resources and organize by biome"""
	items_by_biome.clear()
	
	var items_dir = "res://resources/collection_items/"
	var dir = DirAccess.open(items_dir)
	
	if not dir:
		push_error("[BiomeSpawnManager] Could not open directory: %s" % items_dir)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource_path = items_dir + file_name
			var item_data = load(resource_path) as CollectionItemData
			
			if item_data and item_data.is_valid():
				_register_item_for_biomes(item_data)
				total_items_loaded += 1
			else:
				push_warning("[BiomeSpawnManager] Invalid or missing data for: %s" % file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Log biome distribution
	for biome_name in items_by_biome.keys():
		var items = items_by_biome[biome_name]
		print("[BiomeSpawnManager] Biome '%s': %d items" % [biome_name, items.size()])

func _register_item_for_biomes(item_data: CollectionItemData):
	"""Register item for each biome it can spawn in"""
	for biome_name in item_data.biome_affinity:
		if not items_by_biome.has(biome_name):
			items_by_biome[biome_name] = []
		
		items_by_biome[biome_name].append(item_data)

# ============================================
# LOOT TABLE GENERATION
# ============================================

func generate_chunk_items(biome_name: String) -> Array[CollectionItemData]:
	"""
	Generate a loot table for a chunk based on point budget and rarity weights.
	Returns array of specific CollectionItemData to spawn.
	"""
	
	# Get items available for this biome
	if not items_by_biome.has(biome_name):
		push_warning("[BiomeSpawnManager] No items available for biome: %s" % biome_name)
		return []
	
	var available_items = items_by_biome[biome_name]
	
	if available_items.is_empty():
		push_warning("[BiomeSpawnManager] Biome '%s' has no items" % biome_name)
		return []
	
	# Determine point budget for this chunk
	var point_budget = _get_point_budget()
	
	print("[BiomeSpawnManager] === Generating chunk for '%s' with %d points ===" % [biome_name, point_budget])
	
	# Generate loot table
	var selected_items: Array[CollectionItemData] = []
	var points_spent = 0
	
	# Step 1: Try to spawn legendary (with pity)
	var legendary_items = _filter_by_rarity(available_items, 3)
	if legendary_items.size() > 0:
		var legendary_roll = randf()
		var legendary_chance = _get_legendary_chance()
		
		print("[BiomeSpawnManager] Legendary roll: %.2f vs %.2f chance (pity: %.2f%%)" % [
			legendary_roll,
			legendary_chance,
			legendary_pity_counter * 100
		])
		
		if legendary_roll < legendary_chance:
			var legendary = legendary_items.pick_random()
			selected_items.append(legendary)
			points_spent += POINT_COSTS[legendary.rarity]
			legendary_spawned.emit(legendary.display_name)
			_reset_pity()
			print("[BiomeSpawnManager] ✨ LEGENDARY SPAWNED: %s" % legendary.display_name)
		else:
			_increment_pity()
			print("[BiomeSpawnManager] Legendary roll failed (new pity: %.2f%%)" % (legendary_pity_counter * 100))
	
	# Step 2: Try to spawn rare items
	var rare_items = _filter_by_rarity(available_items, 2)
	while points_spent < point_budget and rare_items.size() > 0:
		var rare_cost = POINT_COSTS[2]
		if points_spent + rare_cost > point_budget:
			break
		
		if randf() < 0.3:  # 30% chance to add a rare
			var rare = rare_items.pick_random()
			selected_items.append(rare)
			points_spent += rare_cost
			print("[BiomeSpawnManager] 💎 Rare spawned: %s" % rare.display_name)
		else:
			break
	
	# Step 3: Try to spawn uncommon items
	var uncommon_items = _filter_by_rarity(available_items, 1)
	while points_spent < point_budget and uncommon_items.size() > 0:
		var uncommon_cost = POINT_COSTS[1]
		if points_spent + uncommon_cost > point_budget:
			break
		
		if randf() < 0.5:  # 50% chance to add an uncommon
			var uncommon = uncommon_items.pick_random()
			selected_items.append(uncommon)
			points_spent += uncommon_cost
			print("[BiomeSpawnManager] 🔷 Uncommon spawned: %s" % uncommon.display_name)
		else:
			break
	
	# Step 4: Fill remaining budget with commons
	var common_items = _filter_by_rarity(available_items, 0)
	var commons_added = 0
	while points_spent < point_budget and common_items.size() > 0:
		var common_cost = POINT_COSTS[0]
		if points_spent + common_cost > point_budget:
			break
		
		var common = common_items.pick_random()
		selected_items.append(common)
		points_spent += common_cost
		commons_added += 1
	
	if commons_added > 0:
		print("[BiomeSpawnManager] ⚪ Filled with %d commons" % commons_added)
	
	print("[BiomeSpawnManager] Generated %d items (%d points remaining)" % [
		selected_items.size(),
		point_budget - points_spent
	])
	print("[BiomeSpawnManager] === End chunk generation ===")
	
	return selected_items

# ============================================
# HELPER METHODS
# ============================================

func _get_point_budget() -> int:
	"""Get point budget based on mode (testing vs production)"""
	if use_testing_rates:
		return testing_items_per_chunk  # In testing, 1 point per item for simplicity
	else:
		return randi_range(PRODUCTION_MIN_ITEMS, PRODUCTION_MAX_ITEMS)

func _get_legendary_chance() -> float:
	"""Get legendary spawn chance with pity bonus"""
	var base_chance = testing_legendary_chance if use_testing_rates else PRODUCTION_LEGENDARY_CHANCE
	return min(base_chance + legendary_pity_counter, PITY_CAP)

func _increment_pity():
	"""Increment pity counter after failed legendary roll"""
	legendary_pity_counter = min(legendary_pity_counter + PITY_INCREMENT, PITY_CAP)
	pity_updated.emit(legendary_pity_counter)

func _reset_pity():
	"""Reset pity counter after successful legendary spawn"""
	legendary_pity_counter = 0.0
	pity_updated.emit(legendary_pity_counter)

func _filter_by_rarity(items: Array[CollectionItemData], rarity: int) -> Array[CollectionItemData]:
	"""Filter items by specific rarity value"""
	var filtered: Array[CollectionItemData] = []
	for item in items:
		if item.rarity == rarity:
			filtered.append(item)
	return filtered

# ============================================
# PUBLIC API
# ============================================

func reset_pity_counter():
	"""Manually reset pity (useful for testing or save/load)"""
	legendary_pity_counter = 0.0
	pity_updated.emit(legendary_pity_counter)
	print("[BiomeSpawnManager] Pity counter reset")

func get_pity_counter() -> float:
	"""Get current pity value (0.0 to 1.0)"""
	return legendary_pity_counter

func get_biome_stats(biome_name: String) -> Dictionary:
	"""Get statistics about items available in a biome"""
	if not items_by_biome.has(biome_name):
		return {"error": "Biome not found"}
	
	var items = items_by_biome[biome_name]
	var stats = {
		"total": items.size(),
		"common": 0,
		"uncommon": 0,
		"rare": 0,
		"legendary": 0
	}
	
	for item in items:
		match item.rarity:
			0: stats.common += 1
			1: stats.uncommon += 1
			2: stats.rare += 1
			3: stats.legendary += 1
	
	return stats
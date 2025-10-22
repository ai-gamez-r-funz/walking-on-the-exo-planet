# res://autoload/discovery_manager.gd
extends Node

# Discovery tracking
var scanned_items: Dictionary = {}  # Key: item_id, Value: ScanDiscoveryData
var total_scans: int = 0

# ADD: Cache for loaded item data
var _item_data_cache: Dictionary = {}  # item_uid → CollectionItemData

# Unlock thresholds (for future phases)
var scan_thresholds: Dictionary = {
	"temperate_unlock": 5,  # Scan 5 items to unlock temperate
	"animal_unlock": 15,
	"exotic_unlock": 25
}

signal scan_recorded(item_id: String, is_new_discovery: bool)
signal threshold_reached(threshold_name: String)
signal collection_updated()

class ScanDiscoveryData:
	var item_id: String
	var scan_tier: int = 1  # 1=basic, 2=detailed, 3=complete
	var times_scanned: int = 0
	var first_scan_time: float = 0.0
	var last_scan_time: float = 0.0

# ADD: Progression gate definitions
var progression_gates: Dictionary = {
	"hub": {
		"name": "Hub Tutorial",
		"total_scans_required": 1,
		"unique_items_required": 1,
		"tier_3_required": 0,
		"unlocks_biome": "biome_1"
	},
	"biome_1": {
		"name": "Starting Area - Chad's Lost Items",
		"total_scans_required": 10,  # Scan 3 items multiple times
		"unique_items_required": 3,  # Chad's Bag, Lunch, Garbage
		"tier_3_required": 1,  # At least one common to tier 3
		"unlocks_biome": "biome_2"
	},
	"biome_2": {
		"name": "Temperate Zone",
		"total_scans_required": 25,
		"unique_items_required": 8,
		"tier_3_required": 2,
		"unlocks_biome": "biome_3"
	},
	"biome_3": {
		"name": "Lush Biome",
		"total_scans_required": 50,
		"unique_items_required": 15,
		"tier_3_required": 3,
		"unlocks_biome": "biome_4"
	},
	"biome_4": {
		"name": "Exotic Biome",
		"total_scans_required": 80,
		"unique_items_required": 20,
		"tier_3_required": 5,
		"unlocks_biome": "complete"
	}
}

# ADD: New signals
signal biome_unlocked(biome_name: String)
signal progression_milestone(milestone_name: String, progress: Dictionary)

func _ready():
	# Connect to ScannerManager to receive scan completions
	ScannerManager.scan_completed.connect(_on_scanner_completed)
	
	print("[DiscoveryManager] Initialized and connected to ScannerManager")
	# Preload all collection item data on startup (optional optimization)
	_preload_collection_items()
	

# SIMPLIFIED: record_scan now just uses the data we already have
func record_scan(item_uid: String, item_data: CollectionItemData) -> bool:
	"""
	Record a scan and update tier progression.
	item_data is passed directly from the scannable object via signal.
	No filesystem searching needed!
	"""
	var is_new = not scanned_items.has(item_uid)
	
	if is_new:
		# First scan - create new entry
		scanned_items[item_uid] = ScanDiscoveryData.new()
		scanned_items[item_uid].item_id = item_uid
		scanned_items[item_uid].first_scan_time = Time.get_unix_time_from_system()
		scanned_items[item_uid].times_scanned = 1
		scanned_items[item_uid].scan_tier = 1
	else:
		# Additional scan - increment count
		scanned_items[item_uid].times_scanned += 1
		
		# Update tier based on rarity-adjusted thresholds
		var times_scanned = scanned_items[item_uid].times_scanned
		scanned_items[item_uid].scan_tier = item_data.get_tier_from_scan_count(times_scanned)
	
	total_scans += 1
	
	# Emit signals
	scan_recorded.emit(item_uid, is_new)
	collection_updated.emit()
	
	# Check if this scan unlocked a biome
	_check_biome_unlock()
	
	var tier = scanned_items[item_uid].scan_tier
	var times = scanned_items[item_uid].times_scanned
	print("[DiscoveryManager] Scan recorded: %s (Tier %d, Scans: %d/%d)" % [
		item_data.display_name,
		tier,
		times,
		item_data.get_scans_for_tier(3)
	])
	
	return is_new

# ADD: Check biome progression
func check_biome_progression(biome_name: String) -> Dictionary:
	"""
	Returns progression status for a biome.
	"""
	if not progression_gates.has(biome_name):
		return {}
	
	var gate = progression_gates[biome_name]
	var biome_items = _get_biome_items(biome_name)
	
	# Count scans in this biome
	var biome_total_scans = 0
	var biome_unique_items = 0
	var biome_tier_3_count = 0
	
	for item_uid in biome_items:
		if scanned_items.has(item_uid):
			var scan_data = scanned_items[item_uid]
			biome_total_scans += scan_data.times_scanned
			biome_unique_items += 1
			
			if scan_data.scan_tier >= 3:
				biome_tier_3_count += 1
	
	var is_complete = (
		biome_total_scans >= gate.total_scans_required and
		biome_unique_items >= gate.unique_items_required and
		biome_tier_3_count >= gate.tier_3_required
	)
	
	return {
		"total_scans": biome_total_scans,
		"total_scans_required": gate.total_scans_required,
		"unique_items": biome_unique_items,
		"unique_items_required": gate.unique_items_required,
		"tier_3_count": biome_tier_3_count,
		"tier_3_required": gate.tier_3_required,
		"is_complete": is_complete,
		"can_unlock_next": is_complete,
		"next_biome": gate.unlocks_biome if is_complete else ""
	}

func _get_biome_items(biome_name: String) -> Array[String]:
	"""
	Get all item UIDs that belong to this biome.
	Only used for checking progression gates, not for recording scans.
	"""
	var items: Array[String] = []
	
	# Single unified location for all collection item data
	var collection_dir = "res://data/collection_items/"
	var dir = DirAccess.open(collection_dir)
	
	if not dir:
		return items
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item_data = load(collection_dir + file_name) as CollectionItemData
			if item_data and item_data.can_spawn_in_biome(biome_name):
				items.append(item_data.item_uid)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return items


func _check_thresholds():
	for threshold_name in scan_thresholds:
		var required = scan_thresholds[threshold_name]
		if total_scans == required:
			threshold_reached.emit(threshold_name)
			print("[DiscoveryManager] THRESHOLD REACHED: %s" % threshold_name)

func has_scanned(item_id: String) -> bool:
	return scanned_items.has(item_id)

func get_scan_data(item_id: String) -> ScanDiscoveryData:
	return scanned_items.get(item_id, null)

func get_discovery_stats() -> Dictionary:
	return {
		"total_scans": total_scans,
		"unique_items": scanned_items.size(),
		"completion_percentage": 0.0  # Calculate based on total available items later
	}

func to_save_dict() -> Dictionary:
	var save_data = {
		"total_scans": total_scans,
		"scanned_items": {}
	}
	
	for item_id in scanned_items:
		var discovery = scanned_items[item_id]
		save_data.scanned_items[item_id] = {
			"scan_tier": discovery.scan_tier,
			"times_scanned": discovery.times_scanned,
			"first_scan_time": discovery.first_scan_time,
			"last_scan_time": discovery.last_scan_time
		}
	
	return save_data

func load_from_dict(data: Dictionary):
	scanned_items.clear()
	total_scans = data.get("total_scans", 0)
	
	var items_data = data.get("scanned_items", {})
	for item_id in items_data:
		var item_data = items_data[item_id]
		var discovery = ScanDiscoveryData.new()
		discovery.item_id = item_id
		discovery.scan_tier = item_data.get("scan_tier", 1)
		discovery.times_scanned = item_data.get("times_scanned", 0)
		discovery.first_scan_time = item_data.get("first_scan_time", 0.0)
		discovery.last_scan_time = item_data.get("last_scan_time", 0.0)
		scanned_items[item_id] = discovery
	
	print("[DiscoveryManager] Loaded %d discoveries" % scanned_items.size())
	collection_updated.emit()

func _on_scanner_completed(item_uid: String, item_data: CollectionItemData):
	"""Handle scan completion from scanner"""
	if not item_data or not item_data.is_valid():
		push_error("[DiscoveryManager] Invalid item data received for: %s" % item_uid)
		return
	
	var is_new = record_scan(item_uid, item_data)
	
	# Additional feedback based on discovery
	if is_new:
		print("[DiscoveryManager] 🆕 New discovery: %s (%s)" % [
			item_data.display_name,
			item_uid
		])

# ADD: Check if biome should unlock
func _check_biome_unlock():
	"""Check if current progression unlocks next biome"""
	var current_biome = WorldState.current_biome if has_node("/root/WorldState") else "hub"
	var progress = check_biome_progression(current_biome)
	
	if progress.is_empty():
		return
	
	if progress.can_unlock_next and progress.next_biome != "":
		var next_biome = progress.next_biome
		
		# Check if already unlocked
		if has_node("/root/WorldState"):
			var world_state = get_node("/root/WorldState")
			if world_state.has_method("is_biome_unlocked"):
				if world_state.is_biome_unlocked(next_biome):
					return  # Already unlocked
				
				# Unlock it!
				if world_state.has_method("unlock_biome"):
					world_state.unlock_biome(next_biome)
				
				biome_unlocked.emit(next_biome)
				
				print("[DiscoveryManager] 🎉 Biome unlocked: %s" % next_biome)
				
				# Show unlock notification
				var biome_display_name = next_biome.replace("_", " ").capitalize()
				DialogueManager.show_message(
					"Lucy",
					"Fascinating! Your scans have revealed a new area. The %s is now accessible!" % biome_display_name,
					5.0
				)



# ADD: New helper to load by item_key (for scene loading)
func _load_collection_item_by_key(item_key: String) -> CollectionItemData:
	"""Load CollectionItemData resource directly by item_key (file name)"""
	var search_dirs = [
		"res://data/collection_items/flora/",
		"res://data/collection_items/minerals/",
		"res://data/collection_items/artifacts/"
	]
	
	for dir_path in search_dirs:
		var file_path = dir_path + item_key + ".tres"
		if ResourceLoader.exists(file_path):
			return load(file_path) as CollectionItemData
	
	return null

# ADD: Get current scan tier for an item
func get_scan_tier(item_uid: String) -> int:
	"""Returns current tier (1-3) or 0 if not scanned"""
	if not scanned_items.has(item_uid):
		return 0
	return scanned_items[item_uid].scan_tier

# ADD: Get scan progress info for an item
func get_scan_progress(item_uid: String) -> Dictionary:
	"""
	Returns detailed scan progress for an item.
	Useful for UI display.
	"""
	if not scanned_items.has(item_uid):
		return {
			"scanned": false,
			"times_scanned": 0,
			"current_tier": 0,
			"max_tier": 3,
			"scans_to_next_tier": 0
		}
	
	var scan_data = scanned_items[item_uid]
	var item_data = _load_collection_item_data(item_uid)
	
	if not item_data:
		push_warning("[DiscoveryManager] Could not load item data for: %s" % item_uid)
		return {
			"scanned": true,
			"times_scanned": scan_data.times_scanned,
			"current_tier": scan_data.scan_tier,
			"max_tier": 3,
			"scans_to_next_tier": 0  # Unknown without item_data
		}
	
	return {
		"scanned": true,
		"times_scanned": scan_data.times_scanned,
		"current_tier": scan_data.scan_tier,
		"max_tier": 3,
		"scans_to_next_tier": item_data.get_scans_to_next_tier(scan_data.times_scanned),
		"rarity": item_data.get_rarity_name(),
		"display_name": item_data.display_name,
		"category": item_data.get_category_name()
	}

func _preload_collection_items():
	"""
	Optional: Preload all CollectionItemData on startup.
	Avoids filesystem scans during gameplay.
	"""
	var collection_dir = "res://resources/collection_items/"
	var dir = DirAccess.open(collection_dir)
	
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item_data = load(collection_dir + file_name) as CollectionItemData
			if item_data and not item_data.item_uid.is_empty():
				_item_data_cache[item_data.item_uid] = item_data
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("[DiscoveryManager] Preloaded %d collection items" % _item_data_cache.size())

func _load_collection_item_data(item_uid: String) -> CollectionItemData:
	"""
	Load CollectionItemData - uses cache if available, otherwise scans filesystem.
	"""
	# Check cache first
	if _item_data_cache.has(item_uid):
		return _item_data_cache[item_uid]
	
	# Fallback: scan filesystem
	var collection_dir = "res://resources/collection_items/"
	var dir = DirAccess.open(collection_dir)
	
	if not dir:
		return null
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item_data = load(collection_dir + file_name) as CollectionItemData
			if item_data and item_data.item_uid == item_uid:
				# Cache it for next time
				_item_data_cache[item_uid] = item_data
				dir.list_dir_end()
				return item_data
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return null

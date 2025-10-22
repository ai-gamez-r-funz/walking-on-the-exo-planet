extends CardDisplayable
class_name CollectionItemData
## Data resource defining properties for all scannable objects in the game.
##
## Each scannable object (plants, animals, minerals, artifacts) references one of these
## resources to define its identity, scanning behavior, and world generation properties.
## Create .tres files inheriting this resource for each unique scannable object.

# ============================================
# CORE IDENTITY
# ============================================

## Unique identifier for save/load systems (e.g., "flora_001", "fauna_003")
@export var item_uid: String = ""

## Human-readable key for internal references (e.g., "basic_plant", "alphaca")
@export var item_key: String = ""

## Display name shown in UI (e.g., "Basic Plant", "Alphaca")
@export var display_name: String = ""

## Scientific or flavor name for added personality (e.g., "Plantus Simplicitus")
@export var scientific_name: String = ""

# ============================================
# VISUAL & UI
# ============================================

## Icon/thumbnail displayed in inventory and collection UI
@export var icon: Texture2D

## Object category (Flora, Fauna, Mineral, Artifact, Unknown)
@export var category: Category = Category.FLORA

## Rarity tier affecting spawn rate and UI presentation
@export var rarity: Rarity = Rarity.COMMON

# ============================================
# LORE & DESCRIPTION
# ============================================

## Main description text shown in detailed item view
@export_multiline var description: String = ""

## Hint about where to find this object (e.g., "Found in temperate biomes")
@export var discovery_hint: String = ""

# ============================================
# SCANNING PROPERTIES
# ============================================

## Time in seconds required to complete a scan of this object
@export_range(0.5, 10.0, 0.5) var scan_time: float = 2.0

# ============================================
# WORLD GENERATION
# ============================================

## List of biome names where this object can spawn (e.g., ["starter", "temperate"])
@export var biome_affinity: Array[String] = []

## Total scans player must complete before this object starts spawning (0 = available immediately)
@export_range(0, 100) var unlock_threshold: int = 0

# ============================================
# ENUMS
# ============================================

## Categories for organizing collection and determining behavior
enum Category {
	FLORA,      ## Plants, trees, vegetation
	FAUNA,      ## Animals, creatures
	MINERAL,    ## Rocks, crystals, geological formations
	ARTIFACT,   ## Ancient ruins, mysterious objects
	UNKNOWN     ## Unidentified or special objects
}

## Rarity tiers affecting spawn rates and UI styling
enum Rarity {
	COMMON,      ## 60% spawn rate, basic UI styling
	UNCOMMON,    ## 25% spawn rate, enhanced UI styling
	RARE,        ## 12% spawn rate, special UI styling
	LEGENDARY    ## 3% spawn rate, unique UI styling
}

# ============================================
# VALIDATION
# ============================================

## Validates that all required fields are properly configured.
## Call this in _ready() of scannable_object.gd to catch configuration errors early.
func is_valid() -> bool:
	if item_uid.is_empty():
		push_error("CollectionItemData: item_uid is empty")
		return false
	
	if item_key.is_empty():
		push_error("CollectionItemData: item_key is empty")
		return false
	
	if display_name.is_empty():
		push_error("CollectionItemData: display_name is empty for %s" % item_uid)
		return false
	
	if icon == null:
		push_warning("CollectionItemData: icon is null for %s (will use placeholder)" % item_uid)
		# Not a critical error - can use placeholder icon
	
	if biome_affinity.is_empty():
		push_warning("CollectionItemData: biome_affinity is empty for %s (won't spawn in world)" % item_uid)
		# Not critical for phase 1, but important for phase 4
	
	return true

# ============================================
# HELPER METHODS
# ============================================

## Returns a formatted string for debug/logging purposes
func get_debug_string() -> String:
	return "[CollectionItem: %s (%s) - %s - %s]" % [
		display_name,
		item_uid,
		Category.keys()[category],
		Rarity.keys()[rarity]
	]

## Returns the rarity as a human-readable string
func get_rarity_name() -> String:
	return Rarity.keys()[rarity]

## Returns the category as a human-readable string
func get_category_name() -> String:
	return Category.keys()[category]

## Returns a Color associated with this rarity tier for UI styling
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.WHITE
		Rarity.UNCOMMON:
			return Color(0.3, 1.0, 0.3)  # Green
		Rarity.RARE:
			return Color(0.3, 0.6, 1.0)  # Blue
		Rarity.LEGENDARY:
			return Color(1.0, 0.8, 0.0)  # Gold
		_:
			return Color.WHITE

## Returns true if this item can spawn in the specified biome
func can_spawn_in_biome(biome_name: String) -> bool:
	return biome_name in biome_affinity

## Returns a spawn weight modifier based on rarity (used by world_generator)
func get_spawn_weight() -> float:
	match rarity:
		Rarity.COMMON:
			return 1.0
		Rarity.UNCOMMON:
			return 0.4
		Rarity.RARE:
			return 0.2
		Rarity.LEGENDARY:
			return 0.05
		_:
			return 1.0


# ============================================
# CARD DISPLAY INTERFACE IMPLEMENTATION
# ============================================

func get_card_title() -> String:
	return display_name

func get_card_subtitle() -> String:
	return scientific_name

func get_card_icon() -> Texture2D:
	return icon

func get_card_description() -> String:
	return description

func get_card_category() -> String:
	return Category.keys()[category]

func get_card_color() -> Color:
	return get_rarity_color()

func get_card_metadata() -> Dictionary:
	return {
		"uid": item_uid,
		"key": item_key,
		"rarity": Rarity.keys()[rarity],
		"discovery_hint": discovery_hint,
		"scan_time": scan_time,
		"biome_affinity": biome_affinity,
		"unlock_threshold": unlock_threshold
	}

func shows_rarity() -> bool:
	return true  # Collection items always show rarity

func shows_progress() -> bool:
	return false  # Could be true if tracking scan completion percentage

func get_scans_for_tier(tier: int) -> int:
	match tier:
		1:
			return 1  # First scan unlocks
		2:
			return 1 + (rarity + 1)
		3:
			return 1 + (rarity + 1) * 2
		_:
			return 1

## Returns the tier (1-3) for a given number of scans
func get_tier_from_scan_count(scan_count: int) -> int:
	if scan_count >= get_scans_for_tier(3):
		return 3
	elif scan_count >= get_scans_for_tier(2):
		return 2
	elif scan_count >= 1:
		return 1
	else:
		return 0

## Returns how many more scans needed to reach next tier
func get_scans_to_next_tier(current_scans: int) -> int:
	var current_tier = get_tier_from_scan_count(current_scans)
	if current_tier >= 3:
		return 0  # Already max tier
	
	var next_tier = current_tier + 1
	return get_scans_for_tier(next_tier) - current_scans

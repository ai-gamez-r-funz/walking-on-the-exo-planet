# world_state.gd
# Autoload singleton that tracks current biome state
# Path: res://autoload/world_state.gd

extends Node

# Current active biome
var current_biome: String = "starter"

# Available biomes for cycling (expand in Phase 4)
var available_biomes: Array[String] = ["starter", "temperate"]

# Emitted when biome changes
signal biome_changed(new_biome: String)

func _ready():
	print("[WorldState] Initialized - Starting biome: %s" % current_biome)

# Set the active biome
func set_biome(biome_name: String):
	if biome_name in available_biomes:
		var old_biome = current_biome
		current_biome = biome_name
		biome_changed.emit(biome_name)
		print("[WorldState] Biome changed: %s -> %s" % [old_biome, biome_name])
		 # ADD THIS: Trigger exploration comment on biome change
		if AmbientComments and old_biome != biome_name:
			AmbientComments.trigger_exploration_comment()
	else:
		push_error("[WorldState] Invalid biome: %s (Available: %s)" % [biome_name, available_biomes])

# Cycle to next biome (for debug testing)
func cycle_biome_for_debug():
	var current_index = available_biomes.find(current_biome)
	var next_index = (current_index + 1) % available_biomes.size()
	set_biome(available_biomes[next_index])

# Get current biome name
func get_current_biome() -> String:
	return current_biome

# Check if biome is available
func is_biome_available(biome_name: String) -> bool:
	return biome_name in available_biomes

# Add new biome to available list (for progression in Phase 4)
func unlock_biome(biome_name: String):
	if biome_name not in available_biomes:
		available_biomes.append(biome_name)
		print("[WorldState] Biome unlocked: %s" % biome_name)

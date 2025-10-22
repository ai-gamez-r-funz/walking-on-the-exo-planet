# res://scripts/resources/card_displayable.gd
class_name CardDisplayable
extends Resource
## Base class for any resource that can be displayed as a card in UI.
##
## Inherit from this for collection items, characters, locations, accessories, etc.
## Provides standardized interface for card display systems.

# ============================================
# REQUIRED OVERRIDE METHODS
# ============================================

## Returns the primary display name for this card
func get_card_title() -> String:
	push_error("CardDisplayable.get_card_title() must be overridden")
	return ""

## Returns the subtitle/secondary text (e.g., scientific name, location type)
func get_card_subtitle() -> String:
	return ""  # Optional - empty string if not needed

## Returns the icon/thumbnail for this card
func get_card_icon() -> Texture2D:
	push_error("CardDisplayable.get_card_icon() must be overridden")
	return null

## Returns the full description text
func get_card_description() -> String:
	return ""

## Returns the category/type label (e.g., "Flora", "Character", "Location")
func get_card_category() -> String:
	return ""

## Returns a color for rarity/styling (default white if not applicable)
func get_card_color() -> Color:
	return Color.WHITE

## Returns additional metadata as a Dictionary for flexible extension
func get_card_metadata() -> Dictionary:
	return {}

# ============================================
# CARD LAYOUT HINTS
# ============================================

## Returns true if this card should show rarity indicator
func shows_rarity() -> bool:
	return false

## Returns true if this card should show progress/completion indicator
func shows_progress() -> bool:
	return false

## Returns progress value 0.0-1.0 if shows_progress() is true
func get_progress() -> float:
	return 0.0

# gem_data.gd
class_name GemData
extends Resource

## The 5 baseline gem tiers
const TIERS = ["Chipped", "Flawed", "Normal", "Flawless", "Perfect"]

## The 8 baseline gem base qualities
const QUALITIES = ["Ruby", "Sapphire", "Emerald", "Topaz", "Diamond", "Amethyst", "Aquamarine", "Opal"]

## Core metadata tracking keys
@export var tier: String = "Chipped"
@export var quality: String = "Ruby"
@export var is_advanced_tower: bool = false
@export var advanced_name: String = ""

## Unique identifier used to manage ingredient history ordering
@export var placement_timestamp: int = 0

## Easy getter helper for contextual UI naming rules
func get_display_name() -> String:
	if is_advanced_tower:
		return advanced_name
	return "%s %s" % [tier, quality]

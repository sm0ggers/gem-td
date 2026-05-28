extends Resource
class_name HeroData

@export var hero_name: String = "Generic Builder"
@export var move_speed: float = 6.0
@export var base_mana: float = 100.0
@export var mana_regen: float = 1.0

# --- GEMTD ECONOMY STATS ---
@export var gold_bonus: int = 0
@export var luck: float = 1.0
@export var rock_refund_rate: float = 0.0
@export var upgrade_discount: float = 0.0

# References to custom ability scripts or scenes we will hook up later
@export var ability_1_name: String = ""
@export var ability_2_name: String = ""

## This is the missing bridge function Godot was screaming about!
func get_modifiers_dict() -> Dictionary:
	return {
		"gold_bonus": gold_bonus,
		"luck": luck,
		"rock_refund_rate": rock_refund_rate,
		"upgrade_discount": upgrade_discount
	}

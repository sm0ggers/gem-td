extends Resource
class_name HeroData

@export var hero_name: String = "Generic Builder"
@export var move_speed: float = 6.0
@export var base_mana: float = 100.0
@export var mana_regen: float = 1.0

# References to custom ability scripts or scenes we will hook up later
@export var ability_1_name: String = ""
@export var ability_2_name: String = ""

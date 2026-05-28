extends Control

# Passing the actual Resource file outward instead of just a text name string!
signal map_type_selected(profile: MapProfile)
signal hero_selected(profile: HeroData)

# UI Panel References
@onready var main_menu_panel: Control = $MainMenuPanel
@onready var hero_select_panel: Control = $HeroSelectPanel
@onready var game_hud_panel: Control = $GameHUDPanel

# Game HUD Specific References
@onready var wave_label: Label = $GameHUDPanel/WaveLabel
@onready var gold_label: Label = $GameHUDPanel/GoldLabel
@onready var tower_sidebar: Control = $GameHUDPanel/TowerSidebarPanel
@onready var tower_name_lbl: Label = $GameHUDPanel/TowerSidebarPanel/NameLabel
@onready var tower_dmg_lbl: Label = $GameHUDPanel/TowerSidebarPanel/DamageLabel
@onready var tower_range_lbl: Label = $GameHUDPanel/TowerSidebarPanel/RangeLabel

# --- 📁 HARDCODED DICTIONARIES REMOVED ---
# We load the data files directly using Godot's built-in 'preload' function
@onready var map_normal = preload("res://classic_profile.tres")
@onready var map_blitz = preload("res://blitz_profile.tres")

@onready var hero_gremlin = preload("res://gremlin_hero.tres")
@onready var hero_mason = preload("res://mason_hero.tres")
@onready var hero_gemologist = preload("res://gemologist_hero.tres")

enum GameState { MAIN_MENU, HERO_SELECT, GAMEPLAY }
var current_state: GameState = GameState.MAIN_MENU

func _ready() -> void:
	_change_state(GameState.MAIN_MENU)
	_connect_button_signals()
	tower_sidebar.hide()

func _change_state(new_state: GameState) -> void:
	current_state = new_state
	main_menu_panel.visible = (current_state == GameState.MAIN_MENU)
	hero_select_panel.visible = (current_state == GameState.HERO_SELECT)
	game_hud_panel.visible = (current_state == GameState.GAMEPLAY)

func _connect_button_signals() -> void:
	# Main Menu Buttons - We pass the loaded data files directly!
	$MainMenuPanel/ClassicBtn.pressed.connect(_on_map_button_pressed.bind(map_normal))
	$MainMenuPanel/BlitzBtn.pressed.connect(_on_map_button_pressed.bind(map_blitz))
	
	# Hero Select Buttons - Passing the hero resources
	$HeroSelectPanel/GremlinBtn.pressed.connect(_on_hero_button_pressed.bind(hero_gremlin))
	$HeroSelectPanel/MasonBtn.pressed.connect(_on_hero_button_pressed.bind(hero_mason))
	$HeroSelectPanel/GemologistBtn.pressed.connect(_on_hero_button_pressed.bind(hero_gemologist))

# --- INPUT HANDLERS ---

func _on_map_button_pressed(profile: MapProfile) -> void:
	map_type_selected.emit(profile)
	_change_state(GameState.HERO_SELECT)

func _on_hero_button_pressed(profile: HeroData) -> void:
	hero_selected.emit(profile)
	_change_state(GameState.GAMEPLAY)

# --- PUBLIC APIS ---

func update_hud_values(wave_num: int, gold_count: int) -> void:
	wave_label.text = "Wave: %d" % wave_num
	gold_label.text = "Gold: %d" % gold_count

func display_tower_stats(tower_data: Dictionary) -> void:
	if current_state != GameState.GAMEPLAY: return
	
	if tower_data.is_empty():
		tower_sidebar.hide()
		return
		
	tower_sidebar.show()
	tower_name_lbl.text = "Name: " + str(tower_data.get("name", "Unknown Struct"))
	tower_dmg_lbl.text = "Damage: " + str(tower_data.get("damage", 0))
	tower_range_lbl.text = "Range: " + str(tower_data.get("range", 0.0))

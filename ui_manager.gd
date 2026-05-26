extends Control

# Signals to communicate outward to your Level/Game Managers
signal map_type_selected(profile_name: String)
signal hero_selected(hero_name: String, modifiers: Dictionary)

# UI Panel References
@onready var main_menu_panel: Control = $MainMenuPanel
@onready var hero_select_panel: Control = $HeroSelectPanel
@onready var game_hud_panel: Control = $GameHUDPanel

# Game HUD Specific References (Sidebar labels)
@onready var wave_label: Label = $GameHUDPanel/WaveLabel
@onready var gold_label: Label = $GameHUDPanel/GoldLabel
@onready var tower_sidebar: Control = $GameHUDPanel/TowerSidebarPanel
@onready var tower_name_lbl: Label = $GameHUDPanel/TowerSidebarPanel/NameLabel
@onready var tower_dmg_lbl: Label = $GameHUDPanel/TowerSidebarPanel/DamageLabel
@onready var tower_range_lbl: Label = $GameHUDPanel/TowerSidebarPanel/RangeLabel

# Hero Configuration Stats
const HERO_PROFILES = {
	"Greedy Gremlin": {"gold_bonus": 150, "luck": 1.2},
	"Clumsy Mason": {"rock_refund_rate": 0.25, "luck": 0.8},
	"Gemologist": {"upgrade_discount": 0.15, "luck": 1.0}
}

enum GameState { MAIN_MENU, HERO_SELECT, GAMEPLAY }
var current_state: GameState = GameState.MAIN_MENU

func _ready() -> void:
	_change_state(GameState.MAIN_MENU)
	_connect_button_signals()
	tower_sidebar.hide() # Hide tower stats panel until a tower is clicked

## State Machine management for swapping screens cleanly
func _change_state(new_state: GameState) -> void:
	current_state = new_state
	
	# Toggle screen visibility based on state
	main_menu_panel.visible = (current_state == GameState.MAIN_MENU)
	hero_select_panel.visible = (current_state == GameState.HERO_SELECT)
	game_hud_panel.visible = (current_state == GameState.GAMEPLAY)

func _connect_button_signals() -> void:
	# Main Menu Buttons (Assumes nodes named 'ClassicBtn' and 'BlitzBtn' exist)
	$MainMenuPanel/ClassicBtn.pressed.connect(_on_map_button_pressed.bind("Normal"))
	$MainMenuPanel/BlitzBtn.pressed.connect(_on_map_button_pressed.bind("Blitz"))
	
	# Hero Select Buttons
	$HeroSelectPanel/GremlinBtn.pressed.connect(_on_hero_button_pressed.bind("Greedy Gremlin"))
	$HeroSelectPanel/MasonBtn.pressed.connect(_on_hero_button_pressed.bind("Clumsy Mason"))
	$HeroSelectPanel/GemologistBtn.pressed.connect(_on_hero_button_pressed.bind("Gemologist"))

# --- INPUT HANDLERS ---

func _on_map_button_pressed(profile_name: String) -> void:
	map_type_selected.emit(profile_name)
	_change_state(GameState.HERO_SELECT)

func _on_hero_button_pressed(hero_name: String) -> void:
	var stats = HERO_PROFILES[hero_name]
	hero_selected.emit(hero_name, stats)
	_change_state(GameState.GAMEPLAY)

# --- PUBLIC APIS (Call these from game loops/managers) ---

## Updates the general economy and wave values displayed on screen
func update_hud_values(wave_num: int, gold_count: int) -> void:
	wave_label.text = "Wave: %d" % wave_num
	gold_label.text = "Gold: %d" % gold_count

## Connected to your 3D interaction raycast layer. 
## Safe bridge data parser when selecting structures.
func display_tower_stats(tower_data: Dictionary) -> void:
	if current_state != GameState.GAMEPLAY: return
	
	if tower_data.is_empty():
		tower_sidebar.hide()
		return
		
	tower_sidebar.show()
	tower_name_lbl.text = "Name: " + str(tower_data.get("name", "Unknown Struct"))
	tower_dmg_lbl.text = "Damage: " + str(tower_data.get("damage", 0))
	tower_range_lbl.text = "Range: " + str(tower_data.get("range", 0.0))

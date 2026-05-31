# ui_manager.gd
extends Control

## Re-connected original setup signals so gemtd_1_test.gd can detect clicks![cite: 3]
signal map_type_selected(profile: MapProfile)
signal hero_selected(profile: HeroData)

@onready var build_manager = $"../BuildManager"
@onready var wave_manager = $"../WaveManager"

# --- NEW RIGHT-PANEL UI ELEMENT CONTAINER REFERENCES ---
var right_panel: PanelContainer
var label_title: Label
var label_stats: Label

# Action Buttons
var btn_keep: Button
var btn_downgrade: Button
var btn_merge: Button
var btn_one_shot: Button
var btn_combine_mid: Button
var btn_guide_placeholder: Button
var btn_start_wave: Button

# Sub-context choices matching selection
var sub_menu_container: VBoxContainer
var active_inspected_tower: Node3D = null

func _ready() -> void:
	# 1. Programmatically generate the advanced Right Panel overlay
	_generate_ui_nodes_programmatically()
	
	# 2. Safely bridge to your BuildManager signals
	if build_manager:
		build_manager.choice_phase_ended.connect(_on_choice_phase_ended)
		
	# 3. CRITICAL: Wait one frame to ensure the scene tree is completely loaded 
	# before searching for menu buttons.
	await get_tree().process_frame
	_rebind_original_menu_buttons()

## Scan the scene tree for your custom panels and connect the explicit buttons
func _rebind_original_menu_buttons() -> void:
	print("--- UI MANAGER: STARTING BUTTON BINDING SCAN ---")
	
	# --- MAP SELECTION BINDINGS ---
	var main_menu_panel = find_child("MainMenuPanel", true, false)
	if main_menu_panel:
		print("Found MainMenuPanel successfully.")
		var blitz_btn = main_menu_panel.find_child("BlitzBtn", true, false) as Button
		var classic_btn = main_menu_panel.find_child("ClassicBtn", true, false) as Button
		
		if blitz_btn:
			print("Found BlitzBtn.")
			blitz_btn.pressed.connect(func():
				var profile = blitz_btn.get_meta("map_profile") if blitz_btn.has_meta("map_profile") else null
				if profile == null:
					push_error("CRITICAL: BlitzBtn is missing 'map_profile' Meta in Inspector! Creating empty fallback.")
					profile = MapProfile.new()
					profile.profile_name = "Blitz"
				_on_map_btn_pressed(profile)
			)
			
		if classic_btn:
			print("Found ClassicBtn.")
			classic_btn.pressed.connect(func():
				var profile = classic_btn.get_meta("map_profile") if classic_btn.has_meta("map_profile") else null
				if profile == null:
					push_error("CRITICAL: ClassicBtn is missing 'map_profile' Meta in Inspector! Creating empty fallback.")
					profile = MapProfile.new()
					profile.profile_name = "Classic"
				_on_map_btn_pressed(profile)
			)
	else:
		push_error("CRITICAL: Could not find a node named 'MainMenuPanel' in the scene tree!")

	# --- HERO SELECTION BINDINGS ---
	var hero_select_panel = find_child("HeroSelectPanel", true, false)
	if hero_select_panel:
		print("Found HeroSelectPanel successfully.")
		var heroes = ["GremlinBtn", "MasonBtn", "GemologistBtn"]
		for hero_btn_name in heroes:
			var btn = hero_select_panel.find_child(hero_btn_name, true, false) as Button
			if btn:
				print("Found hero button: ", hero_btn_name)
				btn.pressed.connect(func():
					var data = btn.get_meta("hero_data") if btn.has_meta("hero_data") else null
					if data == null:
						push_error("CRITICAL: " + hero_btn_name + " is missing 'hero_data' Meta! Creating empty fallback.")
						data = HeroData.new()
						data.hero_name = hero_btn_name.replace("Btn", "")
					_on_hero_btn_pressed(data)
				)
	else:
		print("Note: HeroSelectPanel is currently hidden or not found yet (this is normal if hidden by default).")

func _on_map_btn_pressed(profile: MapProfile) -> void:
	print("Map button clicked! Registering profile: ", profile.profile_name)
	map_type_selected.emit(profile)
	
	# Transition Panels
	var main_menu_panel = find_child("MainMenuPanel", true, false)
	var hero_select_panel = find_child("HeroSelectPanel", true, false)
	
	if main_menu_panel: main_menu_panel.visible = false
	if hero_select_panel: 
		hero_select_panel.visible = true
		print("Switched visibility: Main Menu OFF, Hero Select ON.")
	else:
		push_error("Could not find HeroSelectPanel to make visible!")

func _on_hero_btn_pressed(data: HeroData) -> void:
	print("Hero button clicked! Selected: ", data.hero_name)
	hero_selected.emit(data)
	_hide_setup_menus()

func _hide_setup_menus() -> void:
	var main_menu_panel = find_child("MainMenuPanel", true, false)
	var hero_select_panel = find_child("HeroSelectPanel", true, false)
	if main_menu_panel: main_menu_panel.visible = false
	if hero_select_panel: hero_select_panel.visible = false
	print("All setup menus hidden. Game world active.")

# --- PROGRAMMATIC GAMEPLAY UI GENERATION ---
func _generate_ui_nodes_programmatically() -> void:
	# 1. Base Container: Anchored cleanly to the right side of the screen
	right_panel = PanelContainer.new()
	right_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right_panel.custom_minimum_size = Vector2(360, 0) # Slightly widened for comfortable text spacing
	add_child(right_panel)
	
	# Margin wrapper adds uniform padding so elements don't hug the window borders
	var margin_box = MarginContainer.new()
	margin_box.add_theme_constant_override("margin_left", 15)
	margin_box.add_theme_constant_override("margin_right", 15)
	margin_box.add_theme_constant_override("margin_top", 20)
	margin_box.add_theme_constant_override("margin_bottom", 20)
	right_panel.add_child(margin_box)
	
	# Main structural vertical stack (No ScrollContainer wrapper!)
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin_box.add_child(main_vbox)
	
	# --- TOP SECTION: INSPECTION INFO BLOCKS ---
	label_title = Label.new()
	label_title.text = "Select a Gem Tower"
	label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Make title look distinct
	label_title.add_theme_font_size_override("font_size", 18) 
	main_vbox.add_child(label_title)
	
	label_stats = Label.new()
	label_stats.text = "Stats: ---\nRange: ---\nSpeed: ---"
	label_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(label_stats)
	
	btn_guide_placeholder = Button.new()
	btn_guide_placeholder.text = "Recipe Guide [Placeholder]"
	btn_guide_placeholder.custom_minimum_size = Vector2(0, 35)
	main_vbox.add_child(btn_guide_placeholder)
	
	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)
	
	# --- MIDDLE SECTION: 2x2 ACTION BUTTON GRID ---
	var actions_grid = GridContainer.new()
	actions_grid.columns = 2
	actions_grid.add_theme_constant_override("h_separation", 10)
	actions_grid.add_theme_constant_override("v_separation", 10)
	main_vbox.add_child(actions_grid)
	
	# Configure buttons with clean minimum heights so they are easy to click
	var btn_height = Vector2(0, 45)
	
	btn_keep = Button.new()
	btn_keep.text = "Keep Selection"
	btn_keep.custom_minimum_size = btn_height
	btn_keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_keep.pressed.connect(func(): _trigger_build_action("keep"))
	actions_grid.add_child(btn_keep)
	
	btn_downgrade = Button.new()
	btn_downgrade.text = "Downgrade"
	btn_downgrade.custom_minimum_size = btn_height
	btn_downgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_downgrade.pressed.connect(func(): _trigger_build_action("downgrade"))
	actions_grid.add_child(btn_downgrade)
	
	btn_merge = Button.new()
	btn_merge.text = "Merge Identical"
	btn_merge.custom_minimum_size = btn_height
	btn_merge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_merge.pressed.connect(func(): _trigger_build_action("merge"))
	actions_grid.add_child(btn_merge)
	
	btn_one_shot = Button.new()
	btn_one_shot.text = "One-Shot Combine"
	btn_one_shot.custom_minimum_size = btn_height
	btn_one_shot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_one_shot.pressed.connect(func(): _show_sub_recipes_pool(true))
	actions_grid.add_child(btn_one_shot)
	
	# Mid-Wave interaction button stays underneath the main grid stack
	btn_combine_mid = Button.new()
	btn_combine_mid.text = "Combine Advanced Tower"
	btn_combine_mid.custom_minimum_size = Vector2(0, 40)
	btn_combine_mid.pressed.connect(func(): _show_sub_recipes_pool(false))
	main_vbox.add_child(btn_combine_mid)
	
	# Sub-selection list container for combination recipes
	sub_menu_container = VBoxContainer.new()
	sub_menu_container.add_theme_constant_override("separation", 6)
	main_vbox.add_child(sub_menu_container)
	
	# --- BOTTOM SECTION: FLOW CONTROL CONTROLS ---
	# Control spacing spacers to push the START WAVE button down cleanly
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)
	
	btn_start_wave = Button.new()
	btn_start_wave.text = "START WAVE"
	btn_start_wave.custom_minimum_size = Vector2(0, 55) # Prominent button size
	btn_start_wave.visible = false
	btn_start_wave.pressed.connect(_on_start_wave_pressed)
	main_vbox.add_child(btn_start_wave)
	
	# Default hidden initialization
	right_panel.visible = false
	_set_all_action_buttons_visible(false)

@warning_ignore("shadowed_variable_base_class")
func _set_all_action_buttons_visible(is_visible: bool) -> void:
	btn_keep.visible = is_visible
	btn_downgrade.visible = is_visible
	btn_merge.visible = is_visible
	btn_one_shot.visible = is_visible
	btn_combine_mid.visible = is_visible

func _on_tower_inspected(tower_node: Node3D, data: Dictionary) -> void:
	right_panel.visible = true
	active_inspected_tower = tower_node
	_clear_sub_menu_options()
	
	label_title.text = data["display_name"]
	
	if tower_node.is_active:
		label_stats.text = "Dmg: %d\nRange: %.1f\nSpeed: %.2f" % [tower_node.damage, tower_node.attack_range, tower_node.actual_attack_speed]
	else:
		label_stats.text = "Status: Undecided / Round Placement Pool"
		
	_set_all_action_buttons_visible(false)
	
	if build_manager.current_state == build_manager.BuildState.CHOICE_PENDING and data["is_from_current_round"]:
		btn_keep.visible = true
		btn_downgrade.visible = true
		btn_downgrade.disabled = not data["can_downgrade"]
		btn_merge.visible = true
		btn_merge.disabled = not data["can_merge"]
		
		if not data["one_shot_recipes"].is_empty():
			btn_one_shot.visible = true
	else:
		if tower_node.name.begins_with("Active_"):
			var mid_recipes = build_manager.get_available_recipes_for_tower(tower_node)
			if not mid_recipes.is_empty():
				btn_combine_mid.visible = true

func _trigger_build_action(action_type: String) -> void:
	if not is_instance_valid(active_inspected_tower): return
	match action_type:
		"keep": build_manager.execute_choice_keep(active_inspected_tower)
		"downgrade": build_manager.execute_choice_downgrade(active_inspected_tower)
		"merge": build_manager.execute_choice_merge(active_inspected_tower)
	_clear_all_panel_views()

func _show_sub_recipes_pool(is_one_shot: bool) -> void:
	_clear_sub_menu_options()
	if not is_instance_valid(active_inspected_tower): return
	
	var list: Array[String] = []
	if is_one_shot:
		var check = build_manager._get_valid_one_shot_recipes()
		for item in check: list.append(item)
	else:
		var check = build_manager.get_available_recipes_for_tower(active_inspected_tower)
		for item in check: list.append(item)
		
	for recipe in list:
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 35)
		
		if is_one_shot:
			# One-shot context assumes current selection rules apply
			b.text = "Forge: " + recipe
			b.pressed.connect(func(): _confirm_combination_forge(recipe, is_one_shot))
		else:
			# Mid-wave combination: Check if partner pieces reside on the board
			var can_craft = build_manager.is_recipe_fully_available(active_inspected_tower, recipe)
			if can_craft:
				b.text = "Forge: " + recipe
				b.disabled = false
			else:
				b.text = "Forge: " + recipe + " (Missing Ingredients)"
				b.disabled = true # GREY OUT BUTTON IF MATES ARE MISSING
				
			b.pressed.connect(func(): _confirm_combination_forge(recipe, is_one_shot))
			
		sub_menu_container.add_child(b)

func _confirm_combination_forge(recipe_name: String, is_one_shot: bool) -> void:
	if not is_instance_valid(active_inspected_tower): return
	if is_one_shot:
		build_manager.execute_choice_one_shot(active_inspected_tower, recipe_name)
		_clear_all_panel_views()
	else:
		var success = build_manager.execute_mid_wave_combination(active_inspected_tower, recipe_name)
		if success:
			_clear_all_panel_views()
		else:
			var err_lbl = Label.new()
			err_lbl.text = "Missing ingredients on map!"
			err_lbl.add_theme_color_override("font_color", Color(1,0,0))
			sub_menu_container.add_child(err_lbl)

func _on_choice_phase_ended() -> void:
	if not build_manager.auto_start_wave:
		btn_start_wave.visible = true

func _on_start_wave_pressed() -> void:
	btn_start_wave.visible = false
	if wave_manager:
		wave_manager.start_next_wave()
	if build_manager:
		build_manager.reset_for_next_building_round()

func _clear_sub_menu_options() -> void:
	for child in sub_menu_container.get_children():
		child.queue_free()

func _clear_all_panel_views() -> void:
	_clear_sub_menu_options()
	_set_all_action_buttons_visible(false)
	label_title.text = "Selection Confirmed"
	label_stats.text = "Processing grid updates..."
	active_inspected_tower = null

func display_tower_stats(data: Dictionary) -> void:
	right_panel.visible = true
	if data.is_empty():
		label_title.text = "Empty Tile"
		label_stats.text = "Select a tower to view metrics."
	else:
		label_title.text = data["name"]
		label_stats.text = "Damage: %d\nRange: %.1f" % [data["damage"], data["range"]]

# Inside ui_manager.gd

## Creates a dynamic debug dropdown menu at the mouse position
func spawn_debug_cheat_menu(screen_position: Vector2, spawn_callback: Callable) -> void:
	# Clean up any existing menu instance first
	var old_menu = get_node_or_null("DebugCheatMenu")
	if old_menu: old_menu.queue_free()
	
	var popup_panel = PopupPanel.new()
	popup_panel.name = "DebugCheatMenu"
	popup_panel.size = Vector2(200, 250)
	popup_panel.position = Vector2i(int(screen_position.x), int(screen_position.y))
	add_child(popup_panel)
	
	var scroll = ScrollContainer.new()
	popup_panel.add_child(scroll)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(main_vbox)
	
	var title = Label.new()
	title.text = "--- CHEAT MENU ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	var qualities = ["Ruby", "Sapphire", "Emerald", "Topaz", "Diamond", "Amethyst", "Aquamarine", "Opal"]
	var tiers = ["Chipped", "Flawed", "Normal", "Flawless", "Perfect"]
	
	# Loop and generate Tier sub-menus for each Gem Quality
	for quality in qualities:
		var quality_menu_button = MenuButton.new()
		quality_menu_button.text = quality
		quality_menu_button.flat = false
		quality_menu_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		main_vbox.add_child(quality_menu_button)
		
		var popup: PopupMenu = quality_menu_button.get_popup()
		for tier in tiers:
			popup.add_item(tier)
			
		popup.id_pressed.connect(func(id: int):
			var selected_tier = tiers[id]
			# Fire callback back to BuildManager to spawn the selected item
			spawn_callback.call(selected_tier, quality)
			popup_panel.hide()
			popup_panel.queue_free()
		)
		
	popup_panel.popup()
	

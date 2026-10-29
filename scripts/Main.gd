extends Node

const PenaltySceneScript = preload("res://scripts/PenaltyScene3D.gd")
const SeasonScreenScript = preload("res://scripts/SeasonScreen.gd")
const EditorScreenScript = preload("res://scripts/EditorScreen.gd")

var ui_canvas: CanvasLayer
var current_screen: Node = null
var current_3d_scene: Node3D = null

func _ready() -> void:
    DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
    ui_canvas = CanvasLayer.new()
    add_child(ui_canvas)
    show_main_menu()

func _clear_active() -> void:
    if current_screen != null and is_instance_valid(current_screen):
        current_screen.queue_free()
        current_screen = null
    if current_3d_scene != null and is_instance_valid(current_3d_scene):
        current_3d_scene.queue_free()
        current_3d_scene = null

func show_main_menu() -> void:
    _clear_active()
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui_canvas.add_child(root)
    current_screen = root

    # Deep UEFA-style stadium night blue background
    var bg := ColorRect.new()
    bg.color = Color(0.04, 0.09, 0.18, 1.0)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(bg)

    var pitch_stripe := ColorRect.new()
    pitch_stripe.color = Color(0.08, 0.34, 0.16, 1.0)
    pitch_stripe.anchor_left = 0.0
    pitch_stripe.anchor_right = 1.0
    pitch_stripe.anchor_top = 0.72
    pitch_stripe.anchor_bottom = 1.0
    root.add_child(pitch_stripe)

    var main_vbox := VBoxContainer.new()
    main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    main_vbox.offset_left = 60
    main_vbox.offset_right = -60
    main_vbox.offset_top = 36
    main_vbox.offset_bottom = -36
    main_vbox.add_theme_constant_override("separation", 18)
    root.add_child(main_vbox)

    var title := Label.new()
    title.text = "PENALTY CHAMPIONS 3D"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 46)
    title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22))
    main_vbox.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "3D STADIUM SHOOTOUT  •  FULL SEASON MANAGER  •  IN-GAME DATABASE EDITOR"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 18)
    subtitle.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
    main_vbox.add_child(subtitle)

    # Team matchup preview card for Quick Shootout
    var card := PanelContainer.new()
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_vbox.add_child(card)

    var card_hbox := HBoxContainer.new()
    card_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    card_hbox.add_theme_constant_override("separation", 40)
    card.add_child(card_hbox)

    # Left Column: Quick Shootout Selector
    var quick_box := VBoxContainer.new()
    quick_box.alignment = BoxContainer.ALIGNMENT_CENTER
    quick_box.add_theme_constant_override("separation", 12)
    card_hbox.add_child(quick_box)

    var q_title := Label.new()
    q_title.text = "QUICK PENALTY SHOOTOUT MATCHUP"
    q_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    q_title.add_theme_font_size_override("font_size", 20)
    q_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.55))
    quick_box.add_child(q_title)

    var teams_row := HBoxContainer.new()
    teams_row.alignment = BoxContainer.ALIGNMENT_CENTER
    teams_row.add_theme_constant_override("separation", 18)
    quick_box.add_child(teams_row)

    var home_logo := TextureRect.new()
    home_logo.custom_minimum_size = Vector2(72, 72)
    home_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    home_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    teams_row.add_child(home_logo)

    var home_opt := OptionButton.new()
    home_opt.custom_minimum_size = Vector2(210, 48)
    teams_row.add_child(home_opt)

    var vs_lbl := Label.new()
    vs_lbl.text = "VS"
    vs_lbl.add_theme_font_size_override("font_size", 24)
    teams_row.add_child(vs_lbl)

    var away_opt := OptionButton.new()
    away_opt.custom_minimum_size = Vector2(210, 48)
    teams_row.add_child(away_opt)

    var away_logo := TextureRect.new()
    away_logo.custom_minimum_size = Vector2(72, 72)
    away_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    away_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    teams_row.add_child(away_logo)

    for i in range(GameDatabase.teams.size()):
        var t: Dictionary = GameDatabase.teams[i]
        var label_txt: String = str(t["name"]) + " (" + str(t["rating"]) + ")"
        home_opt.add_item(label_txt, i)
        away_opt.add_item(label_txt, i)

    home_opt.selected = 0
    away_opt.selected = min(1, GameDatabase.teams.size() - 1)

    var update_logos := func(_idx: int = 0) -> void:
        var ht: Dictionary = GameDatabase.teams[home_opt.selected]
        var at: Dictionary = GameDatabase.teams[away_opt.selected]
        home_logo.texture = ProceduralArt.get_team_logo(ht, 80)
        away_logo.texture = ProceduralArt.get_team_logo(at, 80)

    home_opt.item_selected.connect(update_logos)
    away_opt.item_selected.connect(update_logos)
    update_logos.call(0)

    var play_quick_btn := Button.new()
    play_quick_btn.text = "PLAY 3D PENALTY SHOOTOUT NOW"
    play_quick_btn.custom_minimum_size = Vector2(420, 62)
    play_quick_btn.add_theme_font_size_override("font_size", 22)
    play_quick_btn.pressed.connect(func() -> void:
        var ht_id: String = str(GameDatabase.teams[home_opt.selected]["id"])
        var at_id: String = str(GameDatabase.teams[away_opt.selected]["id"])
        start_penalty_shootout(ht_id, at_id, {})
    )
    quick_box.add_child(play_quick_btn)

    # Bottom navigation buttons
    var nav_hbox := HBoxContainer.new()
    nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    nav_hbox.add_theme_constant_override("separation", 24)
    main_vbox.add_child(nav_hbox)

    var season_btn := Button.new()
    season_btn.text = "SEASON MODE (LEAGUES & CUPS)"
    season_btn.custom_minimum_size = Vector2(340, 64)
    season_btn.add_theme_font_size_override("font_size", 20)
    season_btn.pressed.connect(show_season_screen)
    nav_hbox.add_child(season_btn)

    var editor_btn := Button.new()
    editor_btn.text = "FULL DATABASE EDITOR"
    editor_btn.custom_minimum_size = Vector2(320, 64)
    editor_btn.add_theme_font_size_override("font_size", 20)
    editor_btn.pressed.connect(show_editor_screen)
    nav_hbox.add_child(editor_btn)

    var settings_btn := Button.new()
    settings_btn.text = "SETTINGS"
    settings_btn.custom_minimum_size = Vector2(200, 64)
    settings_btn.add_theme_font_size_override("font_size", 20)
    settings_btn.pressed.connect(_show_settings_popup)
    nav_hbox.add_child(settings_btn)

func start_penalty_shootout(home_id: String, away_id: String, fixture_ref: Dictionary = {}) -> void:
    _clear_active()
    var scene3d := Node3D.new()
    scene3d.set_script(PenaltySceneScript)
    add_child(scene3d)
    current_3d_scene = scene3d
    scene3d.setup_match(self, ui_canvas, home_id, away_id, fixture_ref)

func show_season_screen() -> void:
    _clear_active()
    var scr := Control.new()
    scr.set_script(SeasonScreenScript)
    scr.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui_canvas.add_child(scr)
    current_screen = scr
    scr.setup(self)

func show_editor_screen() -> void:
    _clear_active()
    var ed := Control.new()
    ed.set_script(EditorScreenScript)
    ed.set_anchors_preset(Control.PRESET_FULL_RECT)
    ui_canvas.add_child(ed)
    current_screen = ed
    ed.setup(self)

func _show_settings_popup() -> void:
    var pop := AcceptDialog.new()
    pop.title = "Game Settings"
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 12)

    var sfx_chk := CheckButton.new()
    sfx_chk.text = "Stadium Sound Effects & Whistle"
    sfx_chk.button_pressed = ProceduralArt.sound_enabled
    sfx_chk.toggled.connect(func(on: bool) -> void:
        ProceduralArt.sound_enabled = on
    )
    vb.add_child(sfx_chk)

    var reset_btn := Button.new()
    reset_btn.text = "Reset Save & Regenerate Default Database"
    reset_btn.pressed.connect(func() -> void:
        GameDatabase.generate_default_database()
        SeasonManager.start_new_season(true)
        pop.hide()
        show_main_menu()
    )
    vb.add_child(reset_btn)

    pop.add_child(vb)
    current_screen.add_child(pop)
    pop.popup_centered(Vector2i(460, 240))

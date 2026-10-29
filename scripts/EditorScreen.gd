extends Control

var main_ctrl: Node
var active_tab: int = 0
var body_box: VBoxContainer
var selected_team_idx: int = 0
var selected_player_idx: int = 0
var selected_league_idx: int = 0
var selected_comp_idx: int = 0

func setup(m_ctrl: Node) -> void:
    main_ctrl = m_ctrl

    var bg := ColorRect.new()
    bg.color = Color(0.06, 0.09, 0.15, 1.0)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var root_vbox := VBoxContainer.new()
    root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    root_vbox.offset_left = 20
    root_vbox.offset_right = -20
    root_vbox.offset_top = 14
    root_vbox.offset_bottom = -14
    root_vbox.add_theme_constant_override("separation", 10)
    add_child(root_vbox)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 12)
    root_vbox.add_child(top_row)

    var back_btn := Button.new()
    back_btn.text = "◄ SAVE & EXIT TO MENU"
    back_btn.custom_minimum_size = Vector2(210, 44)
    back_btn.pressed.connect(func() -> void:
        GameDatabase.save_game()
        main_ctrl.show_main_menu()
    )
    top_row.add_child(back_btn)

    var title := Label.new()
    title.text = "FULL IN-GAME DATABASE EDITOR (TEAMS • PLAYERS • LEAGUES • TROPHIES • JSON)"
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22))
    top_row.add_child(title)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    root_vbox.add_child(tabs)

    var labels: Array[String] = ["TEAMS & LOGOS", "PLAYERS & PHOTOS", "LEAGUES & SPOTS", "CUPS & TROPHIES", "JSON IMPORT / EXPORT"]
    for i in range(labels.size()):
        var b := Button.new()
        b.text = labels[i]
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.custom_minimum_size = Vector2(0, 44)
        b.pressed.connect(func() -> void:
            active_tab = i
            _rebuild_tab()
        )
        tabs.add_child(b)

    body_box = VBoxContainer.new()
    body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_vbox.add_child(body_box)

    _rebuild_tab()

func _rebuild_tab() -> void:
    for c in body_box.get_children():
        c.queue_free()

    if active_tab == 0:
        _build_teams_editor()
    elif active_tab == 1:
        _build_players_editor()
    elif active_tab == 2:
        _build_leagues_editor()
    elif active_tab == 3:
        _build_competitions_editor()
    else:
        _build_json_editor()

func _open_phone_image_picker(save_key: String, on_done: Callable) -> void:
    var fd := FileDialog.new()
    fd.access = FileDialog.ACCESS_FILESYSTEM
    fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    fd.filters = PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPG Images", "*.jpeg ; JPEG Images", "*.webp ; WebP Images"])
    if OS.get_name() == "Android":
        fd.current_dir = "/storage/emulated/0/Download"
    fd.file_selected.connect(func(path: String) -> void:
        var saved_path: String = ProceduralArt.import_custom_image(path, save_key)
        on_done.call(saved_path)
        fd.queue_free()
    )
    add_child(fd)
    fd.popup_centered(Vector2i(760, 480))

# ==================== TAB 0: TEAMS & LOGOS ====================
func _build_teams_editor() -> void:
    selected_team_idx = clampi(selected_team_idx, 0, max(0, GameDatabase.teams.size() - 1))
    var t: Dictionary = GameDatabase.teams[selected_team_idx]

    var top_sel := HBoxContainer.new()
    top_sel.add_theme_constant_override("separation", 10)
    body_box.add_child(top_sel)

    var opt := OptionButton.new()
    opt.custom_minimum_size = Vector2(320, 42)
    for i in range(GameDatabase.teams.size()):
        opt.add_item(str(GameDatabase.teams[i]["name"]), i)
    opt.selected = selected_team_idx
    opt.item_selected.connect(func(idx: int) -> void:
        selected_team_idx = idx
        _rebuild_tab()
    )
    top_sel.add_child(opt)

    var add_btn := Button.new()
    add_btn.text = "+ ADD NEW TEAM"
    add_btn.pressed.connect(func() -> void:
        var new_id: String = "team_custom_" + str(Time.get_ticks_msec())
        GameDatabase.teams.append({
            "id": new_id, "name": "New Club FC", "short_name": "NEW",
            "color1": "#1e5aa8", "color2": "#f5c518", "stadium": "New Stadium",
            "rating": 78, "league_id": str(GameDatabase.leagues[0]["id"]),
            "country": str(GameDatabase.leagues[0]["country"]),
            "logo_shape": 0, "logo_pattern": 0, "custom_logo": ""
        })
        selected_team_idx = GameDatabase.teams.size() - 1
        _rebuild_tab()
    )
    top_sel.add_child(add_btn)

    var del_btn := Button.new()
    del_btn.text = "DELETE TEAM"
    del_btn.pressed.connect(func() -> void:
        if GameDatabase.teams.size() > 4:
            GameDatabase.teams.remove_at(selected_team_idx)
            selected_team_idx = 0
            _rebuild_tab()
    )
    top_sel.add_child(del_btn)

    var form := HBoxContainer.new()
    form.add_theme_constant_override("separation", 24)
    body_box.add_child(form)

    # Left Preview (Strictly 2D Flat Logo + Picker)
    var logo_vb := VBoxContainer.new()
    logo_vb.add_theme_constant_override("separation", 10)
    form.add_child(logo_vb)

    var logo_preview := TextureRect.new()
    logo_preview.custom_minimum_size = Vector2(140, 140)
    logo_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo_preview.texture = ProceduralArt.get_team_logo(t, 128)
    logo_vb.add_child(logo_preview)

    var rand_logo_btn := Button.new()
    rand_logo_btn.text = "Generate New 2D Logo"
    rand_logo_btn.pressed.connect(func() -> void:
        t["custom_logo"] = ""
        t["logo_shape"] = (int(t.get("logo_shape", 0)) + 1) % 4
        t["logo_pattern"] = (int(t.get("logo_pattern", 0)) + 1) % 4
        ProceduralArt.logo_cache.clear()
        _rebuild_tab()
    )
    logo_vb.add_child(rand_logo_btn)

    var pick_logo_btn := Button.new()
    pick_logo_btn.text = "Pick Logo from Phone"
    pick_logo_btn.pressed.connect(func() -> void:
        _open_phone_image_picker(str(t["id"]), func(saved_path: String) -> void:
            if saved_path != "":
                t["custom_logo"] = saved_path
                ProceduralArt.logo_cache.clear()
                _rebuild_tab()
        )
    )
    logo_vb.add_child(pick_logo_btn)

    # Right Fields
    var fields := GridContainer.new()
    fields.columns = 2
    fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    fields.add_theme_constant_override("h_separation", 14)
    fields.add_theme_constant_override("v_separation", 10)
    form.add_child(fields)

    _add_line_field(fields, "Club Name:", str(t.get("name", "")), func(v: String) -> void: t["name"] = v)
    _add_line_field(fields, "Short Name (3 chars):", str(t.get("short_name", "FC")), func(v: String) -> void:
        t["short_name"] = v.to_upper().substr(0, 3)
        ProceduralArt.logo_cache.clear()
    )
    _add_line_field(fields, "Primary Hex Color:", str(t.get("color1", "#1e5aa8")), func(v: String) -> void:
        t["color1"] = v
        ProceduralArt.logo_cache.clear()
    )
    _add_line_field(fields, "Secondary Hex Color:", str(t.get("color2", "#f5c518")), func(v: String) -> void:
        t["color2"] = v
        ProceduralArt.logo_cache.clear()
    )
    _add_line_field(fields, "Stadium Name:", str(t.get("stadium", "")), func(v: String) -> void: t["stadium"] = v)
    _add_line_field(fields, "Team Rating (50-99):", str(t.get("rating", 78)), func(v: String) -> void: t["rating"] = clampi(int(v), 50, 99))

# ==================== TAB 1: PLAYERS & PHOTOS ====================
func _build_players_editor() -> void:
    selected_player_idx = clampi(selected_player_idx, 0, max(0, GameDatabase.players.size() - 1))
    var p: Dictionary = GameDatabase.players[selected_player_idx]
    var p_team: Dictionary = GameDatabase.get_team(str(p.get("team_id", "team_0")))

    var top_sel := HBoxContainer.new()
    top_sel.add_theme_constant_override("separation", 10)
    body_box.add_child(top_sel)

    var opt := OptionButton.new()
    opt.custom_minimum_size = Vector2(380, 42)
    for i in range(min(250, GameDatabase.players.size())):
        var pl: Dictionary = GameDatabase.players[i]
        opt.add_item(str(pl["name"]) + " (" + str(pl["position"]) + " - OVR " + str(pl["rating"]) + ")", i)
    opt.selected = min(selected_player_idx, 249)
    opt.item_selected.connect(func(idx: int) -> void:
        selected_player_idx = idx
        _rebuild_tab()
    )
    top_sel.add_child(opt)

    var add_btn := Button.new()
    add_btn.text = "+ ADD NEW PLAYER"
    add_btn.pressed.connect(func() -> void:
        var pid: String = "player_custom_" + str(Time.get_ticks_msec())
        GameDatabase.players.push_front({
            "id": pid, "name": "NEW STAR", "number": 10, "position": "FWD",
            "age": 22, "nationality": "Spain", "team_id": str(GameDatabase.teams[0]["id"]),
            "rating": 85, "shooting": 88, "composure": 86, "accuracy": 87,
            "reflexes": 50, "diving": 50, "positioning": 50,
            "skin_tone": 1, "hair_color": 0, "custom_photo": "",
            "season_apps": 0, "season_goals": 0, "season_assists": 0,
            "season_pens_scored": 0, "season_pens_missed": 0, "season_saves": 0,
            "career_apps": 0, "career_goals": 0, "career_assists": 0,
            "career_pens_scored": 0, "career_pens_missed": 0, "career_saves": 0
        })
        selected_player_idx = 0
        _rebuild_tab()
    )
    top_sel.add_child(add_btn)

    var del_btn := Button.new()
    del_btn.text = "DELETE PLAYER"
    del_btn.pressed.connect(func() -> void:
        if GameDatabase.players.size() > 20:
            GameDatabase.players.remove_at(selected_player_idx)
            selected_player_idx = 0
            _rebuild_tab()
    )
    top_sel.add_child(del_btn)

    var form := HBoxContainer.new()
    form.add_theme_constant_override("separation", 24)
    body_box.add_child(form)

    var photo_vb := VBoxContainer.new()
    photo_vb.add_theme_constant_override("separation", 10)
    form.add_child(photo_vb)

    var photo_rect := TextureRect.new()
    photo_rect.custom_minimum_size = Vector2(130, 130)
    photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    photo_rect.texture = ProceduralArt.get_player_photo(p, str(p_team.get("color1", "#1e5aa8")), 96)
    photo_vb.add_child(photo_rect)

    var gen_face_btn := Button.new()
    gen_face_btn.text = "Cycle Generic Face"
    gen_face_btn.pressed.connect(func() -> void:
        p["custom_photo"] = ""
        p["skin_tone"] = (int(p.get("skin_tone", 0)) + 1) % 5
        p["hair_color"] = (int(p.get("hair_color", 0)) + 1) % 5
        ProceduralArt.player_photo_cache.clear()
        _rebuild_tab()
    )
    photo_vb.add_child(gen_face_btn)

    var pick_photo_btn := Button.new()
    pick_photo_btn.text = "Pick Photo from Phone"
    pick_photo_btn.pressed.connect(func() -> void:
        _open_phone_image_picker(str(p["id"]), func(saved_path: String) -> void:
            if saved_path != "":
                p["custom_photo"] = saved_path
                ProceduralArt.player_photo_cache.clear()
                _rebuild_tab()
        )
    )
    photo_vb.add_child(pick_photo_btn)

    var grid := GridContainer.new()
    grid.columns = 4
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 8)
    form.add_child(grid)

    _add_line_field(grid, "Player Name:", str(p.get("name", "")), func(v: String) -> void: p["name"] = v)
    _add_line_field(grid, "Shirt Number:", str(p.get("number", 9)), func(v: String) -> void: p["number"] = clampi(int(v), 1, 99))
    _add_line_field(grid, "Position (GK/DEF/MID/FWD):", str(p.get("position", "FWD")), func(v: String) -> void: p["position"] = v.to_upper())
    _add_line_field(grid, "Nationality:", str(p.get("nationality", "Spain")), func(v: String) -> void: p["nationality"] = v)
    _add_line_field(grid, "Overall Rating:", str(p.get("rating", 80)), func(v: String) -> void: p["rating"] = clampi(int(v), 40, 99))
    _add_line_field(grid, "Shooting (1-99):", str(p.get("shooting", 80)), func(v: String) -> void: p["shooting"] = clampi(int(v), 1, 99))
    _add_line_field(grid, "Composure (1-99):", str(p.get("composure", 80)), func(v: String) -> void: p["composure"] = clampi(int(v), 1, 99))
    _add_line_field(grid, "Accuracy (1-99):", str(p.get("accuracy", 80)), func(v: String) -> void: p["accuracy"] = clampi(int(v), 1, 99))
    _add_line_field(grid, "GK Reflexes (1-99):", str(p.get("reflexes", 50)), func(v: String) -> void: p["reflexes"] = clampi(int(v), 1, 99))
    _add_line_field(grid, "GK Diving (1-99):", str(p.get("diving", 50)), func(v: String) -> void: p["diving"] = clampi(int(v), 1, 99))
    _add_line_field(grid, "GK Positioning (1-99):", str(p.get("positioning", 50)), func(v: String) -> void: p["positioning"] = clampi(int(v), 1, 99))

# ==================== TAB 2: LEAGUES & SPOTS ====================
func _build_leagues_editor() -> void:
    selected_league_idx = clampi(selected_league_idx, 0, max(0, GameDatabase.leagues.size() - 1))
    var l: Dictionary = GameDatabase.leagues[selected_league_idx]

    var top_sel := HBoxContainer.new()
    top_sel.add_theme_constant_override("separation", 10)
    body_box.add_child(top_sel)

    var opt := OptionButton.new()
    opt.custom_minimum_size = Vector2(360, 42)
    for i in range(GameDatabase.leagues.size()):
        var lg: Dictionary = GameDatabase.leagues[i]
        opt.add_item(str(lg["country"]) + " - " + str(lg["name"]) + " (Div " + str(lg["division"]) + ")", i)
    opt.selected = selected_league_idx
    opt.item_selected.connect(func(idx: int) -> void:
        selected_league_idx = idx
        _rebuild_tab()
    )
    top_sel.add_child(opt)

    var add_btn := Button.new()
    add_btn.text = "+ ADD NEW LEAGUE"
    add_btn.pressed.connect(func() -> void:
        GameDatabase.leagues.append({
            "id": "league_custom_" + str(Time.get_ticks_msec()),
            "name": "Custom Super League",
            "country": "Custom",
            "division": 1,
            "num_teams": 8,
            "promo_spots": 0,
            "releg_spots": 2,
            "ucl_spots": 2,
            "uel_spots": 2,
            "sister_league_id": ""
        })
        selected_league_idx = GameDatabase.leagues.size() - 1
        _rebuild_tab()
    )
    top_sel.add_child(add_btn)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 10)
    body_box.add_child(grid)

    _add_line_field(grid, "League Name:", str(l.get("name", "")), func(v: String) -> void: l["name"] = v)
    _add_line_field(grid, "Country:", str(l.get("country", "")), func(v: String) -> void: l["country"] = v)
    _add_line_field(grid, "Division Tier (1 or 2):", str(l.get("division", 1)), func(v: String) -> void: l["division"] = clampi(int(v), 1, 4))
    _add_line_field(grid, "Promotion Spots:", str(l.get("promo_spots", 0)), func(v: String) -> void: l["promo_spots"] = clampi(int(v), 0, 4))
    _add_line_field(grid, "Relegation Spots:", str(l.get("releg_spots", 2)), func(v: String) -> void: l["releg_spots"] = clampi(int(v), 0, 4))
    _add_line_field(grid, "Champions Cup Spots:", str(l.get("ucl_spots", 2)), func(v: String) -> void: l["ucl_spots"] = clampi(int(v), 0, 4))
    _add_line_field(grid, "Shield Cup Spots:", str(l.get("uel_spots", 2)), func(v: String) -> void: l["uel_spots"] = clampi(int(v), 0, 4))

# ==================== TAB 3: CUPS & TROPHIES ====================
func _build_competitions_editor() -> void:
    selected_comp_idx = clampi(selected_comp_idx, 0, max(0, GameDatabase.competitions.size() - 1))
    var c: Dictionary = GameDatabase.competitions[selected_comp_idx]

    var top_sel := HBoxContainer.new()
    top_sel.add_theme_constant_override("separation", 10)
    body_box.add_child(top_sel)

    var opt := OptionButton.new()
    opt.custom_minimum_size = Vector2(360, 42)
    for i in range(GameDatabase.competitions.size()):
        opt.add_item(str(GameDatabase.competitions[i]["name"]), i)
    opt.selected = selected_comp_idx
    opt.item_selected.connect(func(idx: int) -> void:
        selected_comp_idx = idx
        _rebuild_tab()
    )
    top_sel.add_child(opt)

    var add_btn := Button.new()
    add_btn.text = "+ ADD COMPETITION / CUP"
    add_btn.pressed.connect(func() -> void:
        GameDatabase.competitions.append({
            "id": "comp_custom_" + str(Time.get_ticks_msec()),
            "name": "Custom Knockout Cup",
            "country": "International",
            "format": "knockout",
            "trophy_style": 0,
            "trophy_color": "#ffd700",
            "custom_trophy": ""
        })
        selected_comp_idx = GameDatabase.competitions.size() - 1
        _rebuild_tab()
    )
    top_sel.add_child(add_btn)

    var form := HBoxContainer.new()
    form.add_theme_constant_override("separation", 24)
    body_box.add_child(form)

    var tr_vb := VBoxContainer.new()
    tr_vb.add_theme_constant_override("separation", 10)
    form.add_child(tr_vb)

    var tr_rect := TextureRect.new()
    tr_rect.custom_minimum_size = Vector2(130, 130)
    tr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tr_rect.texture = ProceduralArt.get_trophy_icon(c, 128)
    tr_vb.add_child(tr_rect)

    var cycle_tr_btn := Button.new()
    cycle_tr_btn.text = "Cycle Trophy Shape"
    cycle_tr_btn.pressed.connect(func() -> void:
        c["custom_trophy"] = ""
        c["trophy_style"] = (int(c.get("trophy_style", 0)) + 1) % 3
        ProceduralArt.trophy_cache.clear()
        _rebuild_tab()
    )
    tr_vb.add_child(cycle_tr_btn)

    var pick_tr_btn := Button.new()
    pick_tr_btn.text = "Pick Trophy Photo"
    pick_tr_btn.pressed.connect(func() -> void:
        _open_phone_image_picker(str(c["id"]), func(saved_path: String) -> void:
            if saved_path != "":
                c["custom_trophy"] = saved_path
                ProceduralArt.trophy_cache.clear()
                _rebuild_tab()
        )
    )
    tr_vb.add_child(pick_tr_btn)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 10)
    form.add_child(grid)

    _add_line_field(grid, "Competition Name:", str(c.get("name", "")), func(v: String) -> void: c["name"] = v)
    _add_line_field(grid, "Format (knockout / group+knockout):", str(c.get("format", "knockout")), func(v: String) -> void: c["format"] = v)
    _add_line_field(grid, "Trophy Hex Color:", str(c.get("trophy_color", "#ffd700")), func(v: String) -> void:
        c["trophy_color"] = v
        ProceduralArt.trophy_cache.clear()
    )

# ==================== TAB 4: JSON IMPORT / EXPORT ====================
func _build_json_editor() -> void:
    var info := Label.new()
    info.text = "Export the full database to JSON (file & clipboard) or paste a JSON database below to import:"
    body_box.add_child(info)

    var json_box := TextEdit.new()
    json_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    json_box.text = GameDatabase.export_database_json()
    body_box.add_child(json_box)

    var btn_row := HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 16)
    body_box.add_child(btn_row)

    var copy_btn := Button.new()
    copy_btn.text = "EXPORT & COPY JSON TO CLIPBOARD"
    copy_btn.custom_minimum_size = Vector2(300, 48)
    copy_btn.pressed.connect(func() -> void:
        var s: String = GameDatabase.export_database_json()
        json_box.text = s
        DisplayServer.clipboard_set(s)
    )
    btn_row.add_child(copy_btn)

    var import_btn := Button.new()
    import_btn.text = "IMPORT DATABASE FROM JSON BOX"
    import_btn.custom_minimum_size = Vector2(300, 48)
    import_btn.pressed.connect(func() -> void:
        GameDatabase.import_database_json_string(json_box.text)
        _rebuild_tab()
    )
    btn_row.add_child(import_btn)

func _add_line_field(parent: Control, label_text: String, initial_val: String, on_change: Callable) -> void:
    var lbl := Label.new()
    lbl.text = label_text
    parent.add_child(lbl)

    var le := LineEdit.new()
    le.text = initial_val
    le.custom_minimum_size = Vector2(210, 38)
    le.text_changed.connect(on_change)
    parent.add_child(le)
